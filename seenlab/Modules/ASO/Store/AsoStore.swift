//
//  AsoStore.swift
//  seenlab
//
//  Everything the ASO screen shows for the current project and country, loaded together like the web
//  store's refreshAll + latest AI jobs. The chosen country is remembered under `aso.country`, the same
//  key the web uses. Read-only: running measurements and editing stay on the web.
//

import Foundation
import Combine

extension SeenlabAPI {
    /// The review and experiment lists are per storefront; the core routes do not pass a country.
    static func asoReviews(country: String) -> APIRoute { APIRoute(path: "/admin/aso/reviews", query: ["country": country], scoped: true) }
    static func asoListingChanges(country: String) -> APIRoute { APIRoute(path: "/admin/aso/listing-changes", query: ["country": country], scoped: true) }
    /// AI jobs are stored per country; the web asks for the latest one of the storefront being viewed.
    static func asoLatestJob(type: String, country: String) -> APIRoute { APIRoute(path: "/admin/aso/jobs/latest", query: ["type": type, "country": country], scoped: true) }
}

final class AsoStore: ObservableObject {
    static let countryKey = "aso.country"

    @Published private(set) var country: String = UserDefaults.standard.string(forKey: AsoStore.countryKey) ?? "us"
    @Published private(set) var countries: [String] = []

    @Published private(set) var overview: AsoOverview?
    @Published private(set) var keywords: [AsoKeyword] = []
    @Published private(set) var apps: [AsoApp] = []
    @Published private(set) var audit: AsoAudit?
    @Published private(set) var suggestion: Job<AsoSuggestionResult>?
    @Published private(set) var reviews: [AsoReviewSummary] = []
    @Published private(set) var reviewsInsights: Job<AsoReviewsInsightsResult>?
    @Published private(set) var listingChanges: [AsoListingChange] = []

    @Published private(set) var loading = false
    @Published private(set) var error: String?

    /// Project + country the data on screen belongs to.
    private var loadedKey: String?
    /// Another project clears the screen; another country keeps it until the new data arrives.
    private var loadedProject: Int?

    /// The key `.task(id:)` watches: a new project or country reloads.
    func key(project: Int?) -> String { "\(project ?? 0)-\(country)" }

    var hasData: Bool { overview != nil }

    func setCountry(_ code: String) {
        guard code != country else { return }
        UserDefaults.standard.set(code, forKey: AsoStore.countryKey)
        country = code
    }

    /// Loads the whole channel. `force` = pull to refresh (keeps what is on screen while it loads).
    func load(project: Int?, force: Bool = false) async {
        guard let project else { return }
        let key = key(project: project)
        if !force && loadedKey == key && overview != nil { return }
        if loadedProject != project { clear() }
        loading = true
        error = nil
        defer { loading = false }
        let country = self.country
        let net = NetworkManager.shared

        // Tasks started here stay on the main actor (the models' Decodable conformances live there) and
        // still run side by side, since each one waits on the network.
        let ov = Task { try await net.request(SeenlabAPI.asoOverview(country: country), as: AsoOverview.self) }
        let kw = Task { try await net.request(SeenlabAPI.asoKeywords(country: country), as: [AsoKeyword].self) }
        let ap = Task { try await net.request(SeenlabAPI.asoApps(country: country), as: [AsoApp].self) }
        let au = Task { try await net.request(SeenlabAPI.asoAudit(country: country), as: AsoAudit.self) }
        let sg = Task { try await net.request(SeenlabAPI.asoLatestJob(type: "suggest", country: country), as: Job<AsoSuggestionResult>.self) }
        let rv = Task { try await net.request(SeenlabAPI.asoReviews(country: country), as: [AsoReviewSummary].self) }
        let ri = Task { try await net.request(SeenlabAPI.asoLatestJob(type: "reviews_insights", country: country), as: Job<AsoReviewsInsightsResult>.self) }
        let lc = Task { try await net.request(SeenlabAPI.asoListingChanges(country: country), as: [AsoListingChange].self) }

        do {
            // The overview decides whether the screen works at all; the rest fill their tabs when they arrive.
            let overview = try await ov.value
            let keywords = (try? await kw.value) ?? nil
            let apps = (try? await ap.value) ?? nil
            let audit = (try? await au.value) ?? nil
            let suggestion = (try? await sg.value) ?? nil
            let reviews = (try? await rv.value) ?? nil
            let insights = (try? await ri.value) ?? nil
            let changes = (try? await lc.value) ?? nil
            guard !Task.isCancelled, key == self.key(project: NetworkManager.shared.projectId) else { return }

            self.overview = overview
            self.countries = overview?.countries ?? []
            self.keywords = keywords ?? []
            self.apps = apps ?? []
            self.audit = audit
            self.suggestion = suggestion
            self.reviews = reviews ?? []
            self.reviewsInsights = insights
            self.listingChanges = changes ?? []
            loadedKey = key
            loadedProject = project
        } catch {
            guard !Task.isCancelled else { return }
            self.error = (error as? APIError)?.errorDescription ?? t("ios.loadFailed")
        }
    }

    /// A keyword's 30-day rank history for every tracked app.
    func history(for keyword: AsoKeyword) async -> AsoKeywordHistory? {
        (try? await NetworkManager.shared.request(SeenlabAPI.asoKeywordHistory(id: keyword.id, country: keyword.country ?? country), as: AsoKeywordHistory.self)) ?? nil
    }

    private func clear() {
        overview = nil; keywords = []; apps = []; audit = nil; suggestion = nil
        reviews = []; reviewsInsights = nil; listingChanges = []; loadedKey = nil; loadedProject = nil
    }

    // MARK: - Derived, as the web header computes them

    /// The same term can be tracked from several sources — keep its best rank.
    var uniqueKeywords: [AsoKeyword] {
        var map: [String: AsoKeyword] = [:]
        var order: [String] = []
        for k in keywords {
            let key = k.term.lowercased()
            if let prev = map[key] {
                if let p = k.position, prev.position == nil || p < prev.position! { map[key] = k }
            } else {
                map[key] = k
                order.append(key)
            }
        }
        return order.compactMap { map[$0] }
    }

    /// Tracked keywords by term, for the AI tab's "numbers behind the word".
    var keywordsByTerm: [String: AsoKeyword] {
        Dictionary(uniqueKeywords.map { ($0.term.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })
    }

    var isAndroid: Bool { (overview?.platform ?? audit?.platform) == "android" }
}
