//
//  Project.swift
//  seenlab
//
//  A project is an iOS app, an Android app or a website (a website has SEO and AIO, no ASO).
//

import Foundation

struct Project: Decodable, Identifiable, Hashable {
    let id: Int
    let platform: String?
    let name: String
    let subtitle: String?
    let developer: String?
    let iconUrl: String?
    let storeUrl: String?
    let websiteUrl: String?
    let rating: Double?
    let ratingCount: Double?
    let ready: Bool?

    var hasStore: Bool { platform == "ios" || platform == "android" }
    var storeName: String { platform == "android" ? "Google Play" : "App Store" }
    var platformIcon: String {
        switch platform { case "android": "a.circle"; case "web": "globe"; default: "apple.logo" }
    }
    /// The line under the name: developer for store apps, the host for websites.
    var byline: String { hasStore ? (developer ?? storeName) : Fmt.host(websiteUrl) }
}
