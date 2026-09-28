//
//  SeoScreen.swift
//  seenlab
//
//  SEO: how search sees the project's website (web: seo/pages/GooglePage.vue). The header card with the
//  site's host, the seven tabs, and the open tab below. Read-only: audits, measurements and edits run on the web.
//

import SwiftUI

struct SeoScreen: View {
    @EnvironmentObject private var projects: ProjectStore
    @Environment(\.channel) private var channel
    @StateObject private var store = SeoStore()

    var body: some View {
        ChannelScroll(refresh: { await store.refresh() }) {
            header
            if let site = store.site.value, site.hasWebsite {
                ChannelTabs(tabs: tabs, selection: Binding(get: { store.tab }, set: { store.select($0) }))
                    .padding(.horizontal, -16)
                content(site)
            } else if store.site.loaded {
                noSite
            } else if let error = store.site.error, !store.site.loading {
                ErrorCard(message: error) { Task { await store.loadSite() } }
            } else {
                LoadingCard()
            }
        }
        .task(id: projects.currentId) { await store.start(project: projects.currentId) }
    }

    // MARK: - Header

    private var host: String? {
        guard let url = store.site.value?.websiteUrl, !url.isEmpty else { return nil }
        return Fmt.host(url)
    }

    private var header: some View {
        ChannelHeader(channel: "seo") {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: t("seo.note"))
                if let host {
                    Text(host).font(.dm(28, .bold)).tracking(-0.8).foregroundStyle(Color.slInk).lineLimit(1).minimumScaleFactor(0.6)
                } else if store.site.loaded {
                    Text(t("seo.site.emptyTitle")).font(.dm(26, .bold)).tracking(-0.7).foregroundStyle(Color.slInk).fixedSize(horizontal: false, vertical: true)
                } else {
                    RoundedRectangle(cornerRadius: 10).fill(Color.slBg).frame(width: 200, height: 32)
                }
            }
        }
    }

    /// The project has no website: the web's empty state, pointing to the web where it is added.
    private var noSite: some View {
        SLCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "globe").font(.system(size: 28, weight: .light)).foregroundStyle(Color.slAccent600)
                Text(t("seo.site.emptySub")).font(.dm(14.5)).foregroundStyle(Color.slInkSoft).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                Text(t("ios.webOnly")).font(.dm(12.5)).foregroundStyle(Color.slInkMuted).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Tabs

    private var tabs: [TabItem] {
        [
            TabItem(key: "plan", label: t("seo.tabs.plan"), icon: "checklist"),
            TabItem(key: "audit", label: t("seo.tabs.audit"), icon: "list.clipboard"),
            TabItem(key: "rank", label: t("seo.tabs.rank"), icon: "chart.bar.xaxis"),
            TabItem(key: "research", label: t("seo.tabs.research"), icon: "lightbulb"),
            TabItem(key: "lab", label: t("seo.tabs.lab"), icon: "testtube.2"),
            TabItem(key: "ai", label: t("seo.tabs.ai"), icon: "bubble.left.and.text.bubble.right"),
            TabItem(key: "console", label: t("seo.tabs.console"), icon: "chart.line.uptrend.xyaxis"),
        ]
    }

    private func retry() { Task { await store.loadTab(force: true) } }

    @ViewBuilder
    private func content(_ site: SeoSite) -> some View {
        switch store.tab {
        case "audit":
            SeoAuditView(site: site, audit: store.audit, links: store.links, retry: retry)
        case "rank":
            SeoSlotView(slot: store.rank, retry: retry) { SeoRankView(data: $0) }
        case "research":
            SeoSlotView(slot: store.research, retry: retry) { SeoResearchView(research: $0) }
        case "lab":
            SeoSlotView(slot: store.lab, retry: retry) { SeoLabView(lab: $0, go: { store.select($0) }) }
        case "ai":
            SeoAiView(report: store.report, llms: site.llms, extras: store.ai, retry: retry)
        case "console":
            SeoConsoleView(google: site.google, report: store.gsc, days: store.gscDays, setDays: { store.setGscDays($0) }, retry: retry)
        default:
            SeoSlotView(slot: store.plan, retry: retry) { plan in
                PlanView(plan: plan, channel: "seo", go: { store.select($0) }, kb: { channel.kb($0) })
            }
        }
    }
}
