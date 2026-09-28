//
//  SeoSite.swift
//  seenlab
//
//  The website behind a project and its latest crawl (seo/site, seo/audit, seo/links).
//  Every field is optional: older audits and half-finished jobs leave parts out.
//

import Foundation

/// seo/site: the website, Google connection, a summary of the latest audit and the llms.txt draft.
struct SeoSite: Decodable {
    let websiteUrl: String?
    let google: SeoGoogle?
    let audit: Audit?
    let llms: Job<SeoLlmsDraft>?
    let businessName: String?
    let sources: SeoSources?

    struct Audit: Decodable {
        let job: Job<JSONValue>?
        /// The report without pages and robots.
        let summary: SeoAuditReport?
    }

    var hasWebsite: Bool { !(websiteUrl ?? "").isEmpty }
}

struct SeoGoogle: Decodable {
    let configured: Bool?
    let connected: Bool?
    let email: String?
    let siteUrl: String?
    let lastSyncedAt: String?
    let error: String?
    let syncJob: Job<JSONValue>?
}

/// Where rankings come from: DataForSEO (serp) and/or Search Console.
struct SeoSources: Decodable {
    let serp: Bool?
    let gsc: Bool?
}

/// seo/audit: the latest audit job, the score over time and what changed since the previous audit.
struct SeoAuditJob: Decodable {
    let id: Int?
    let status: String?
    let result: SeoAuditReport?
    let error: String?
    let createdAt: String?
    let finishedAt: String?
    let history: [Point]?
    let diff: Diff?

    var isDone: Bool { status == "done" }
    var isRunning: Bool { status == "pending" || status == "running" }

    struct Point: Decodable {
        let date: String?
        let score: Double?
        let errors: Double?
        let warnings: Double?
    }

    struct Diff: Decodable {
        let since: String?
        let score: Double?
        let new: [String]?
        let fixed: [String]?
        let changed: [Change]?

        struct Change: Decodable {
            let code: String
            let from: Double?
            let to: Double?
        }
    }
}

/// One crawl of the site, as the audit job stores it.
struct SeoAuditReport: Decodable {
    let url: String?
    let crawledAt: String?
    let score: Double?
    let pagesCrawled: Int?
    let sitemap: Sitemap?
    let robots: Robots?
    let issues: [Issue]?
    let ai: SeoAiReport?
    let pagespeed: SeoPageSpeed?
    let pages: [Page]?
    /// While the crawl runs: pages read so far and the total.
    let progress: Double?
    let total: Double?

    struct Sitemap: Decodable {
        let found: Bool?
        let urls: Int?
        let files: [String]?
    }

    struct Robots: Decodable {
        let found: Bool?
        let text: String?
    }

    struct Issue: Decodable, Identifiable {
        let code: String
        let severity: String?
        let count: Int?
        let pages: [IssuePage]?
        var id: String { code }
    }

    struct IssuePage: Decodable {
        let url: String?
        /// A number (duplicates, images) or a text; null when the issue has no value.
        let value: JSONValue?
    }

    struct Page: Decodable {
        let url: String?
        let status: Int?
        let ms: Double?
        let title: String?
        let words: Int?
        let jsOnly: Bool?
        let issues: [PageIssue]?
    }

    struct PageIssue: Decodable {
        let code: String?
        let severity: String?
    }

    /// Pages affected per severity, the way the web counts them.
    func count(_ severity: String) -> Int {
        (issues ?? []).filter { $0.severity == severity }.reduce(0) { $0 + ($1.count ?? 0) }
    }
}

/// What AI crawlers can read: robots.txt rules per bot, llms.txt, schema.org types, JS-only pages.
struct SeoAiReport: Decodable {
    let bots: [Bot]?
    let llmsTxt: LlmsTxt?
    /// `{ "Organization": 18, … }`, or `[]` when the site has none.
    let schema: JSONValue?
    let jsOnlyPages: Int?
    let homeWords: Int?

    struct Bot: Decodable {
        let bot: String
        let owner: String?
        let kind: String?
        let allowed: Bool?
    }

    struct LlmsTxt: Decodable {
        let found: Bool?
        let size: Int?
    }

    /// Schema types found on the crawled pages with their counts, most used first.
    var schemaTypes: [(type: String, count: Int)] {
        schema?.object.map { ($0.key, $0.value.int ?? 0) }.sorted { $0.count > $1.count } ?? []
    }
}

/// Google PageSpeed Insights for the home page (mobile).
struct SeoPageSpeed: Decodable {
    let score: Double?
    let lab: Metrics?
    let field: Metrics?
    let error: String?

    struct Metrics: Decodable {
        let lcpMs: Double?
        let inpMs: Double?
        let cls: Double?
        let tbtMs: Double?
        let fcpMs: Double?
    }
}

/// The llms.txt draft (llms_txt job result).
struct SeoLlmsDraft: Decodable {
    let llmsTxt: String?
    let notes: [String]?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        llmsTxt = c.seoTry(.llmsTxt)
        notes = c.seoTry(.notes)
    }
    private enum CodingKeys: String, CodingKey { case llmsTxt, notes }
}

/// seo/links: a page with few or no internal links and the pages to link it from.
struct SeoLink: Decodable {
    let url: String?
    let title: String?
    let inbound: Int?
    let anchor: String?
    let from: [From]?

    struct From: Decodable {
        let url: String?
        let title: String?
    }
}

extension KeyedDecodingContainer {
    /// Decodes a field if it is there and has the expected type; AI-written results are not always tidy.
    func seoTry<T: Decodable>(_ key: Key) -> T? { (try? decodeIfPresent(T.self, forKey: key)) ?? nil }
}
