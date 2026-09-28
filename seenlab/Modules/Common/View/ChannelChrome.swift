//
//  ChannelChrome.swift
//  seenlab
//
//  What every channel screen sits in: the navigation with the project menu and the knowledge-base button,
//  the header card, and the actions a channel can call (open another channel, open the KB at a chapter).
//

import SwiftUI

enum Channel: String, CaseIterable { case aso, seo, aio, settings }

/// Lets a channel open another one (the web's "Otvori SEO" buttons) or its knowledge base at a chapter.
struct ChannelActions {
    var open: (Channel) -> Void = { _ in }
    var kb: (String?) -> Void = { _ in }
}

private struct ChannelActionsKey: EnvironmentKey { static let defaultValue = ChannelActions() }
extension EnvironmentValues {
    var channel: ChannelActions {
        get { self[ChannelActionsKey.self] }
        set { self[ChannelActionsKey.self] = newValue }
    }
}

/// A channel's navigation: project menu on the left, knowledge base on the right.
struct ChannelNav<Content: View>: View {
    let channel: String
    let open: (Channel) -> Void
    @ViewBuilder var content: Content

    @EnvironmentObject private var projects: ProjectStore
    @State private var kbChapter: KBStart?

    struct KBStart: Identifiable { let id = UUID(); let chapter: String? }

    var body: some View {
        NavigationStack {
            content
                .background(Color.slBg)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { ProjectMenu() }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { kbChapter = KBStart(chapter: nil) } label: { Image(systemName: "book.pages") }
                            .accessibilityLabel(t("kb.open"))
                    }
                }
                .toolbarBackground(Color.slBg, for: .navigationBar)
                .navigationBarTitleDisplayMode(.inline)
        }
        .environment(\.channel, ChannelActions(open: open, kb: { kbChapter = KBStart(chapter: $0) }))
        .sheet(item: $kbChapter) { KnowledgeBaseSheet(channel: channel, start: $0.chapter) }
    }
}

/// The project button in every channel's toolbar: the current project, tap to open the picker.
struct ProjectMenu: View {
    @EnvironmentObject private var projects: ProjectStore
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            HStack(spacing: 8) {
                RemoteIcon(url: projects.current?.iconUrl, size: 26, fallback: projects.current?.platformIcon ?? "app.fill")
                Text(projects.current?.name ?? "Seenlab").font(.dm(14, .semibold)).foregroundStyle(Color.slInk).lineLimit(1).frame(maxWidth: 190, alignment: .leading)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.slInkMuted)
            }
        }
        .accessibilityLabel(t("ios.pickProject"))
        .sheet(isPresented: $open) { ProjectPickerSheet() }
        #if DEBUG
        .onAppear { if UserDefaults.standard.bool(forKey: "openPicker") { open = true } }
        #endif
    }
}

/// The top card of every channel: project, today's date and channel, then the channel's own headline.
struct ChannelHeader<Headline: View>: View {
    let channel: String
    var status: String? = nil
    @ViewBuilder var headline: Headline
    @EnvironmentObject private var projects: ProjectStore

    var body: some View {
        SLCard {
            HStack(spacing: 10) {
                RemoteIcon(url: projects.current?.iconUrl, size: 30, fallback: projects.current?.platformIcon ?? "app.fill")
                (Text(Fmt.today()).fontWeight(.semibold).foregroundStyle(Color.slInk) + Text(" · " + t("sl.shell." + (channel == "aio" ? "ai" : channel)) + (status.map { " · " + $0 } ?? "")).foregroundStyle(Color.slInkMuted))
                    .font(.dm(12.5)).lineLimit(2)
            }
            .padding(.bottom, 12)
            headline
        }
    }
}

