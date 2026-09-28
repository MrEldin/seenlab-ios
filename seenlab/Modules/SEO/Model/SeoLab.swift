//
//  SeoLab.swift
//  seenlab
//
//  The lab (seo/lab), built on Search Console: pages seen but not clicked, searches almost on page 1,
//  pages losing clicks, and before/after experiments.
//

import Foundation

struct SeoLabReport: Decodable {
    let connected: Bool?
    let lowCtr: [LowCtr]?
    let striking: [Striking]?
    let decaying: [Decaying]?
    let experiments: [Experiment]?

    struct LowCtr: Decodable {
        let url: String?
        let clicks: Double?
        let impressions: Double?
        let ctr: Double?
        let position: Double?
        let expectedCtr: Double?
        let gain: Double?
    }

    struct Striking: Decodable {
        let query: String?
        let url: String?
        let impressions: Double?
        let clicks: Double?
        let position: Double?
        let gain: Double?
    }

    struct Decaying: Decodable {
        let url: String?
        let clicks: Double?
        let prevClicks: Double?
        let change: Double?
        let position: Double?
        let prevPosition: Double?
    }

    struct Experiment: Decodable, Identifiable {
        let id: Int
        let url: String?
        let note: String?
        let startedOn: String?
        let before: Window?
        let after: Window?
        let ready: Bool?

        struct Window: Decodable {
            let days: Int?
            let clicksPerDay: Double?
            let ctr: Double?
            let position: Double?
        }
    }
}
