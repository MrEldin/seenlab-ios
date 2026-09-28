//
//  AioPrompt.swift
//  seenlab
//
//  GET /admin/aio/prompts/{id} — the latest answer of every assistant to one prompt, with the products it
//  named, the sources it cited, its claims about the product and 90 days of history.
//

import Foundation

struct AioPromptDetail: Decodable {
    let id: Int?
    let text: String?
    let isActive: Bool?
    let answers: [AioAnswer]?
    let history: AioMap<[AioHistoryPoint]>?
    let names: [String]?
}

struct AioAnswer: Decodable, Identifiable, Hashable {
    let engine: String
    let model: String?
    let capturedOn: String?
    let mentioned: Bool?
    let position: Double?
    let sentiment: String?
    let excerpt: String?
    let brands: [AioAnswerBrand]?
    let citations: [String]?
    let answer: String?
    let error: JSONValue?
    let sample: Int?
    let claims: [AioClaim]?

    /// One tab per answer: the engine, plus the sample number when it was asked more than once.
    var id: String { "\(engine):\(sample ?? 1)" }

    var errorText: String? {
        switch error {
        case .string(let s) where !s.isEmpty: return s
        case .bool(true): return "—"
        default: return nil
        }
    }
}

struct AioAnswerBrand: Decodable, Hashable {
    let rank: Double?
    let name: String
    let own: Bool?
    let competitor: Bool?
}

struct AioClaim: Decodable, Hashable {
    let claim: String?
    let verdict: String?
    let fix: String?
}

struct AioHistoryPoint: Decodable, Hashable {
    let date: String?
    let mentioned: Bool?
    let position: Double?
    let error: Bool?
}
