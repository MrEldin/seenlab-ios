//
//  SeoResearch.swift
//  seenlab
//
//  Research results (the latest seo_ideas and seo_brief jobs). The brief is written by AI, so it is
//  decoded leniently: a field of an unexpected type is left out instead of failing the whole result.
//

import Foundation

/// Keyword ideas around a seed.
struct SeoIdeas: Decodable {
    let seed: String?
    let country: String?
    let source: String?
    let ideas: [Idea]?
    let generatedAt: String?

    struct Idea: Decodable {
        let term: String
        let volume: Double?
        let difficulty: Double?
        let cpc: Double?
        let tracked: Bool?
        let gsc: Gsc?

        struct Gsc: Decodable {
            let impressions: Double?
            let clicks: Double?
            let position: Double?
        }
    }
}

/// The content plan for a keyword: what the top pages cover and what the page needs.
struct SeoBrief: Decodable {
    let keyword: String?
    let country: String?
    let ownUrl: String?
    let ownPosition: Double?
    let pages: [Page]?
    let brief: Content?
    let generatedAt: String?

    struct Page: Decodable {
        let position: Int?
        let domain: String?
        let url: String?
        let title: String?
        let words: Int?
        let headings: [String]?
    }

    struct Content: Decodable {
        let intent: String?
        let summary: String?
        let missing: [String]?
        let title: String?
        let metaDescription: String?
        let intro: String?
        let outline: [Section]?
        let faq: [Faq]?
        let internalLinks: [String]?
        let words: JSONValue?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            intent = c.seoTry(.intent)
            summary = c.seoTry(.summary)
            missing = c.seoTry(.missing)
            title = c.seoTry(.title)
            metaDescription = c.seoTry(.metaDescription)
            intro = c.seoTry(.intro)
            outline = c.seoTry(.outline)
            faq = c.seoTry(.faq)
            internalLinks = c.seoTry(.internalLinks)
            words = c.seoTry(.words)
        }
        private enum CodingKeys: String, CodingKey { case intent, summary, missing, title, metaDescription, intro, outline, faq, internalLinks, words }

        struct Section: Decodable {
            let heading: String?
            let points: [String]?
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                heading = c.seoTry(.heading)
                points = c.seoTry(.points)
            }
            private enum CodingKeys: String, CodingKey { case heading, points }
        }

        struct Faq: Decodable {
            let q: String?
            let a: String?
        }
    }
}

/// The two research results together.
struct SeoResearch {
    let ideas: LatestJob<SeoIdeas>?
    let brief: LatestJob<SeoBrief>?
}
