//
//  SeoStore.swift
//  seenlab
//
//  The SEO page's data for the project being viewed. Like the web's GooglePage: the site first, then
//  each tab loads its own data the first time it is opened. Switching the project starts over.
//

import Foundation
import Combine

extension SeenlabAPI {
    static let seoBing = APIRoute(path: "/admin/seo/bing", scoped: true)
}

/// One piece of the page: its value, whether it is loading, and why it failed.
struct SeoSlot<Value> {
    var value: Value?
    var loading = false
    var loaded = false
    var error: String?

    /// Nothing to show yet and a request is in flight.
    var firstLoad: Bool { loading && !loaded }
}

final class SeoStore: ObservableObject {
    static let tabs = ["plan", "audit", "rank", "research", "lab", "ai", "console"]

    @Published var tab: String {
        didSet { if tab != oldValue { UserDefaults.standard.set(tab, forKey: "seo.tab") } }
    }
    @Published private(set) var site = SeoSlot<SeoSite>()
    @Published private(set) var plan = SeoSlot<ActionPlan>()
    @Published private(set) var audit = SeoSlot<SeoAuditJob>()
    @Published private(set) var links: [SeoLink] = []
    @Published private(set) var rank = SeoSlot<SeoRankData>()
    @Published private(set) var research = SeoSlot<SeoResearch>()
    @Published private(set) var lab = SeoSlot<SeoLabReport>()
    @Published private(set) var ai = SeoSlot<SeoAiExtras>()
    @Published private(set) var gsc = SeoSlot<SeoGscReport>()
    @Published private(set) var gscDays = 28

    private var projectId: Int?

    init() {
        let saved = UserDefaults.standard.string(forKey: "seo.tab") ?? "plan"
        tab = SeoStore.tabs.contains(saved) ? saved : "plan"
    }

    /// The latest crawl: the full report once the audit tab loaded it, otherwise the site's summary.
    var report: SeoAuditReport? {
        if let r = audit.value?.result, audit.value?.isDone == true { return r }
        return site.value?.audit?.summary
    }

    // MARK: - Loading

    /// Called whenever the screen appears or the project changes.
    func start(project id: Int?) async {
        if id != projectId {
            projectId = id
            site = SeoSlot(); plan = SeoSlot(); audit = SeoSlot(); links = []; rank = SeoSlot()
            research = SeoSlot(); lab = SeoSlot(); ai = SeoSlot(); gsc = SeoSlot()
        }
        guard id != nil else { return }
        await loadSite()
        await loadTab()
    }

    /// Pull to refresh: the site and the open tab again.
    func refresh() async {
        await loadSite(force: true)
        await loadTab(force: true)
    }

    func select(_ key: String) {
        guard SeoStore.tabs.contains(key) else { return }
        tab = key
        Task { await loadTab() }
    }

    func setGscDays(_ days: Int) {
        guard days != gscDays else { return }
        gscDays = days
        Task { await loadGsc(force: true) }
    }

    func loadSite(force: Bool = false) async {
        await load(\.site, force: force) { try await NetworkManager.shared.request(SeenlabAPI.seoSite, as: SeoSite.self) }
    }

    func loadTab(force: Bool = false) async {
        guard site.value?.hasWebsite == true else { return }
        switch tab {
        case "plan":
            await load(\.plan, force: force) { try await NetworkManager.shared.request(SeenlabAPI.seoActions, as: LatestJob<ActionPlan>.self)?.result }
        case "audit":
            await loadAudit(force: force)
        case "rank":
            await load(\.rank, force: force) { try await NetworkManager.shared.request(SeenlabAPI.seoKeywords, as: SeoRankData.self) }
        case "research":
            await load(\.research, force: force) {
                let ideas = Task { try await NetworkManager.shared.request(SeenlabAPI.seoLatestJob(type: "seo_ideas"), as: LatestJob<SeoIdeas>.self) }
                let brief = Task { try await NetworkManager.shared.request(SeenlabAPI.seoLatestJob(type: "seo_brief"), as: LatestJob<SeoBrief>.self) }
                return SeoResearch(ideas: try await ideas.value, brief: try await brief.value)
            }
        case "lab":
            await load(\.lab, force: force) { try await NetworkManager.shared.request(SeenlabAPI.seoLab, as: SeoLabReport.self) }
        case "ai":
            await load(\.ai, force: force) {
                // Bing and the schema draft are extras: the tab still shows when they fail.
                let index = Task { try await NetworkManager.shared.request(SeenlabAPI.seoIndexNow, as: SeoIndexNow.self) }
                let bing = Task { try? await NetworkManager.shared.request(SeenlabAPI.seoBing, as: SeoBing.self) }
                let schema = Task { try? await NetworkManager.shared.request(SeenlabAPI.seoLatestJob(type: "seo_schema"), as: LatestJob<SeoSchemaDraft>.self) }
                return SeoAiExtras(indexNow: try await index.value, bing: await bing.value, schema: await schema.value?.result)
            }
        case "console":
            await loadGsc(force: force)
        default:
            break
        }
    }

    private func loadAudit(force: Bool) async {
        // No audit yet: the tab shows the "not checked yet" state from the site alone.
        guard site.value?.audit != nil else { return }
        let pid = projectId
        let fetchedLinks = Task { try? await NetworkManager.shared.request(SeenlabAPI.seoLinks, as: [SeoLink].self) }
        await load(\.audit, force: force) { try await NetworkManager.shared.request(SeenlabAPI.seoAudit, as: SeoAuditJob.self) }
        if let l = await fetchedLinks.value, pid == projectId { links = l }
    }

    private func loadGsc(force: Bool) async {
        guard site.value?.google?.connected == true else { return }
        let days = gscDays
        await load(\.gsc, force: force) { try await NetworkManager.shared.request(SeenlabAPI.seoPerformance(days: days), as: SeoGscReport.self) }
    }

    /// Runs one request for a slot; drops the answer if the project changed meanwhile.
    private func load<Value>(_ slot: ReferenceWritableKeyPath<SeoStore, SeoSlot<Value>>, force: Bool, _ fetch: () async throws -> Value?) async {
        if self[keyPath: slot].loading || (self[keyPath: slot].loaded && !force) { return }
        let pid = projectId
        self[keyPath: slot].loading = true
        do {
            let value = try await fetch()
            guard pid == projectId else { return }
            self[keyPath: slot].value = value
            self[keyPath: slot].loaded = true
            self[keyPath: slot].error = nil
        } catch {
            guard pid == projectId else { return }
            // A failed refresh keeps what is already on screen (views show the error only without a value).
            self[keyPath: slot].error = (error as? APIError)?.errorDescription ?? t("ios.loadFailed")
        }
        self[keyPath: slot].loading = false
    }
}
