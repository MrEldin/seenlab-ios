//
//  User.swift
//  seenlab
//
//  The signed-in person (GET /api/auth/user) and the plan their account runs on (`subscription`,
//  built by the API's Plans\Plan::toArray()).
//

import Foundation

struct User: Decodable {
    let id: Int
    let firstName: String?
    let lastName: String?
    let email: String?
    let locale: String?
    let company: String?
    let plan: String?
    let paidUntil: String?
    let subscription: Subscription?

    var displayName: String {
        let n = [firstName, lastName].compactMap { $0?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
        return n.isEmpty ? (email?.components(separatedBy: "@").first ?? "Seenlab") : n
    }

    var initials: String {
        let parts = [firstName, lastName].compactMap { $0?.first.map(String.init) }
        return parts.isEmpty ? String((email ?? "SL").prefix(2)).uppercased() : parts.joined().uppercased()
    }
}

/// What the account's plan allows today, as the API sends it. The API enforces all of it; the app only
/// reads it to hide what the plan does not include. Missing lists (`null`) mean "everything".
struct Subscription: Decodable {
    let key: String?
    let label: String?
    let trial: Bool?
    let trialEndsAt: String?
    let trialDaysLeft: Int?
    let paidUntil: String?
    /// The premium AI/store tools.
    let tools: Bool?
    /// The weekly email.
    let digest: Bool?
    /// AI assistants the plan asks (AIO); null = every configured engine.
    let engines: [String]?
    /// Channels the plan includes (`aso`, `seo`, `aio`); null or absent = all three.
    let channels: [String]?

    /// Whether the plan includes a channel. Settings is always there.
    func includes(_ channel: Channel) -> Bool {
        guard channel != .settings, let channels else { return true }
        return channels.contains(channel.rawValue)
    }
}

struct LoginResponse: Decodable {
    let accessToken: String
}
