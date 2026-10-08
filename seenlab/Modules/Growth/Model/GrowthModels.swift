//
//  GrowthModels.swift
//  seenlab
//
//  The growth map as the API sends it (GET admin/growth/plan): the AI's map, the founder's board on top of it,
//  the marks, what Seenlab measured, the inbox, rivals' channels, the people on the board.
//  Decoded with a plain JSONDecoder (no snake-case strategy): card ids are dictionary keys ("c_x1y2", "x_product_hunt")
//  and must stay as they are, so the snake_case fields are named in CodingKeys.
//

import Foundation

/// A number the API may send as an integer or a decimal.
typealias Num = Double

struct GrowthData: Decodable {
    var plan: GrowthPlan?
    var state: GrowthState
    var current: Int?
    var maps: [GrowthMapRow]
    var directory: [DirChannel]
    var evidence: [String: Evidence]
    var results: [String: StepResult]
    var experiments: [String: Experiment]
    var inbox: [InboxItem]
    var rivals: [Rival]
    var team: Team?
    var quickRuns: QuickRuns?
    var generatedAt: String?
    var defaultBudget: Int?
    var job: GrowthJob?

    enum CodingKeys: String, CodingKey { case plan, state, current, maps, directory, evidence, results, experiments, inbox, rivals, team, job
        case quickRuns = "quick_runs", generatedAt = "generated_at", defaultBudget = "default_budget" }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        plan = try? c.decodeIfPresent(GrowthPlan.self, forKey: .plan)
        state = (try? c.decode(GrowthState.self, forKey: .state)) ?? GrowthState()
        current = try? c.decodeIfPresent(Int.self, forKey: .current)
        maps = (try? c.decode([GrowthMapRow].self, forKey: .maps)) ?? []
        directory = (try? c.decode([DirChannel].self, forKey: .directory)) ?? []
        evidence = (try? c.decode([String: Evidence].self, forKey: .evidence)) ?? [:]
        results = (try? c.decode([String: StepResult].self, forKey: .results)) ?? [:]
        experiments = (try? c.decode([String: Experiment].self, forKey: .experiments)) ?? [:]
        inbox = (try? c.decode([InboxItem].self, forKey: .inbox)) ?? []
        rivals = (try? c.decode([Rival].self, forKey: .rivals)) ?? []
        team = try? c.decodeIfPresent(Team.self, forKey: .team)
        quickRuns = try? c.decodeIfPresent(QuickRuns.self, forKey: .quickRuns)
        generatedAt = try? c.decodeIfPresent(String.self, forKey: .generatedAt)
        defaultBudget = try? c.decodeIfPresent(Int.self, forKey: .defaultBudget)
        job = try? c.decodeIfPresent(GrowthJob.self, forKey: .job)
    }
}

struct QuickRuns: Decodable { var used: Int?; var limit: Int? }

struct GrowthPlan: Decodable {
    var stage: String?
    var summary: String?
    var budget: Num?
    var phases: [Phase]
    var conditions: [Condition]
    var suggestions: [Suggestion]

    enum CodingKeys: String, CodingKey { case stage, summary, budget, phases, conditions, suggestions }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        stage = try? c.decodeIfPresent(String.self, forKey: .stage)
        summary = try? c.decodeIfPresent(String.self, forKey: .summary)
        budget = try? c.decodeIfPresent(Num.self, forKey: .budget)
        phases = (try? c.decode([Phase].self, forKey: .phases)) ?? []
        conditions = (try? c.decode([Condition].self, forKey: .conditions)) ?? []
        suggestions = (try? c.decode([Suggestion].self, forKey: .suggestions)) ?? []
    }
    init(stage: String?, summary: String?, budget: Num?, phases: [Phase], conditions: [Condition], suggestions: [Suggestion]) {
        self.stage = stage; self.summary = summary; self.budget = budget; self.phases = phases; self.conditions = conditions; self.suggestions = suggestions
    }
}

struct Phase: Decodable { var id: String; var kind: String; var title: String?; var note: String?; var nodes: [PlanNode] }

struct CopyText: Codable, Hashable { var kind: String?; var label: String?; var text: String }

struct PlanNode: Decodable {
    var id: String
    var channel: String?
    var channelName: String?
    var kind: String?
    var url: String?
    var title: String?
    var what: String?
    var why: String?
    var steps: [String]?
    var copy: [CopyText]?
    var cost: Num?
    var effortHours: Num?
    var expect: String?
    var week: Num?
    var custom: Bool?
    enum CodingKeys: String, CodingKey { case id, channel, kind, url, title, what, why, steps, copy, cost, expect, week, custom
        case channelName = "channel_name", effortHours = "effort_hours" }
}

struct Condition: Decodable { var id: String; var after: String?; var question: String?; var signal: String?; var yes: String?; var no: String?; var note: String? }
struct Suggestion: Decodable { var channel: String; var phase: String?; var why: String?; var cost: Num? }

struct DirChannel: Decodable, Identifiable {
    var id: String
    var name: String
    var kind: String
    var url: String?
    var cost: [Num]
    var effortHours: Num?
    var how: String?
    var expect: String?
    enum CodingKeys: String, CodingKey { case id, name, kind, url, cost, how, expect; case effortHours = "effort_hours" }
}

struct GrowthMapRow: Decodable, Identifiable {
    var id: Int
    var revised: Bool?
    var at: String?
    var budget: Num?
    var summary: String?
    var steps: Int?
    var done: Int?
}

struct Evidence: Decodable { var key: String; var n: Num?; var host: String?; var at: String? }

struct Mark: Codable {
    var status: String?
    var visitors: Num?
    var signups: Num?
    var spent: Num?
    var note: String?
    var at: String?
    var startedAt: String?
    var auto: Bool?
    enum CodingKeys: String, CodingKey { case status, visitors, signups, spent, note, at, auto; case startedAt = "started_at" }
}

struct ResultWindow: Decodable { var days: Int?; var elapsed: Int?; var complete: Bool?; var clicks: [Num?]?; var ratings: [Num?]?; var ai: [Num?]? }
struct StepResult: Decodable { var at: String?; var d7: ResultWindow?; var d30: ResultWindow? }
struct Experiment: Decodable { var metric: String; var target: Num?; var days: Int?; var start: String?; var elapsed: Int?; var value: Num?; var verdict: String }

struct InboxItem: Decodable, Identifiable {
    struct Drop: Decodable { var term: String?; var was: Int?; var now: Int? }
    var id: String
    var source: String
    var kind: String
    var title: String?
    var why: String?
    var steps: [String]?
    var draft: String?
    var column: String?
    var effortHours: Num?
    var at: String?
    var data: Drop?
    enum CodingKeys: String, CodingKey { case id, source, kind, title, why, steps, draft, column, at, data; case effortHours = "effort_hours" }
}

struct Rival: Decodable { var channel: String; var rivals: [String]; var host: String?; var answers: Int? }

struct Person: Decodable, Identifiable { var id: Int; var name: String; var initials: String; var color: String; var role: String? }
struct Team: Decodable { var people: [Person]; var me: Int?; var role: String?; var limit: Int? }

struct Comment: Decodable, Identifiable { var id: String; var card: String; var user: Int?; var name: String?; var initials: String?; var color: String?; var text: String; var at: String? }

struct GrowthJob: Decodable {
    struct Result: Decodable { var mode: String?; var source: String?; var out: JSONValue? }
    var id: Int
    var type: String?
    var status: String
    var error: String?
    var result: Result?
}

struct SharedBoard: Decodable, Identifiable { var appId: Int; var name: String; var iconUrl: String?; var owner: String?
    var id: Int { appId }
    enum CodingKeys: String, CodingKey { case name, owner; case appId = "app_id", iconUrl = "icon_url" } }

// MARK: - The founder's board (saved as it is sent back)

struct CardOverride: Codable {
    var channel: String?
    var title: String?
    var what: String?
    var why: String?
    var cost: Num?
    var effortHours: Num?
    var week: Num?
    var steps: [String]?
    var copy: [CopyText]?
    var owner: Int?
    var test: TestSpec?
    var from: String?
    enum CodingKeys: String, CodingKey { case channel, title, what, why, cost, week, steps, copy, owner, test, from; case effortHours = "effort_hours" }
}

struct TestSpec: Codable, Equatable { var metric: String; var target: Num; var days: Int }

struct StickyMeta: Codable { var title: String?; var description: String?; var image: String?; var site: String? }

struct Sticky: Codable, Identifiable {
    var id: String
    var type: String
    var text: String
    var url: String
    var x: Double
    var y: Double
    var meta: StickyMeta?
    var w: Double?
    var h: Double?
}

struct BoardLink: Codable, Identifiable { var id: String; var from: String; var to: String }
struct BoardFrame: Codable, Identifiable { var id: String; var title: String; var cards: [String]; var color: String? }

struct BoardState: Codable {
    var order: [String: [String]] = ["fix": [], "free": [], "paid": [], "scale": []]
    var cards: [String: CardOverride] = [:]
    var dismissed: [String] = []
    var stickies: [Sticky] = []
    var links: [BoardLink] = []
    var frames: [BoardFrame] = []
    var inboxDone: [String] = []
    enum CodingKeys: String, CodingKey { case order, cards, dismissed, stickies, links, frames; case inboxDone = "inbox_done" }

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        order = (try? c.decode([String: [String]].self, forKey: .order)) ?? order
        cards = (try? c.decode([String: CardOverride].self, forKey: .cards)) ?? [:]
        dismissed = (try? c.decode([String].self, forKey: .dismissed)) ?? []
        stickies = (try? c.decode([Sticky].self, forKey: .stickies)) ?? []
        links = (try? c.decode([BoardLink].self, forKey: .links)) ?? []
        frames = (try? c.decode([BoardFrame].self, forKey: .frames)) ?? []
        inboxDone = (try? c.decode([String].self, forKey: .inboxDone)) ?? []
        for k in ["fix", "free", "paid", "scale"] where order[k] == nil { order[k] = [] }
    }

    /// As JSON for the API (the body of PUT layout).
    var json: [String: Any] {
        guard let data = try? JSONEncoder().encode(self), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return obj
    }
}

struct GrowthState: Decodable {
    var steps: [String: Mark] = [:]
    var board: BoardState?
    var rev: Int = 0
    var comments: [Comment] = []
    var budget: Int?
    enum CodingKeys: String, CodingKey { case steps, board, rev, comments, budget }
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        steps = (try? c.decode([String: Mark].self, forKey: .steps)) ?? [:]
        board = try? c.decodeIfPresent(BoardState.self, forKey: .board)
        rev = (try? c.decode(Int.self, forKey: .rev)) ?? 0
        comments = (try? c.decode([Comment].self, forKey: .comments)) ?? []
        budget = try? c.decodeIfPresent(Int.self, forKey: .budget)
    }
}

/// A card as the board shows it: the AI's node or the founder's own, with the overrides applied.
struct BoardCard: Identifiable, Equatable {
    var id: String
    var channel: String?
    var channelName: String
    var kind: String
    var url: String?
    var title: String
    var what: String
    var why: String
    var steps: [String]
    var copy: [CopyText]
    var cost: Double
    var effortHours: Double
    var expect: String
    var week: Int
    var source: String       // ai | added | custom
    var owner: Int?
    var test: TestSpec?
    static func == (a: BoardCard, b: BoardCard) -> Bool { a.id == b.id && a.title == b.title && a.week == b.week && a.cost == b.cost && a.owner == b.owner && a.test == b.test }
}
