//
//  NetworkManager.swift
//  seenlab
//
//  Talks to the Seenlab API (Laravel, JWT). Every response is wrapped in `{ "data": … }`.
//  The base URL is https://api.seenlab.io; for local work launch with `-apiBase http://localhost:86`.
//

import Foundation

final class NetworkManager {
    static let shared = NetworkManager()

    /// The project the channel calls are scoped to (set by ProjectStore).
    var projectId: Int?
    /// Called when the API says the session is over (401) or the account is suspended.
    var onSessionEnded: ((APIError) -> Void)?

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    var baseURL: String {
        UserDefaults.standard.string(forKey: "apiBase") ?? "https://api.seenlab.io"
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

    private func raw(_ route: APIRoute) async throws -> Data {
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

        let data: Data, response: URLResponse
        do { (data, response) = try await session.data(for: req) } catch { throw APIError.offline }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if (200...299).contains(status) { return data }

        let envelope = try? decoder.decode(Envelope<JSONValue>.self, from: data)
        if envelope?.code == "account_suspended" { onSessionEnded?(.suspended); throw APIError.suspended }
        switch status {
        case 401:
            if route.path == "/login" { throw APIError.wrongCredentials }
            onSessionEnded?(.unauthorized)
            throw APIError.unauthorized
        case 422:
            let errors = (try? decoder.decode(ValidationBody.self, from: data))?.errors ?? [:]
            throw APIError.validation(errors)
        default:
            throw APIError.server(status, envelope?.message)
        }
    }

    private struct ValidationBody: Decodable { let errors: [String: [String]]? }
}
