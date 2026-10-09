//
//  NoticeViews.swift
//  seenlab
//
//  The bell (with the unread count), the list of notifications in a sheet, and the push choices in Settings.
//

import SwiftUI
import UserNotifications

/// The bell in a toolbar or the board's header: the count, tap for the list.
struct NotificationBell: View {
    @ObservedObject private var store = NoticeStore.shared
    @State private var open = false
    var size: CGFloat = 34

    var body: some View {
        Button { open = true } label: {
            Image(systemName: store.unread > 0 ? "bell.badge" : "bell")
                .font(.system(size: 16, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(store.unread > 0 ? Color.slAccent600 : Color.slInkSoft, Color.slInkSoft)
                .frame(width: size, height: size)
                .overlay(alignment: .topTrailing) {
                    if store.unread > 0 {
                        Text(store.unread > 99 ? "99+" : "\(store.unread)").font(.dm(10, .heavy)).foregroundStyle(.white)
                            .padding(.horizontal, 4).frame(minWidth: 17, minHeight: 17).background(Color.slAccent600, in: Capsule())
                            .overlay(Capsule().stroke(.white, lineWidth: 2)).offset(x: 5, y: -3)
                    }
                }
        }
        .accessibilityLabel(t("notify.title"))
        .accessibilityIdentifier("notifications-button")
        .sheet(isPresented: $open) { NoticesSheet() }
        .onChange(of: store.route) { _, r in if r != nil { open = false } }
    }
}

/// All notifications, newest first, grouped by day.
struct NoticesSheet: View {
    @ObservedObject private var store = NoticeStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var onlyUnread = false

    private var shown: [Notice] { onlyUnread ? store.items.filter { !$0.read } : store.items }
    private var days: [(String, [Notice])] {
        var out: [(String, [Notice])] = []
        for n in shown {
            let d = dayLabel(n.date)
            if out.last?.0 == d { out[out.count - 1].1.append(n) } else { out.append((d, [n])) }
        }
        return out
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Picker("", selection: $onlyUnread) {
                        Text(t("notify.filter.all")).tag(false)
                        Text(t("notify.filter.unread")).tag(true)
                    }
                    .pickerStyle(.segmented).padding(.horizontal, 16).padding(.bottom, 8)

                    if shown.isEmpty, !store.loading {
                        VStack(spacing: 10) {
                            Image(systemName: "testtube.2").font(.system(size: 44, weight: .ultraLight)).foregroundStyle(Color.slAccent600)
                            Text(t("notify.emptyHand")).font(.hand(22)).foregroundStyle(Color.slAccent600)
                            Text(onlyUnread ? t("notify.emptyUnread") : t("notify.empty")).font(.dm(14)).foregroundStyle(Color.slInkSoft).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(40)
                    }
                    ForEach(days, id: \.0) { day, items in
                        Text(day.uppercased()).font(.dm(11, .bold)).tracking(0.8).foregroundStyle(Color.slInkFaint).padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 6)
                        VStack(spacing: 2) {
                            ForEach(items) { n in
                                Button { store.open(n); dismiss() } label: { NoticeRowView(n: n) }.buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    if store.more {
                        Button(t("notify.more")) { Task { await store.loadMore() } }.buttonStyle(SLButtonStyle(kind: .secondary)).frame(maxWidth: .infinity).padding(.vertical, 16)
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Color.slBg)
            .refreshable { await store.load() }
            .navigationTitle(t("notify.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(t("notify.close")) { dismiss() }.font(.dm(15)) }
                if store.unread > 0 { ToolbarItem(placement: .topBarTrailing) { Button(t("notify.readAll")) { store.readAll() }.font(.dm(14, .semibold)) } }
            }
        }
        .task { await store.load() }
        .presentationDragIndicator(.visible)
    }

    private func dayLabel(_ d: Date?) -> String {
        guard let d else { return "" }
        let cal = Calendar.current
        if cal.isDateInToday(d) { return t("notify.today") }
        if cal.isDateInYesterday(d) { return t("notify.yesterday") }
        let f = DateFormatter(); f.locale = Locale(identifier: L10n.shared.locale); f.setLocalizedDateFormatFromTemplate("d MMMM")
        return f.string(from: d)
    }
}

struct NoticeRowView: View {
    let n: Notice

    private var tone: (Color, Color) {
        if n.kind == "job_failed" { return (Color.slBadSoft, Color.slBad) }
        switch n.category {
        case "team": return (Color.slTint100, Color.slAccent700)
        case "ai": return (Color(hex: "#EEE8FB"), Color(hex: "#6C4FD1"))
        case "account": return (Color.slBg, Color.slInkSoft)
        default: return (Color.slMarker.opacity(0.35), Color.slInk)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if let a = n.actor, let initials = a.initials {
                    Text(initials).font(.dm(12.5, .heavy)).foregroundStyle(.white).frame(width: 40, height: 40).background(Color(hex: a.color ?? "#0F6E6E"), in: Circle())
                    Image(systemName: n.icon).font(.system(size: 9, weight: .bold)).foregroundStyle(tone.1).frame(width: 18, height: 18).background(tone.0, in: Circle()).overlay(Circle().stroke(.white, lineWidth: 2)).offset(x: 4, y: 4)
                } else {
                    Image(systemName: n.icon).font(.system(size: 17, weight: .medium)).foregroundStyle(tone.1).frame(width: 40, height: 40).background(tone.0, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(n.title).font(.dm(14.5, .semibold)).foregroundStyle(Color.slInk).fixedSize(horizontal: false, vertical: true)
                if !n.body.isEmpty { Text(n.body).font(.dm(13.5)).foregroundStyle(Color.slInkSoft).lineLimit(2) }
                HStack(spacing: 6) {
                    if let d = n.date { Text(d, style: .relative).font(.dm(11.5)).foregroundStyle(Color.slInkMuted) }
                    if let p = n.project, !n.title.contains(p) { Text("· " + p).font(.dm(11.5)).foregroundStyle(Color.slInkMuted).lineLimit(1) }
                }
            }
            Spacer(minLength: 0)
            if !n.read { Circle().fill(Color.slAccent600).frame(width: 8, height: 8).padding(.top, 6) }
        }
        .padding(12)
        .background(n.read ? Color.clear : Color.slTint50, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }
}

/// Settings → Notifications: what reaches this phone, the system permission, a test.
struct NoticeSettingsSection: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var phase
    @State private var prefs: [String: [String: Bool]] = [:]
    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var said: String?
    private let categories = ["team", "results", "ai", "account"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("notify.title")).font(.dm(13, .semibold)).foregroundStyle(Color.slInkMuted).padding(.leading, 4)
            SLCard {
                if status == .denied {
                    Text(t("notify.ios.off")).font(.dm(13.5)).foregroundStyle(Color.slInkSoft)
                    Button(t("notify.ios.openSettings")) { if let u = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(u) } }
                        .buttonStyle(SLButtonStyle(kind: .secondary)).padding(.top, 10)
                } else if status == .notDetermined {
                    Text(t("notify.ios.ask")).font(.dm(13.5)).foregroundStyle(Color.slInkSoft)
                    Button(t("notify.ios.allow")) { Task { await PushManager.shared.start(); status = await PushManager.shared.status() } }
                        .buttonStyle(SLButtonStyle(kind: .primary)).padding(.top, 10)
                } else {
                    Text(t("notify.ios.phoneHint")).font(.dm(13)).foregroundStyle(Color.slInkMuted).padding(.bottom, 4)
                    ForEach(categories, id: \.self) { c in
                        Toggle(isOn: Binding(get: { prefs[c]?["phone"] ?? true }, set: { v in save(c, v) })) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(t("notify.cat." + c)).font(.dm(15, .semibold)).foregroundStyle(Color.slInk)
                                Text(t("notify.catHint." + c)).font(.dm(12)).foregroundStyle(Color.slInkMuted)
                            }
                        }
                        .tint(Color.slAccent600).padding(.vertical, 7)
                        if c != categories.last { Divider() }
                    }
                    Button { test() } label: { Label(t("notify.test.button"), systemImage: "paperplane") }
                        .buttonStyle(SLButtonStyle(kind: .secondary)).padding(.top, 12)
                    if let said { Text(said).font(.dm(12.5)).foregroundStyle(Color.slGood).padding(.top, 6) }
                }
            }
        }
        .task { await refresh() }
        .onChange(of: phase) { _, p in if p == .active { Task { await refresh() } } }
    }

    private func refresh() async {
        status = await PushManager.shared.status()
        if let s = try? await NetworkManager.shared.request(SeenlabAPI.noticeSettings, as: NoticeSettings.self) { prefs = s.prefs }
    }

    private func save(_ c: String, _ v: Bool) {
        prefs[c, default: [:]]["phone"] = v
        Task { if let s = try? await NetworkManager.shared.request(SeenlabAPI.saveNoticeSettings([c: ["phone": v]]), as: NoticeSettings.self) { prefs = s.prefs } }
    }

    private func test() {
        Task {
            do { _ = try await NetworkManager.shared.request(SeenlabAPI.noticeTest, as: JSONValue.self); said = t("notify.test.sent") }
            catch { said = t("notify.test.wait") }
            try? await Task.sleep(for: .seconds(5)); said = nil
        }
    }
}

struct NoticeSettings: Decodable { var prefs: [String: [String: Bool]] }
