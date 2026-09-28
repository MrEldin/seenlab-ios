//
//  MainView.swift
//  seenlab
//
//  The signed-in app: one tab per channel (ASO · SEO · AIO) plus settings. The project being viewed is
//  picked from the menu in every channel's toolbar, like the web's app rail.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject private var projects: ProjectStore
    @EnvironmentObject private var auth: AuthStore
    @SceneStorage("tab") private var tab: Channel = .aso

    var body: some View {
        Group {
            if !projects.loaded {
                ProgressView().tint(Color.slAccent600).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.slBg)
            } else if projects.projects.isEmpty {
                NoProjectsView()
            } else {
                TabView(selection: $tab) {
                    Tab(t("sl.shell.aso"), systemImage: "iphone", value: Channel.aso) { ChannelNav(channel: "aso", open: open) { AsoScreen() } }
                    Tab(t("sl.shell.seo"), systemImage: "globe", value: Channel.seo) { ChannelNav(channel: "seo", open: open) { SeoScreen() } }
                    Tab(t("sl.shell.ai"), systemImage: "bubble.left.and.text.bubble.right", value: Channel.aio) { ChannelNav(channel: "aio", open: open) { AioScreen() } }
                    Tab(t("ios.settings.title"), systemImage: "gearshape", value: Channel.settings) { SettingsView() }
                }
                .tint(Color.slAccent600)
            }
        }
        .task { if !projects.loaded { await projects.load() } }
        #if DEBUG
        .onAppear { if let t = UserDefaults.standard.string(forKey: "startTab"), let c = Channel(rawValue: t) { tab = c } }
        #endif
        .task { if auth.user == nil { await auth.loadUser() } }
    }

    private func open(_ c: Channel) { tab = c }
}

/// No project yet: projects are added on the web.
struct NoProjectsView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "testtube.2").font(.system(size: 54, weight: .ultraLight)).foregroundStyle(Color.slAccent600)
            Eyebrow(text: t("ios.noProjects.eyebrow"))
            Text(t("ios.noProjects.title")).font(.dm(26, .bold)).tracking(-0.5).foregroundStyle(Color.slInk).multilineTextAlignment(.center)
            Text(t("ios.noProjects.sub")).font(.dm(15)).foregroundStyle(Color.slInkMuted).multilineTextAlignment(.center)
            Button { openURL(URL(string: "https://seenlab.io/app")!) } label: { Text(t("ios.openWeb")) }.buttonStyle(SLButtonStyle(kind: .primary)).padding(.top, 6)
            Spacer()
            Button(t("ios.settings.logout")) { Task { await auth.logout() } }.font(.dm(14)).foregroundStyle(Color.slInkMuted).padding(.bottom, 20)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
        .background(Color.slBg)
    }
}
