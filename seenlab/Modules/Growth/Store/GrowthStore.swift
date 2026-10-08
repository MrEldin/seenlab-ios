//
//  GrowthStore.swift
//  seenlab
//
//  The growth board of the project in view (or a board shared with me): loads the map and the founder's board,
//  keeps an undo history, saves each edit a moment later with the board's version (a save on top of an older
//  board is merged with the newer one and saved again), marks steps, comments, and runs the AI on the board.
//  The same API as the web (admin/growth/*).
//

import Foundation
import Combine

@MainActor
final class GrowthStore: ObservableObject {
    @Published private(set) var data: GrowthData?
    @Published private(set) var board: BoardState?
    @Published private(set) var loading = false
    @Published var error: String?
    @Published var notice: String?
    @Published private(set) var job: GrowthJob?
    @Published private(set) var busy: Set<String> = []        // stickies / "coach" the AI is working on
    @Published private(set) var shared: [SharedBoard] = []
    @Published var sharedId: Int?                              // nil = my project's board
    @Published var budget: Int = 1000
    @Published private(set) var canUndo = false

    private var undo: [BoardState?] = []
    private var rev = 0
    private var synced: BoardState?
    private var saveTask: Task<Void, Never>?
    private var saving = false
    private var projectId: Int?
    private let decoder = JSONDecoder()

    var engine: BoardEngine { BoardEngine(plan: data?.plan, directory: data?.directory ?? [], rivals: data?.rivals ?? []) }
    var columns: [BoardColumn] { engine.columns(board) }
    var cards: [BoardCard] { columns.flatMap(\.cards) }
    var stickies: [Sticky] { engine.effective(board).stickies }
    var links: [BoardLink] { engine.effective(board).links }
    var frames: [BoardFrame] { engine.effective(board).frames }
    var inbox: [InboxItem] { let done = Set(engine.effective(board).inboxDone); return (data?.inbox ?? []).filter { !done.contains($0.id) } }
    var running: Bool { ["pending", "running"].contains(job?.status ?? "") }
    var hasPlan: Bool { data?.plan != nil }

    /// Marks as shown: the founder's own, plus the steps Seenlab can see are done that nobody marked.
    var marks: [String: Mark] {
        var m = data?.state.steps ?? [:]
        for c in cards { if let ch = c.channel, data?.evidence[ch] != nil, m[c.id]?.status == nil { m[c.id] = Mark(status: "done", auto: true) } }
        return m
    }

    private var boardId: Int? { sharedId }
    private func route(_ path: String, _ method: HTTPMethod = .GET, query: [String: String] = [:], body: [String: Any]? = nil) -> APIRoute {
        SeenlabAPI.growth(path, method: method, board: boardId, query: query, body: body)
    }
    private func call<T: Decodable>(_ r: APIRoute, as: T.Type) async throws -> T? {
        let raw = try await NetworkManager.shared.data(r)
        return try decoder.decode(Envelope<T>.self, from: raw).data
    }

    // MARK: loading

    /// The sample board (Free): shown, never saved.
    func setSample(_ d: GrowthData) { data = d; board = nil; budget = 1000 }

    func load(project: Int?, map: Int? = nil, quiet: Bool = false) async {
        if sharedId == nil, project != projectId { projectId = project; data = nil; board = nil; undo = []; canUndo = false }
        if !quiet { loading = true; error = nil }
        defer { loading = false }
        do {
            guard let d = try await call(route("plan", query: map.map { ["map": String($0)] } ?? [:]), as: GrowthData.self) else { return }
            data = d
            board = d.state.board
            synced = d.state.board
            rev = d.state.rev
            budget = d.state.budget ?? d.defaultBudget ?? 1000
            if !quiet { undo = []; canUndo = false }
            if let j = d.job, ["pending", "running"].contains(j.status) { job = j; follow(j.id) { [weak self] in await self?.load(project: project) } }
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? t("ios.loadFailed")
        }
        if shared.isEmpty { shared = (try? await NetworkManager.shared.request(SeenlabAPI.growthShared, as: [SharedBoard].self)) ?? [] }
    }

    // MARK: editing

    /// Applies an edit: remembered for undo, shown at once, saved a moment later.
    func apply(_ next: BoardState) {
        undo.append(board)
        if undo.count > 60 { undo.removeFirst() }
        canUndo = true
        board = next
        scheduleSave()
    }
    func undoLast() {
        guard let last = undo.popLast() else { return }
        board = last
        canUndo = !undo.isEmpty
        scheduleSave()
    }

    private func scheduleSave() {
        saving = true
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await self?.save()
            self?.saving = false
        }
    }

    private func save(tries: Int = 0) async {
        let b = board
        var body: [String: Any] = ["rev": rev]
        body["board"] = b.map { $0.json } ?? NSNull()
        if let map = data?.current { body["map"] = map }
        do {
            let raw = try await NetworkManager.shared.data(route("layout", .PUT, body: body))
            if let s = try? decoder.decode(Envelope<GrowthState>.self, from: raw).data { rev = s.rev }
            synced = b
        } catch APIError.server(409, _) where tries < 3 {
            // somebody saved first: keep their changes and mine, and save the two together
            guard let fresh = try? await call(route("plan", query: data?.current.map { ["map": String($0)] } ?? [:]), as: GrowthData.self) else { return }
            let merged = BoardEngine.merge(base: synced, local: engine.effective(board), remote: fresh.state.board)
            rev = fresh.state.rev
            synced = fresh.state.board
            board = merged
            notice = t("growth.team.merged")
            await save(tries: tries + 1)
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? t("ios.loadFailed")
        }
    }

    // MARK: marks, comments

    func saveStep(_ id: String, status: String, visitors: Int?, signups: Int?, spent: Int?, note: String?) async throws {
        var body: [String: Any] = ["status": status]
        if let map = data?.current { body["map"] = map }
        body["visitors"] = visitors ?? NSNull(); body["signups"] = signups ?? NSNull(); body["spent"] = spent ?? NSNull(); body["note"] = note ?? NSNull()
        let raw = try await NetworkManager.shared.data(route("steps/" + id, .PUT, body: body))
        if let s = try? decoder.decode(Envelope<GrowthState>.self, from: raw).data { data?.state.steps = s.steps }
    }

    func comments(for card: String) -> [Comment] { (data?.state.comments ?? []).filter { $0.card == card } }
    func comment(_ card: String, _ text: String) async throws {
        var body: [String: Any] = ["card": card, "text": text]
        if let map = data?.current { body["map"] = map }
        struct R: Decodable { var comments: [Comment] }
        if let r = try await call(route("comments", .POST, body: body), as: R.self) { data?.state.comments = r.comments }
    }

    // MARK: the AI

    private func follow(_ id: Int, done: @escaping () async -> Void) {
        Task {
            for _ in 0..<120 {
                try? await Task.sleep(for: .seconds(3))
                guard let j = try? await call(route("jobs/\(id)"), as: GrowthJob.self) else { continue }
                job = j
                if j.status == "done" { await done(); return }
                if j.status == "failed" { return }
            }
        }
    }

    private func waitJob(_ id: Int) async throws -> GrowthJob {
        for i in 0..<90 {
            try await Task.sleep(for: .milliseconds(i < 4 ? 1200 : 2000))
            if let j = try await call(route("jobs/\(id)"), as: GrowthJob.self) {
                if j.status == "done" { return j }
                if j.status == "failed" { throw APIError.server(500, j.error ?? t("growth.ai.failed")) }
            }
        }
        throw APIError.server(500, t("growth.ai.failed"))
    }

    private func cardContext() -> [[String: Any]] {
        let cols = columns
        return cols.flatMap { col in col.cards.map { c in
            var o: [String: Any] = ["id": c.id, "title": c.title, "what": c.what, "column": col.kind, "status": marks[c.id]?.status ?? "todo", "cost": c.cost, "effort_hours": c.effortHours, "week": c.week]
            if let ch = c.channel { o["channel"] = ch }
            if let tst = c.test { o["test"] = ["metric": tst.metric, "target": tst.target, "days": tst.days] }
            return o
        } }
    }

    /// Draw a new map for the budget (the old ones stay in the history).
    func make() async {
        do {
            await setBudget(budget)
            guard let j = try await call(route("plan", .POST, body: ["budget": budget, "lang": L10n.shared.locale]), as: GrowthJob.self) else { return }
            job = j
            follow(j.id) { [weak self] in await self?.load(project: self?.projectId) }
        } catch { self.error = (error as? APIError)?.errorDescription }
    }

    /// Bring the map up to date, keeping what is done and the founder's own steps.
    func revise() async {
        guard let map = data?.current else { return }
        let cols = columns.map { col -> [String: Any] in ["kind": col.kind, "cards": col.cards.map { c -> [String: Any] in
            ["id": c.id, "channel": c.channel ?? NSNull(), "title": c.title, "what": c.what, "why": c.why, "steps": c.steps, "cost": c.cost, "effort_hours": c.effortHours, "expect": c.expect, "week": c.week, "source": c.source] }] }
        let notes = stickies.filter { !$0.text.isEmpty }.map { ["type": $0.type, "text": $0.text] }
        do {
            guard let j = try await call(route("revise", .POST, body: ["map": map, "board": cols, "budget": budget, "notes": notes, "lang": L10n.shared.locale]), as: GrowthJob.self) else { return }
            job = j
            follow(j.id) { [weak self] in await self?.load(project: self?.projectId) }
        } catch { self.error = (error as? APIError)?.errorDescription }
    }

    func setBudget(_ b: Int) async {
        budget = b
        _ = try? await NetworkManager.shared.data(route("layout", .PUT, body: ["budget": b]))
    }

    /// A note becomes a step; a risk gets what lowers it (pinned next to it).
    func assist(sticky: Sticky) async -> String? {
        busy.insert(sticky.id); defer { busy.remove(sticky.id) }
        let mode = sticky.type == "risk" ? "risk" : "step"
        do {
            guard let start = try await call(route("assist", .POST, body: ["mode": mode, "text": sticky.text, "source": sticky.id, "cards": cardContext(), "budget": budget, "lang": L10n.shared.locale]), as: GrowthJob.self) else { return nil }
            let j = try await waitJob(start.id)
            guard let out = j.result?.out else { return nil }
            if mode == "step" {
                let (b, id) = engine.stepFromAi(board, out: out, sticky: sticky.id)
                apply(b)
                return id
            }
            var (b, aid) = engine.addSticky(board, type: "answer", x: sticky.x + 260, y: sticky.y, text: out["answer"]?.string ?? "")
            b = engine.addLink(b, from: sticky.id, to: aid)
            for h in out["helps"]?.array.compactMap(\.string) ?? [] { b = engine.addLink(b, from: aid, to: h) }
            apply(b)
        } catch { notice = (error as? APIError)?.errorDescription ?? t("growth.ai.failed") }
        return nil
    }

    /// The coach: 3–5 notes pinned on the board's weak spots, each next to the cards it is about.
    func coach(spot: (([String]) -> (Double, Double))) async {
        busy.insert("coach"); defer { busy.remove("coach") }
        do {
            let notes = stickies.filter { !$0.text.isEmpty }.map { ["type": $0.type, "text": $0.text] }
            guard let start = try await call(route("assist", .POST, body: ["mode": "coach", "text": "review", "cards": cardContext(), "notes": notes, "budget": budget, "lang": L10n.shared.locale]), as: GrowthJob.self) else { return }
            let j = try await waitJob(start.id)
            let list = j.result?.out?["notes"]?.array ?? []
            var b = board
            for n in list {
                let about = n["about"]?.array.compactMap(\.string) ?? []
                let (x, y) = spot(about)
                var (nb, id) = engine.addSticky(b, type: "coach", x: x, y: y, text: n["text"]?.string ?? "")
                for c in about { nb = engine.addLink(nb, from: id, to: c) }
                b = nb
            }
            if let b { apply(b) }
            notice = list.isEmpty ? t("growth.coach.none") : t("growth.coach.done", ["n": list.count])
        } catch { notice = (error as? APIError)?.errorDescription ?? t("growth.ai.failed") }
    }

    // MARK: maps and boards

    func openMap(_ id: Int) async {
        _ = try? await NetworkManager.shared.data(route("layout", .PUT, body: ["current": id]))
        await load(project: projectId, map: id)
    }
    func openShared(_ id: Int?) async {
        sharedId = id
        data = nil; board = nil; undo = []; canUndo = false
        await load(project: projectId)
    }

    /// Someone else may be on the board: catch up with their changes (not in the middle of mine).
    func refreshIfShared() async {
        guard (data?.team?.people.count ?? 0) > 1, !saving else { return }
        await load(project: projectId, map: data?.current, quiet: true)
    }
}
