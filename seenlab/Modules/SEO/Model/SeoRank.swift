//
//  SeoRank.swift
//  seenlab
//
//  Google positions (seo/keywords): tracked keywords, organic and local, and who outranks the site.
//

import Foundation

struct SeoRankData: Decodable {
    let keywords: [SeoKeyword]?
    let competitors: [Competitor]?
    let limits: Limits?
    let sources: SeoSources?
    let businessName: String?
    let job: Job<JSONValue>?

    struct Competitor: Decodable {
        let domain: String
        let keywords: Int?
        let ahead: Int?
        let avgPosition: Double?
    }

    struct Limits: Decodable {
        let organic: Int?
        let local: Int?
    }

    var organic: [SeoKeyword] { (keywords ?? []).filter { $0.kind == "organic" } }
    var local: [SeoKeyword] { (keywords ?? []).filter { $0.kind == "local" } }
}

struct SeoKeyword: Decodable, Identifiable {
    let id: Int
    let kind: String?
    let term: String?
    let country: String?
    let location: String?
    let position: Double?
    let previous: Double?
    let delta: Double?
    let best: Double?
    let url: String?
    let source: String?
    let aiOverview: Bool?
    let aiOverviewOwn: Bool?
    let top: [Top]?
    let capturedOn: String?
    let series: [Point]?

    /// A site above (organic) or a place in the map pack (local).
    struct Top: Decodable {
        let position: Int?
        let domain: String?
        let url: String?
        let title: String?
        let rating: Double?
        let reviews: Int?
    }

    struct Point: Decodable {
        let d: String?
        let p: Double?
    }
}
