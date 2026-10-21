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
    @State private var deleteOpen = false

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

                NoticeSettingsSection()

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

                if let url = ReviewAsk.writeReviewURL {
                    section(t("ios.settings.rateTitle")) {
                        Button { openURL(url) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "star.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.slMarker)
                                    .overlay(Image(systemName: "star").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.slAccent700))
                                Text(t("ios.settings.rate")).font(.dm(15)).foregroundStyle(Color.slInk)
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.slInkFaint)
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

                // the account can be ended here, as it can on the web
                Button { deleteOpen = true } label: { HStack { Spacer(); Text(t("ios.settings.delete.button")).font(.dm(13.5, .semibold)); Spacer() } }
                    .foregroundStyle(Color.slBad).padding(.vertical, 10)
                    .accessibilityIdentifier("settings-delete")

                Text(t("ios.settings.version", ["v": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"]))
                    .font(.dm(12)).foregroundStyle(Color.slInkFaint).frame(maxWidth: .infinity)
            }
            .navigationTitle(t("ios.settings.title"))
            .sheet(isPresented: $deleteOpen) { DeleteAccountSheet().environmentObject(auth) }
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.dm(13, .semibold)).foregroundStyle(Color.slInkMuted).padding(.leading, 4)
            SLCard(padding: 0) { content().padding(.horizontal, 16) }
        }
    }
}

/// Ending the account: what goes with it, the address typed to confirm, one red button. The API refuses a wrong address.
struct DeleteAccountSheet: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""
    @State private var busy = false
    @State private var error: String?

    private var email: String { auth.user?.email ?? "" }
    private var matches: Bool { typed.trimmingCharacters(in: .whitespaces).lowercased() == email.lowercased() && !email.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(t("ios.settings.delete.hand")).font(.hand(24)).foregroundStyle(Color.slAccent600)
                    Text(t("ios.settings.delete.title")).font(.dm(22, .bold)).tracking(-0.3).foregroundStyle(Color.slInk)
                    Text(t("ios.settings.delete.text")).font(.dm(14.5)).foregroundStyle(Color.slInkSoft)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(t("ios.settings.delete.confirm", ["email": email])).font(.dm(13, .semibold)).foregroundStyle(Color.slInk)
                        TextField(email, text: $typed)
                            .textInputAutocapitalization(.never).keyboardType(.emailAddress).autocorrectionDisabled()
                            .font(.dm(15)).padding(.horizontal, 14).frame(height: 46)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(matches ? Color.slAccent600 : Color.slLine))
                            .accessibilityIdentifier("delete-confirm")
                    }
                    .padding(.top, 6)

                    if let error { Text(error).font(.dm(13, .semibold)).foregroundStyle(Color.slBad) }

                    Button {
                        Task {
                            busy = true; error = nil
                            do { try await auth.deleteAccount(confirm: typed) } catch { self.error = error.localizedDescription }
                            busy = false
                        }
                    } label: {
                        HStack { Spacer(); Text(busy ? "…" : t("ios.settings.delete.button")); Spacer() }
                    }
                    .buttonStyle(SLButtonStyle(kind: .primary)).tint(Color.slBad)
                    .disabled(!matches || busy)
                    .opacity(matches ? 1 : 0.5)
                    .padding(.top, 8)
                    .accessibilityIdentifier("delete-go")

                    Button(t("ios.settings.delete.keep")) { dismiss() }.font(.dm(14, .semibold)).foregroundStyle(Color.slInkMuted).frame(maxWidth: .infinity)
                }
                .padding(20)
            }
            .background(Color.slBg)
            .navigationTitle(t("ios.settings.delete.nav"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }
}
