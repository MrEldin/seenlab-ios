//
//  NetworkManager.swift
//  seenlab
//
//  Talks to the Seenlab API (Laravel, JWT). Every response is wrapped in `{ "data": … }`.
//  The base URL is https://api.seenlab.io; debug builds can point elsewhere with `-apiBase http://localhost:86`.
//
//  The token lives 24 h and can be refreshed for 30 days after it expired. Before a call the token is
//  refreshed when it is about to expire (or already has); a 401 on a call refreshes once and retries.
//  Only when the refresh itself is refused (401) is the session over.
//

import Foundation

final class NetworkManager {
    static let shared = NetworkManager()

    /// Refresh the token when it expires within this many seconds.
    private static let refreshAhead: TimeInterval = 10 * 60

    /// The project the channel calls are scoped to (set by ProjectStore).
    var projectId: Int?
    /// Called when the API says the session is over (401) or the account is suspended.
    var onSessionEnded: ((APIError) -> Void)?

    private let session: URLSession
    private let decoder: JSONDecoder
    /// The refresh in flight, so concurrent calls share one instead of racing the API.
    private var refreshTask: Task<String, Error>?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    var baseURL: String {
        #if DEBUG
        // `-apiBase http://localhost:86` on the scheme's launch arguments points a debug build at the local API.
        if let base = UserDefaults.standard.string(forKey: "apiBase"), !base.isEmpty { return base }
        #endif
        return "https://api.seenlab.io"
    }

    /// Calls the route and returns `data` (nil when the API sends `data: null`).
    func request<T: Decodable>(_ route: APIRoute, as type: T.Type = T.self) async throws -> T? {
        let data = try await raw(route)
        do {
            return try decoder.decode(Envelope<T>.self, from: data).data
        } catch {
            #if DEBUG
            print("❌ decode \(route.path): \(error)")
            #endif
            throw APIError.decoding(String(describing: error))
        }
    }

    /// Same, for responses that are not wrapped (the login token).
    func requestPlain<T: Decodable>(_ route: APIRoute, as type: T.Type = T.self) async throws -> T {
        let data = try await raw(route)
        do { return try decoder.decode(T.self, from: data) } catch { throw APIError.decoding(String(describing: error)) }
    }

    private func raw(_ route: APIRoute, retried: Bool = false) async throws -> Data {
        // A token about to run out is swapped before the call, so the call itself never sees a 401.
        if route.usesSession, let token = KeyChainManager.shared.token, JWT.expiresSoon(token, within: NetworkManager.refreshAhead) {
            do { _ = try await refresh(old: token) }
            catch APIError.unauthorized { endSession(); throw APIError.unauthorized }
            catch { /* offline or a server hiccup: try the call with the token we have */ }
        }

        let data: Data, response: URLResponse
        do { (data, response) = try await session.data(for: makeRequest(route)) } catch { throw APIError.offline }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if (200...299).contains(status) { return data }

        let envelope = try? decoder.decode(Envelope<JSONValue>.self, from: data)
        if envelope?.code == "account_suspended" { onSessionEnded?(.suspended); throw APIError.suspended }
        switch status {
        case 401:
            if route.path == "/login" { throw APIError.wrongCredentials }
            if route.path == "/auth/refresh" { throw APIError.unauthorized }
            // One refresh and one retry; a refused refresh means signing in again.
            if !retried, let token = KeyChainManager.shared.token {
                do { _ = try await refresh(old: token) }
                catch APIError.unauthorized { endSession(); throw APIError.unauthorized }
                return try await raw(route, retried: true)
            }
            endSession()
            throw APIError.unauthorized
        case 422:
            let errors = (try? decoder.decode(ValidationBody.self, from: data))?.errors ?? [:]
            throw APIError.validation(errors)
        default:
            throw APIError.server(status, envelope?.message)
        }
    }

    private func makeRequest(_ route: APIRoute) -> URLRequest {
        var comps = URLComponents(string: baseURL + "/api" + route.path)!
        var query = route.query
        if route.scoped, let projectId { query["app_id"] = String(projectId) }
        if !query.isEmpty { comps.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }

        var req = URLRequest(url: comps.url!)
        req.httpMethod = route.method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(L10n.shared.locale, forHTTPHeaderField: "Accept-Language")
        if let token = KeyChainManager.shared.token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body = route.body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        return req
    }

    // MARK: - Refresh

    /// Trades the (possibly expired) token for a fresh one and stores it. One refresh at a time: callers
    /// that arrive while one is running wait for that one. Throws `.unauthorized` when the API refuses.
    private func refresh(old: String) async throws -> String {
        if let refreshTask { return try await refreshTask.value }
        let task = Task<String, Error> { [self] in
            defer { refreshTask = nil }
            // Another caller may have replaced the token by the time we run.
            if let current = KeyChainManager.shared.token, current != old { return current }
            let res: LoginResponse = try await requestPlain(SeenlabAPI.refresh)
            KeyChainManager.shared.token = res.accessToken
            return res.accessToken
        }
        refreshTask = task
        return try await task.value
    }

    private func endSession() {
        KeyChainManager.shared.token = nil
        onSessionEnded?(.unauthorized)
    }

    private struct ValidationBody: Decodable { let errors: [String: [String]]? }
}

/// Reads the JWT without verifying it (the API does that): only `exp` matters here, to know when to refresh.
enum JWT {
    static func expiry(_ token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload += "=" }
        guard let data = Data(base64Encoded: payload),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = obj["exp"] as? Double else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    /// true when the token expires within `seconds` or already has. An unreadable token counts as fine
    /// (a 401 from the API refreshes it anyway).
    static func expiresSoon(_ token: String, within seconds: TimeInterval) -> Bool {
        guard let exp = expiry(token) else { return false }
        return exp.timeIntervalSinceNow < seconds
    }
}
