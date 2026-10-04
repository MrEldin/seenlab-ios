//
//  SettingsView.swift
//  seenlab
//
//  Account, language, legal pages and sign out. Everything else (projects, keywords, prompts, billing)
//  is managed on the web.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var l10n: L10n
    @Environment(\.openURL) private var openURL

    private let languages: [(String, String)] = [("sr", "Srpski"), ("en", "English"), ("de", "Deutsch"), ("es", "Español"), ("fr", "Français")]

    var body: some View {
        NavigationStack {
            ChannelScroll {
                if let u = auth.user {
                    SLCard {
                        HStack(spacing: 12) {
                            Text(u.initials).font(.dm(15, .semibold)).foregroundStyle(Color.slAccent800)
                                .frame(width: 46, height: 46).background(Color.slTint100, in: RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(u.displayName).font(.dm(16, .semibold)).foregroundStyle(Color.slInk)
                                Text(u.email ?? "").font(.dm(13)).foregroundStyle(Color.slInkMuted)
                            }
                            Spacer()
                            // The effective plan (trial, paid or Free) rather than the raw column.
                            if let plan = u.subscription?.label ?? u.plan?.capitalized { Chip(text: plan, tone: .accent) }
                        }
                    }
                }

                section(t("ios.settings.language")) {
                    RowList(items: languages) { lang in
                        Button { auth.setLanguage(lang.0) } label: {
                            HStack {
                                Text(lang.1).font(.dm(15)).foregroundStyle(Color.slInk)
                                Spacer()
                                if l10n.locale == lang.0 { Image(systemName: "checkmark").foregroundStyle(Color.slAccent600).font(.system(size: 14, weight: .semibold)) }
                            }
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                section(t("ios.settings.legal")) {
                    RowList(items: [("terms", t("ios.settings.terms")), ("privacy", t("ios.settings.privacy"))]) { item in
                        Button { openURL(URL(string: "https://seenlab.io/\(item.0)")!) } label: {
                            HStack {
                                Text(item.1).font(.dm(15)).foregroundStyle(Color.slInk)
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.slInkFaint)
                            }
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                SLCard {
                    Text(t("ios.settings.manage")).font(.dm(13.5)).foregroundStyle(Color.slInkSoft)
                    Button { openURL(URL(string: "https://seenlab.io/app")!) } label: { Text(t("ios.openWeb")) }
                        .buttonStyle(SLButtonStyle(kind: .secondary)).padding(.top, 10)
                }

                Button { Task { await auth.logout() } } label: { HStack { Spacer(); Text(t("ios.settings.logout")); Spacer() } }
                    .buttonStyle(SLButtonStyle(kind: .primary))
                    .padding(.top, 6)

                Text(t("ios.settings.version", ["v": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"]))
                    .font(.dm(12)).foregroundStyle(Color.slInkFaint).frame(maxWidth: .infinity)
            }
            .navigationTitle(t("ios.settings.title"))
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.dm(13, .semibold)).foregroundStyle(Color.slInkMuted).padding(.leading, 4)
            SLCard(padding: 0) { content().padding(.horizontal, 16) }
        }
    }
}
