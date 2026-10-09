//
//  Notice.swift
//  seenlab
//
//  One notification, as the API sends it (GET admin/notifications): already in the person's language.
//

import Foundation

struct Notice: Decodable, Identifiable, Equatable {
    struct Actor: Decodable, Equatable { var id: Int?; var name: String?; var initials: String?; var color: String? }

    var id: String
    var kind: String
    var category: String
    var title: String
    var body: String
    var url: String?
    var projectId: Int?
    var project: String?
    var actor: Actor?
    var board: Int?
    var card: String?
    var read: Bool
    var at: String?

    var date: Date? { at.flatMap { ISO8601DateFormatter().date(from: $0) } }

    var icon: String {
        switch kind {
        case "team_joined": return "person.badge.plus"
        case "team_removed": return "person.badge.minus"
        case "comment": return "text.bubble"
        case "assigned": return "checklist"
        case "morning": return "sunrise"
        case "listed": return "list.bullet.clipboard"
        case "test_done": return "flask"
        case "weekly": return "calendar"
        case "job_done": return "sparkles"
        case "job_failed": return "exclamationmark.triangle"
        case "trial_ending", "trial_ended": return "creditcard"
        default: return "bell"
        }
    }
}

struct NoticePage: Decodable { var items: [Notice]; var more: Bool; var unread: Int }

/// Where a notice leads in the app.
struct NoticeTarget: Equatable {
    var channel: Channel
    var projectId: Int?
    var board: Int?
    var card: String?
    var showList = false

    /// The web paths the notices carry, read as the app's tabs.
    static func from(url: String?, projectId: Int?, board: Int?, card: String?) -> NoticeTarget {
        let path = url ?? ""
        let comps = URLComponents(string: "https://seenlab.io" + path)
        let q = { (name: String) in comps?.queryItems?.first { $0.name == name }?.value }
        let boardId = board ?? q("board").flatMap(Int.init)
        let cardId = card ?? q("card")
        switch comps?.path ?? "" {
        case let p where p.hasPrefix("/app/growth"): return NoticeTarget(channel: .growth, projectId: projectId, board: path.contains("board=") ? boardId : nil, card: cardId)
        case let p where p.hasPrefix("/app/google"): return NoticeTarget(channel: .seo, projectId: projectId)
        case let p where p.hasPrefix("/app/ai"): return NoticeTarget(channel: .aio, projectId: projectId)
        case "/app/notifications", "/app/checkout", "": return NoticeTarget(channel: .settings, projectId: projectId, showList: true)
        default: return NoticeTarget(channel: .aso, projectId: projectId)
        }
    }
}
