//
//  AsoModels.swift
//  seenlab
//
//  What /admin/aso returns: the overview, tracked apps, keywords with their 30-day series, a keyword's
//  rank history, the listing audit, review summaries and the logged listing experiments. Keys arrive in
//  snake_case and are converted by the decoder (`avg_position` → `avgPosition`, `last_30d` → `last30d`).
//  Every field the API can omit or send as null is optional; numbers that can be fractional are Double.
//

import Foundation

// MARK: - Overview

struct AsoOverview: Decodable {
    let country: String?
    let countries: [String]?
    let platform: String?
    let own: AsoApp?
    let competitorsCount: Int?
    let keywordsCount: Int?
    let ranked: Int?
    let top10: Int?
    let top50: Int?
    let avgPosition: Double?
    let movers: [AsoMover]?
    let visibility: [AsoVisibilityPoint]?
    let recentChanges: [AsoRecentChange]?
    let insights: [AsoInsight]?
    let ratings: [AsoRatingPoint]?
    let lastTrack: Job<JSONValue>?
}

/// A keyword that moved since yesterday; `from`/`to` nil = outside the ranked depth.
struct AsoMover: Decodable, Hashable {
    let term: String
    let from: Double?
    let to: Double?
    let delta: Double?
}

struct AsoVisibilityPoint: Decodable, Hashable {
    let date: String
    let score: Double?
    let tracked: Double?
}

struct AsoRatingPoint: Decodable, Hashable {
    let date: String
    let count: Double?
    let new: Double?
    let rating: Double?
}

/// A rule-based insight; `value` is a number for most keys but a field list for `competitor_changed`.
struct AsoInsight: Decodable, Hashable {
    let level: String?
    let key: String
    let term: String?
    let value: JSONValue?
    let position: Double?
}

/// A listing change the daily snapshot noticed (own app or a competitor).
struct AsoRecentChange: Decodable, Hashable {
    let app: String?
    let isOwn: Bool?
    let date: String?
    let changes: [AsoFieldChange]?
}

struct AsoFieldChange: Decodable, Hashable {
    let field: String?
    let from: JSONValue?
    let to: JSONValue?
}

// MARK: - Apps

/// A tracked app (own or competitor). The /apps list adds the keyword stats and the last change.
struct AsoApp: Decodable, Identifiable, Hashable {
    let id: Int
    let platform: String?
    let name: String?
    let subtitle: String?
    let developer: String?
    let iconUrl: String?
    let storeUrl: String?
    let version: JSONValue?
    let rating: Double?
    let ratingCount: Double?
    let price: JSONValue?
    let genres: [String]?
    let isOwn: Bool?
    let versionReleasedAt: String?
    let screenshots: [String]?
    let keywordsRanked: Int?
    let keywordsTotal: Int?
    let top10: Int?
    let avgPosition: Double?
    let lastChange: LastChange?

    struct LastChange: Decodable, Hashable {
        let date: String?
        let changes: [AsoFieldChange]?
    }
}

// MARK: - Keywords

struct AsoKeyword: Decodable, Identifiable, Hashable {
    let id: Int
    let term: String
    let country: String?
    let source: String?
    let position: Double?
    let previous: Double?
    let delta: Double?
    let best: Double?
    let series: [Point]?
    let difficulty: Double?
    let traffic: Double?
    let resultsCount: Double?
    let topApps: [AsoTopApp]?
    let competitors: [Competitor]?
    let trackedAt: String?

    /// One day of the own app's rank (`p` nil = not ranked that day).
    struct Point: Decodable, Hashable {
        let d: String
        let p: Double?
    }

    /// A tracked competitor's rank for this keyword.
    struct Competitor: Decodable, Hashable {
        let appId: Int?
        let name: String?
        let iconUrl: String?
        let position: Double?
    }

    /// traffic − difficulty, the web's "opportunity" sort.
    var opportunity: Double { (traffic ?? 0) - (difficulty ?? 0) }
}

/// One of the store's top results for a keyword.
struct AsoTopApp: Decodable, Hashable {
    let position: Double?
    let name: String?
    let rating: Double?
    let ratingCount: Double?
    let iconUrl: String?
}

/// /keywords/{id}/history: the dates, and every tracked app's position on each.
struct AsoKeywordHistory: Decodable {
    let dates: [String]?
    let series: [Series]?
    let topApps: [AsoTopApp]?

    struct Series: Decodable, Hashable {
        let appId: Int?
        let name: String?
        let isOwn: Bool?
        let iconUrl: String?
        let positions: [Double?]?
    }
}

// MARK: - Audit

struct AsoAudit: Decodable {
    let country: String?
    let platform: String?
    let fields: Fields?
    let indexedWords: [String]?
    let duplicates: [Duplicate]?
    let coverage: [Coverage]?
    let unusedFieldWords: [String]?
    let issues: [Issue]?
    let score: Double?

    struct Fields: Decodable {
        let title: AsoAuditField?
        let subtitle: AsoAuditField?
        let keywordField: AsoAuditField?
        let description: AsoAuditField?
    }

    struct Duplicate: Decodable, Hashable {
        let word: String?
        let `where`: String?
    }

    struct Coverage: Decodable, Hashable {
        let term: String
        let covered: Bool?
        let missingWords: [String]?
        let position: Double?
        let difficulty: Double?
        let traffic: Double?
    }

    struct Issue: Decodable, Hashable {
        let level: String?
        let key: String
        let count: Int?
    }

    var isAndroid: Bool { platform == "android" }
}

/// One indexed field: its text and length against the store's limit.
struct AsoAuditField: Decodable, Hashable {
    let text: String?
    let length: Int?
    let max: Int?
    let words: [String]?
}

// MARK: - Reviews

/// Per tracked app: the star distribution and the freshest complaints and praise.
struct AsoReviewSummary: Decodable, Identifiable, Hashable {
    let appId: Int
    let name: String?
    let iconUrl: String?
    let isOwn: Bool?
    let total: Int?
    let distribution: [Int]?
    let avg: Double?
    let last30d: Int?
    let lowStarShare: Double?
    let complaints: [Review]?
    let praise: [Review]?

    var id: Int { appId }

    struct Review: Decodable, Hashable {
        let title: String?
        let body: String?
        let rating: Double?
        let at: String?
    }
}

// MARK: - Listing experiments

/// A listing change logged on the web, with its measured effect on ranks.
struct AsoListingChange: Decodable, Identifiable, Hashable {
    let id: Int
    let changedAt: String?
    let note: String?
    let effect: Effect?

    struct Effect: Decodable, Hashable {
        let ready: Bool?
        let before: Snapshot?
        let after: Snapshot?
        let daysAfter: Int?
        let perKeyword: [KeywordEffect]?
    }

    struct Snapshot: Decodable, Hashable {
        let avgPosition: Double?
        let ranked: Double?
        let visibility: Double?
    }

    struct KeywordEffect: Decodable, Hashable {
        let term: String
        let before: Double?
        let after: Double?
        let delta: Double?
    }
}
