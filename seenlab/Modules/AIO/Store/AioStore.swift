//
//  AioStore.swift
//  seenlab
//
//  Loads the AI answers page of the project being viewed: the overview, the morning plan (served by the
//  SEO endpoint and shared with it), and the latest outreach drafts and AI pages. Read-only — running
//  the assistants and editing prompts stay on the web.
//

import Foundation
import Combine

final class AioStore: ObservableObject {
    @Published private(set) var overview: AioOverview?
    @Published private(set) var plan: ActionPlan?
    @Published private(set) var outreachJobs: [Job<AioOutreachResult>] = []
    @Published private(set) var pageJobs: [Job<AioPageResult>] = []
    @Published private(set) var loading = false
    @Published private(set) var error: String?

    private var projectId: Int?

    /// The latest pitch per cited page (newest wins), keyed by the page URL.
    var drafts: [String: AioOutreachResult] {
        var out: [String: AioOutreachResult] = [:]
        for job in outreachJobs.reversed() {
            guard let result = job.result, let url = job.input?["url"]?.string ?? result.url else { continue }
            out[url] = result
        }
        return out
    }

    /// Written AI pages, newest first.
    var pages: [Job<AioPageResult>] { pageJobs.filter { $0.result?.page != nil } }

    func load(project: Int?) async {
        guard let project else { return }
        if project != projectId {
            projectId = project
            overview = nil
            plan = nil
            outreachJobs = []
            pageJobs = []
        }
        loading = true
        error = nil
        defer { if projectId == project { loading = false } }

        do {
            let data = try await NetworkManager.shared.request(SeenlabAPI.aioOverview(days: 30), as: AioOverview.self)
            guard projectId == project else { return }
            overview = data
        } catch {
            guard projectId == project else { return }
            if overview == nil { self.error = (error as? APIError)?.errorDescription ?? t("ios.loadFailed") }
            return
        }

        // The rest is extra: a failure here leaves the tab empty instead of failing the page.
        let plan = try? await NetworkManager.shared.request(SeenlabAPI.seoActions, as: LatestJob<ActionPlan>.self)
        guard projectId == project else { return }
        self.plan = plan?.result ?? self.plan

        let outreach = try? await NetworkManager.shared.request(SeenlabAPI.aioLatestJobs(type: "aio_outreach"), as: [Job<AioOutreachResult>].self)
        guard projectId == project else { return }
        if let outreach { outreachJobs = outreach }

        let pages = try? await NetworkManager.shared.request(SeenlabAPI.aioLatestJobs(type: "aio_page"), as: [Job<AioPageResult>].self)
        guard projectId == project else { return }
        if let pages { pageJobs = pages }
    }

    /// Every assistant's latest answer to one prompt.
    func prompt(_ id: Int) async throws -> AioPromptDetail? {
        try await NetworkManager.shared.request(SeenlabAPI.aioPrompt(id: id), as: AioPromptDetail.self)
    }
}
