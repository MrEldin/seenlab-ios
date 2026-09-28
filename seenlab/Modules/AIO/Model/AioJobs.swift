//
//  AioJobs.swift
//  seenlab
//
//  Results of the AIO writing jobs, from GET /admin/aio/jobs/latest?type=… (a list of finished jobs,
//  newest first): the pitch for a page that should mention the product, and a page written for AI.
//

import Foundation

/// `aio_outreach`: how to get onto one cited page (email to the author, reply in a thread, a listing).
struct AioOutreachResult: Decodable, Hashable {
    let url: String?
    let kind: String?
    let draft: Draft?

    struct Draft: Decodable, Hashable {
        let summary: String?
        let steps: [String]?
        let email: Email?
        let reply: String?
        let listing: String?
    }

    struct Email: Decodable, Hashable {
        let subject: String?
        let body: String?
    }
}

/// `aio_page`: a comparison / alternatives / best-of page with its FAQ and schema.
struct AioPageResult: Decodable, Hashable {
    let kind: String?
    let target: String?
    let page: Page?

    struct Page: Decodable, Hashable {
        let title: String?
        let slug: String?
        let metaDescription: String?
        let markdown: String?
        let schemaCode: String?
    }
}
