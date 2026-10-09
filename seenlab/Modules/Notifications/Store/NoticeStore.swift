//
//  NoticeStore.swift
//  seenlab
//
//  The person's notifications: the bell's count (and the app icon's badge) and the list.
//  One store for the whole app; `route` is where a tapped notice (in the list or a push) asks to go.
//

import Foundation
import UserNotifications
import Combine

@MainActor
final class NoticeStore: ObservableObject {
    static let shared = NoticeStore()

    @Published private(set) var items: [Notice] = []
    @Published private(set) var unread = 0
    @Published private(set) var more = false
    @Published private(set) var loading = false
    /// A tapped notice: MainView switches to its tab and project, the board opens the card.
    @Published var route: NoticeTarget?

    func load() async {
        loading = true
        defer { loading = false }
        guard let page = try? await NetworkManager.shared.request(SeenlabAPI.notifications(), as: NoticePage.self) else { return }
        items = page.items; more = page.more; setUnread(page.unread)
    }

    func loadMore() async {
        guard more, let last = items.last?.at else { return }
        guard let page = try? await NetworkManager.shared.request(SeenlabAPI.notifications(before: last), as: NoticePage.self) else { return }
        items += page.items.filter { n in !items.contains { $0.id == n.id } }; more = page.more; setUnread(page.unread)
    }

    /// Just the count (the bell, the badge) without the list.
    func refreshCount() async {
        guard let page = try? await NetworkManager.shared.request(SeenlabAPI.notifications(unread: true), as: NoticePage.self) else { return }
        setUnread(page.unread)
    }

    func open(_ n: Notice) {
        markRead(n)
        route = NoticeTarget.from(url: n.url, projectId: n.projectId, board: n.board, card: n.card)
    }

    func markRead(_ n: Notice) {
        guard let i = items.firstIndex(where: { $0.id == n.id }), !items[i].read else { return }
        items[i].read = true
        setUnread(max(0, unread - 1))
        Task { _ = try? await NetworkManager.shared.request(SeenlabAPI.noticeRead(n.id), as: JSONValue.self) }
    }

    func readAll() {
        for i in items.indices { items[i].read = true }
        setUnread(0)
        Task { _ = try? await NetworkManager.shared.request(SeenlabAPI.noticesReadAll, as: JSONValue.self) }
    }

    func reset() { items = []; unread = 0; more = false; route = nil; UNUserNotificationCenter.current().setBadgeCount(0) }

    private func setUnread(_ n: Int) {
        unread = n
        UNUserNotificationCenter.current().setBadgeCount(n)
    }
}
