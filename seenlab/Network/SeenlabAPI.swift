//
//  SeenlabAPI.swift
//  seenlab
//
//  Every endpoint the app reads. Channel calls (ASO, SEO, AIO) are scoped to one project with `app_id`,
//  exactly like the web client's axios interceptor does.
//

import Foundation

struct Envelope<T: Decodable>: Decodable {
    let data: T?
    let message: String?
    let code: String?
}

enum APIError: LocalizedError {
    case unauthorized          // token missing or expired → sign in again
    case suspended             // the account was suspended by an admin
    case wrongCredentials
    case validation([String: [String]])
    case server(Int, String?)
    case offline
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized, .wrongCredentials: return t("admin.login.wrongCredentials")
        case .suspended: return t("admin.login.suspended")
        case .validation: return t("admin.login.invalidData")
        case .offline: return t("ios.offline")
        case .server(_, let message): return message ?? t("ios.loadFailed")
        case .decoding: return t("ios.loadFailed")
        }
    }
}

enum HTTPMethod: String { case GET, POST, PUT, DELETE }

/// One call: a path under /api, its method, query and JSON body.
struct APIRoute {
    let path: String
    var method: HTTPMethod = .GET
    var query: [String: String] = [:]
    var body: [String: Any]? = nil
    /// Adds `app_id` of the project being viewed.
    var scoped: Bool = false

    /// Everything but signing in and the refresh itself rides on the stored token (and may refresh it first).
    var usesSession: Bool { path != "/login" && path != "/auth/refresh" }
}

enum SeenlabAPI {
    // Auth
    static func login(email: String, password: String) -> APIRoute { APIRoute(path: "/login", method: .POST, body: ["email": email, "password": password]) }
    /// Takes the current token (expired is fine, for 30 days) and answers with a new one; 401 = sign in again.
    static let refresh = APIRoute(path: "/auth/refresh")
    static let user = APIRoute(path: "/auth/user")
    static let logout = APIRoute(path: "/auth/logout", method: .POST)
    static func profile(locale: String) -> APIRoute { APIRoute(path: "/auth/profile", method: .PUT, body: ["locale": locale]) }

    // Projects
    static let projects = APIRoute(path: "/admin/aso/projects")

    // ASO
    static func asoOverview(country: String) -> APIRoute { APIRoute(path: "/admin/aso/overview", query: ["country": country], scoped: true) }
    static func asoKeywords(country: String) -> APIRoute { APIRoute(path: "/admin/aso/keywords", query: ["country": country], scoped: true) }
    static func asoKeywordHistory(id: Int, country: String) -> APIRoute { APIRoute(path: "/admin/aso/keywords/\(id)/history", query: ["country": country, "days": "30"], scoped: true) }
    static func asoApps(country: String) -> APIRoute { APIRoute(path: "/admin/aso/apps", query: ["country": country], scoped: true) }
    static func asoAudit(country: String) -> APIRoute { APIRoute(path: "/admin/aso/audit", query: ["country": country], scoped: true) }
    static func asoLatestJob(type: String) -> APIRoute { APIRoute(path: "/admin/aso/jobs/latest", query: ["type": type], scoped: true) }
    static let asoReviews = APIRoute(path: "/admin/aso/reviews", scoped: true)
    static let asoListingChanges = APIRoute(path: "/admin/aso/listing-changes", scoped: true)

    // SEO
    static let seoSite = APIRoute(path: "/admin/seo/site", scoped: true)
    static let seoAudit = APIRoute(path: "/admin/seo/audit", scoped: true)
    static let seoKeywords = APIRoute(path: "/admin/seo/keywords", scoped: true)
    static let seoActions = APIRoute(path: "/admin/seo/actions", scoped: true)
    static let seoLab = APIRoute(path: "/admin/seo/lab", scoped: true)
    static let seoLinks = APIRoute(path: "/admin/seo/links", scoped: true)
    static let seoIndexNow = APIRoute(path: "/admin/seo/indexnow", scoped: true)
    static func seoPerformance(days: Int = 28) -> APIRoute { APIRoute(path: "/admin/seo/google/performance", query: ["days": String(days)], scoped: true) }
    static func seoLatestJob(type: String) -> APIRoute { APIRoute(path: "/admin/seo/jobs/latest", query: ["type": type], scoped: true) }

    // AIO
    static func aioOverview(days: Int = 30) -> APIRoute { APIRoute(path: "/admin/aio/overview", query: ["days": String(days)], scoped: true) }
    static func aioPrompt(id: Int) -> APIRoute { APIRoute(path: "/admin/aio/prompts/\(id)", scoped: true) }
    static func aioLatestJobs(type: String) -> APIRoute { APIRoute(path: "/admin/aio/jobs/latest", query: ["type": type], scoped: true) }
}
