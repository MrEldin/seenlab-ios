//
//  AioOverview.swift
//  seenlab
//
//  GET /admin/aio/overview — everything the AI answers page shows: the assistants, the prompts with their
//  latest result per assistant, rivals, cited sources, outreach targets, accuracy, changes and experiments.
//  Every field is optional: the API leaves parts out until the first run has happened.
//

import Foundation

struct AioOverview: Decodable {
    let engines: [AioEngine]?
    let names: [String]?
    let aliases: [String]?
    let websiteUrl: String?
    let limit: Int?
    let samples: Int?
    let facts: String?
    let positioning: String?
    let perception: [AioPerception]?
    let pageIdeas: [AioPageIdea]?
    let kpis: AioKpis?
    let series: AioSeries?
    let brands: [AioBrand]?
    let sources: [AioSource]?
    let prompts: [AioPromptRow]?
    let outreach: [AioOutreach]?
    let changes: [AioChange]?
    let accuracy: AioAccuracy?
    let experiments: [AioExperiment]?
    let job: Job<JSONValue>?

    var enabledEngines: [AioEngine] { (engines ?? []).filter { $0.enabled == true } }

    /// "ChatGPT" for "chatgpt".
    func label(_ key: String) -> String { engines?.first { $0.key == key }?.label ?? key }

    /// The name the web puts in the headline: the short name, else the first one.
    var appName: String? { (names?.count ?? 0) > 1 ? names?[1] : names?.first }
}

/// One AI assistant and whether it is connected.
struct AioEngine: Decodable, Identifiable, Hashable {
    let key: String
    let label: String?
    let model: String?
    let web: Bool?
    let enabled: Bool?
    let keyName: String?

    var id: String { key }
    var name: String { label ?? key }
}

struct AioKpis: Decodable {
    let prompts: Int?
    let answers: Int?
    let mentioned: Int?
    let mentionRate: Double?
    let avgPosition: Double?
    let shareOfVoice: Double?
    let topRival: AioBrand?
    let sentiment: AioMap<Double>?
    let errors: Int?
    let lastCaptured: String?
}

/// Mention rate per day: `labels` are dates, `engines` has one list per assistant plus "all".
struct AioSeries: Decodable {
    let labels: [String]?
    let engines: AioMap<[Double?]>?
}

/// A product named in the answers (the app itself is `own`).
struct AioBrand: Decodable, Hashable {
    let name: String
    let own: Bool?
    let competitor: Bool?
    let mentions: Double?
    let share: Double?
    let avgRank: Double?
}

/// A site the assistants cite.
struct AioSource: Decodable, Hashable {
    let domain: String
    let citations: Int?
    let prompts: Int?
    let engines: [String]?
    let own: Bool?
}

/// A tracked question with the latest result per assistant and 14 days of mention rate.
struct AioPromptRow: Decodable, Identifiable, Hashable {
    let id: Int
    let text: String?
    let isActive: Bool?
    let source: String?
    let createdAt: String?
    let results: AioMap<AioPromptResult>?
    let history: [Double?]?
}

struct AioPromptResult: Decodable, Hashable {
    let mentioned: Bool?
    let rate: Double?
    let samples: Int?
    let position: Double?
    let sentiment: String?
    let error: JSONValue?
    let capturedOn: String?
    let rivals: [String]?

    /// The API sends `false`/`true` here, older rows a message.
    var failed: Bool {
        switch error {
        case .bool(let b): return b
        case .string(let s): return !s.isEmpty
        default: return false
        }
    }
}

/// A page cited in answers that recommend others — where the product should be.
struct AioOutreach: Decodable, Hashable {
    let domain: String
    let urls: [String]?
    let prompts: Int?
    let engines: [String]?
    let rivals: [String]?
    let citations: Int?
}

/// What changed since the previous measurement (lost / gained / up / down).
struct AioChange: Decodable, Hashable {
    let promptId: Int?
    let prompt: String?
    let engine: String?
    let date: String?
    let since: String?
    let type: String?
    let from: JSONValue?
    let to: JSONValue?
}

struct AioAccuracy: Decodable {
    let counts: Counts?
    let items: [AioClaimItem]?

    struct Counts: Decodable { let correct: Int?; let wrong: Int?; let unclear: Int? }
}

/// A claim about the product found in the answers, checked against the facts.
struct AioClaimItem: Decodable, Hashable {
    let claim: String?
    let verdict: String?
    let fix: String?
    let engines: [String]?
    let prompt: String?
}

/// A logged change and the mention rate before and after it.
struct AioExperiment: Decodable, Identifiable, Hashable {
    let id: Int
    let note: String?
    let startedOn: String?
    let before: JSONValue?
    let after: JSONValue?
    let afterDays: Int?
    let ready: Bool?
}

/// The one sentence an assistant uses for the product.
struct AioPerception: Decodable, Hashable {
    let engine: String
    let summary: String?
    let sentiment: String?
}

/// A page worth writing (vs a rival, alternatives, best-of).
struct AioPageIdea: Decodable, Hashable {
    let kind: String?
    let target: String?
    let title: String?
}

/// A JSON object keyed by engine (or sentiment). PHP sends an empty one as `[]`, so that decodes as empty.
struct AioMap<Value: Decodable>: Decodable {
    let values: [String: Value]

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let dict = try? c.decode([String: Value].self) { values = dict }
        else if (try? c.decode([JSONValue].self)) != nil || c.decodeNil() { values = [:] }
        else { values = try c.decode([String: Value].self) }
    }

    subscript(key: String) -> Value? { values[key] }
}

extension AioMap: Equatable where Value: Equatable {}
extension AioMap: Hashable where Value: Hashable {}
