//
//  SeoConsole.swift
//  seenlab
//
//  Search Console numbers (seo/google/performance): totals against the previous period, the daily
//  series, and the rows for searches, pages and opportunities. `{ "empty": true }` when Google sent nothing.
//

import Foundation

struct SeoGscReport: Decodable {
    let empty: Bool?
    let range: Range?
    let totals: Totals?
    let prev: Totals?
    let series: Series?
    let queries: [Row]?
    let pages: [Row]?
    let opportunities: [Row]?

    var isEmpty: Bool { empty == true || totals == nil }

    struct Range: Decodable {
        let from: String?
        let to: String?
        let days: Int?
    }

    struct Totals: Decodable {
        let clicks: Double?
        let impressions: Double?
        let ctr: Double?
        let position: Double?
    }

    struct Series: Decodable {
        let labels: [String]?
        let clicks: [Double?]?
        let impressions: [Double?]?
        let position: [Double?]?
    }

    struct Row: Decodable {
        let key: String
        let clicks: Double?
        let impressions: Double?
        let ctr: Double?
        let position: Double?
        let prevPosition: Double?
        let prevClicks: Double?
    }
}
