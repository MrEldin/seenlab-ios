//
//  AioScreen.swift
//  seenlab
//
//  The AI answers page (web: visibility/pages/AiAnswers.vue): the header, then one tab per part —
//  action plan, prompts, rivals, sources, accuracy, changes, pages for AI, names & assistants.
//  A read-only viewer: asking the assistants and editing happen on the web.
//

import SwiftUI

struct AioScreen: View {
    @EnvironmentObject private var projects: ProjectStore
    @Environment(\.channel) private var channel
    @StateObject private var store = AioStore()
    @AppStorage("aio.tab") private var tab = "plan"
    @State private var opened: AioPromptRow?

    private var tabs: [TabItem] {
        let d = store.overview
        let planCount = (store.plan?.actions ?? []).filter { $0.channel == "aio" }.count
        let wrong = d?.accuracy?.counts?.wrong ?? 0
        let changes = d?.changes?.count ?? 0
        return [
            TabItem(key: "plan", label: t("aio.tabs.plan"), icon: "checklist", count: planCount > 0 ? planCount : nil),
            TabItem(key: "prompts", label: t("aio.tabs.prompts"), icon: "text.bubble", count: d?.prompts?.count),
            TabItem(key: "rivals", label: t("aio.tabs.rivals"), icon: "chart.bar.xaxis", count: d?.brands?.count),
            TabItem(key: "sources", label: t("aio.tabs.sources"), icon: "link", count: d?.sources?.count),
            TabItem(key: "accuracy", label: t("aio.tabs.accuracy"), icon: "checkmark.shield", count: wrong > 0 ? wrong : nil),
            TabItem(key: "changes", label: t("aio.tabs.changes"), icon: "bell", count: changes > 0 ? changes : nil),
            TabItem(key: "pages", label: t("aio.tabs.pages"), icon: "doc.badge.plus"),
            TabItem(key: "setup", label: t("aio.tabs.setup"), icon: "slider.horizontal.3"),
        ]
    }

    var body: some View {
        ChannelScroll(refresh: { await store.load(project: projects.currentId) }) {
            AioHeader(data: store.overview)
            ChannelTabs(tabs: tabs, selection: $tab).padding(.horizontal, -16)
            content
        }
        .task(id: projects.currentId) { await store.load(project: projects.currentId) }
        .sheet(item: $opened) { p in
            AioPromptSheet(prompt: p, engines: store.overview?.engines ?? [], load: store.prompt)
        }
    }

    @ViewBuilder private var content: some View {
        if let d = store.overview {
            switch tab {
            case "plan":
                PlanView(plan: store.plan, channel: "aio", go: { go($0) }, kb: { channel.kb($0) })
            case "prompts":
                AioPromptsView(data: d) { opened = $0 }
            case "rivals":
                AioRivalsView(data: d)
            case "sources":
                AioSourcesView(data: d, drafts: store.drafts)
            case "accuracy":
                AioAccuracyView(data: d) { go("setup") }
            case "changes":
                AioChangesView(data: d)
            case "pages":
                AioPagesView(data: d, pages: store.pages)
            default:
                AioSetupView(data: d)
            }
        } else if let error = store.error {
            ErrorCard(message: error) { Task { await store.load(project: projects.currentId) } }
        } else {
            LoadingCard()
        }
    }

    private func go(_ key: String) {
        guard tabs.contains(where: { $0.key == key }) else { return }
        withAnimation(.snappy(duration: 0.25)) { tab = key }
    }
}
