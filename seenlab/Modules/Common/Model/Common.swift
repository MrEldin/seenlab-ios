//
//  Common.swift
//  seenlab
//
//  Shapes shared by the channels: a background job (aso_jobs) and the morning action plan.
//

import Foundation

/// A background job as the API returns it; `result` depends on its type.
struct Job<Result: Decodable>: Decodable {
    let id: Int?
    let type: String?
    let status: String?
    let input: JSONValue?
    let result: Result?
    let error: String?
    let createdAt: String?
    let finishedAt: String?

    var isDone: Bool { status == "done" }
    var isRunning: Bool { status == "pending" || status == "running" }
}

/// `{ latest, running }` from the SEO jobs/latest and actions endpoints.
struct LatestJob<Result: Decodable>: Decodable {
    let latest: Job<Result>?
    let running: Job<Result>?

    /// The finished result, if there is one.
    var result: Result? { latest?.isDone == true ? latest?.result : nil }
}

/// The morning plan: a few actions across SEO and AIO, each with steps and a ready draft.
struct ActionPlan: Decodable {
    let actions: [Action]?
    let generatedAt: String?

    struct Action: Decodable, Identifiable {
        let id: String
        let channel: String?
        let kind: String?
        let impact: Double?
        let link: Link?
        let title: String?
        let why: String?
        let steps: [String]?
        let draft: String?

        struct Link: Decodable { let tab: String? }
    }
}
