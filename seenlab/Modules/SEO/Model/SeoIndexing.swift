//
//  SeoIndexing.swift
//  seenlab
//
//  The AI-readiness extras: IndexNow key and last submit (seo/indexnow), what Bing has indexed
//  (seo/bing) and the latest schema markup draft (seo_schema job).
//

import Foundation

struct SeoIndexNow: Decodable {
    let key: String?
    let keyUrl: String?
    let submittedAt: String?
    let bingCheck: Bool?
}

struct SeoBing: Decodable {
    let configured: Bool?
    let indexed: Double?
}

struct SeoSchemaDraft: Decodable {
    let blocks: [Block]?

    struct Block: Decodable {
        let type: String?
        let `where`: String?
        let why: String?
        let code: String?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            type = c.seoTry(.type)
            `where` = c.seoTry(.where)
            why = c.seoTry(.why)
            code = c.seoTry(.code)
        }
        private enum CodingKeys: String, CodingKey { case type, `where`, why, code }
    }
}

/// What the AI tab loads next to the audit summary.
struct SeoAiExtras {
    let indexNow: SeoIndexNow?
    let bing: SeoBing?
    let schema: SeoSchemaDraft?
}
