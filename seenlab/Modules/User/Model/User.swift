//
//  User.swift
//  seenlab
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

    var displayName: String {
        let n = [firstName, lastName].compactMap { $0?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
        return n.isEmpty ? (email?.components(separatedBy: "@").first ?? "Seenlab") : n
    }

    var initials: String {
        let parts = [firstName, lastName].compactMap { $0?.first.map(String.init) }
        return parts.isEmpty ? String((email ?? "SL").prefix(2)).uppercased() : parts.joined().uppercased()
    }
}

struct LoginResponse: Decodable {
    let accessToken: String
}
