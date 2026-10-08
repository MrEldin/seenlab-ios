//
//  GrowthBoardLogic.swift
//  seenlab
//
//  The growth board's rules, the same as the web's useBoard.js: four columns (fix → free → paid → scale) of
//  cards; the AI's map is the start, the founder's board replaces it once they move, add or remove anything.
//  A card id is the AI node's id, `x_<channel>` for a channel added by hand, `c_<random>` for the founder's own step.
//  Every edit returns a new BoardState; the store keeps an undo history and saves it.
//

import Foundation

enum GrowthCols {
    static let all = ["fix", "free", "paid", "scale"]
    static func phaseOf(_ kind: String?) -> String { ["fix": "fix", "newsletter": "paid", "creator": "paid", "ads": "paid"][kind ?? ""] ?? "free" }
}

struct BoardColumn: Identifiable {
    var id: String { kind }
    var kind: String
    var title: String
    var note: String
    var cards: [BoardCard]
    var suggestions: [BoardSuggestion]
}

struct BoardSuggestion: Identifiable {
    var id: String { channel }
    var channel: String
    var name: String
    var kind: String
    var why: String
    var cost: Double
    var rival: Rival?
}

func rid(_ prefix: String) -> String { prefix + String(UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(7)) }

struct BoardEngine {
    var plan: GrowthPlan?
    var directory: [DirChannel]
    var rivals: [Rival] = []

    private var dir: [String: DirChannel] { Dictionary(directory.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }) }
    private var nodes: [String: PlanNode] {
        var m: [String: PlanNode] = [:]
        for ph in plan?.phases ?? [] { for n in ph.nodes { m[n.id] = n } }
        return m
    }

    static func describe(_ c: DirChannel) -> String { L10n.shared.has("growth.dir.what." + c.id) ? t("growth.dir.what." + c.id) : (c.how ?? "") }

    /// The AI's arrangement, before the founder touched anything.
    var aiOrder: [String: [String]] {
        var o: [String: [String]] = ["fix": [], "free": [], "paid": [], "scale": []]
        for ph in plan?.phases ?? [] { for n in ph.nodes { o[GrowthCols.all.contains(ph.kind) ? ph.kind : "free", default: []].append(n.id) } }
        return o
    }

    func effective(_ board: BoardState?) -> BoardState {
        if let board { return board }
        var b = BoardState()
        b.order = aiOrder
        return b
    }

    func card(_ id: String, in b: BoardState) -> BoardCard? {
        let o = b.cards[id]
        if let n = nodes[id] {
            let d = n.channel.flatMap { dir[$0] }
            return BoardCard(id: id, channel: n.channel, channelName: n.channelName ?? d?.name ?? "", kind: n.kind ?? d?.kind ?? "custom", url: n.url ?? d?.url,
                             title: o?.title ?? n.title ?? "", what: (n.what?.isEmpty == false ? n.what : nil) ?? d.map(BoardEngine.describe) ?? "", why: n.why ?? "", steps: n.steps ?? [], copy: n.copy ?? [],
                             cost: n.cost ?? 0, effortHours: n.effortHours ?? 1, expect: n.expect ?? d?.expect ?? "", week: Int(o?.week ?? n.week ?? 0),
                             source: n.custom == true ? "custom" : "ai", owner: o?.owner, test: o?.test)
        }
        guard let c = o else { return nil }
        let d = c.channel.flatMap { dir[$0] }
        if c.channel != nil && d == nil { return nil }
        return BoardCard(id: id, channel: c.channel, channelName: d?.name ?? "", kind: d?.kind ?? "custom", url: d?.url, title: c.title ?? d?.name ?? "",
                         what: c.what ?? d.map(BoardEngine.describe) ?? "", why: c.why ?? "", steps: (c.steps?.isEmpty == false ? c.steps : d?.how.map { [$0] }) ?? [], copy: c.copy ?? [],
                         cost: c.cost ?? d?.cost.first ?? 0, effortHours: c.effortHours ?? d?.effortHours ?? 1, expect: d?.expect ?? "", week: Int(c.week ?? 0),
                         source: c.channel != nil ? "added" : "custom", owner: c.owner, test: c.test)
    }

    /// The columns as drawn: cards in order (weeks filled in), and the proposals not taken or dismissed.
    func columns(_ board: BoardState?) -> [BoardColumn] {
        let b = effective(board)
        var meta: [String: Phase] = [:]
        for ph in plan?.phases ?? [] where meta[ph.kind] == nil { meta[ph.kind] = ph }
        var onBoard = Set<String>()
        var week = 1
        var cols = GrowthCols.all.map { kind -> BoardColumn in
            var cards: [BoardCard] = []
            for id in b.order[kind] ?? [] {
                guard var c = card(id, in: b) else { continue }
                if let ch = c.channel { onBoard.insert(ch) }
                if c.week > 0 { week = max(week, c.week) } else { c.week = week }
                cards.append(c)
            }
            if !cards.isEmpty { week += 1 }
            return BoardColumn(kind: kind, title: meta[kind]?.title ?? "", note: meta[kind]?.note ?? "", cards: cards, suggestions: [])
        }
        let dismissed = Set(b.dismissed)
        for s in plan?.suggestions ?? [] {
            guard !onBoard.contains(s.channel), !dismissed.contains(s.channel), let d = dir[s.channel] else { continue }
            let i = cols.firstIndex { $0.kind == s.phase } ?? 1
            cols[i].suggestions.append(BoardSuggestion(channel: s.channel, name: d.name, kind: d.kind, why: s.why ?? "", cost: s.cost ?? d.cost.first ?? 0))
        }
        for r in rivals {
            guard !onBoard.contains(r.channel), !dismissed.contains(r.channel), let d = dir[r.channel] else { continue }
            if let ci = cols.firstIndex(where: { $0.suggestions.contains { $0.channel == r.channel } }), let si = cols[ci].suggestions.firstIndex(where: { $0.channel == r.channel }) {
                cols[ci].suggestions[si].rival = r
                continue
            }
            let i = cols.firstIndex { $0.kind == GrowthCols.phaseOf(d.kind) } ?? 1
            cols[i].suggestions.append(BoardSuggestion(channel: r.channel, name: d.name, kind: d.kind, why: "", cost: d.cost.first ?? 0, rival: r))
        }
        return cols
    }

    // MARK: edits (each returns the new board)

    private func strip(_ b: inout BoardState, _ id: String) { for k in GrowthCols.all { b.order[k] = (b.order[k] ?? []).filter { $0 != id } } }

    func move(_ b0: BoardState?, id: String, to kind: String, index: Int) -> BoardState {
        var b = effective(b0)
        let from = GrowthCols.all.first { (b.order[$0] ?? []).contains(id) }
        let at = from.flatMap { b.order[$0]?.firstIndex(of: id) } ?? -1
        strip(&b, id)
        var list = b.order[kind] ?? []
        let i = from == kind && at < index ? index - 1 : index
        list.insert(id, at: max(0, min(list.count, i)))
        b.order[kind] = list
        return b
    }

    /// A channel from the directory or a proposal, or the founder's own step.
    func add(_ b0: BoardState?, channel: String?, why: String? = nil, title: String = "", kind: String? = nil) -> (BoardState, String) {
        var b = effective(b0)
        let id = channel.map { "x_" + $0 } ?? rid("c_")
        b.cards[id] = channel != nil ? CardOverride(channel: channel, why: why) : CardOverride(title: title, what: "")
        let col = kind ?? (channel.map { GrowthCols.phaseOf(dir[$0]?.kind) } ?? "free")
        b.order[col, default: []].append(id)
        return (b, id)
    }

    func remove(_ b0: BoardState?, id: String) -> BoardState {
        var b = effective(b0)
        strip(&b, id)
        if nodes[id] == nil { b.cards[id] = nil }
        b.links.removeAll { $0.from == id || $0.to == id }
        b.frames = b.frames.map { var f = $0; f.cards.removeAll { $0 == id }; return f }.filter { !$0.cards.isEmpty }
        return b
    }

    func edit(_ b0: BoardState?, id: String, _ change: (inout CardOverride) -> Void) -> BoardState {
        var b = effective(b0)
        var o = b.cards[id] ?? CardOverride()
        change(&o)
        b.cards[id] = o
        return b
    }

    func dismiss(_ b0: BoardState?, channel: String) -> BoardState { var b = effective(b0); if !b.dismissed.contains(channel) { b.dismissed.append(channel) }; return b }

    func addSticky(_ b0: BoardState?, type: String, x: Double, y: Double, text: String = "") -> (BoardState, String) {
        var b = effective(b0)
        let id = rid("n_")
        b.stickies.append(Sticky(id: id, type: type, text: text, url: "", x: x.rounded(), y: y.rounded()))
        return (b, id)
    }
    func editSticky(_ b0: BoardState?, id: String, _ change: (inout Sticky) -> Void) -> BoardState {
        var b = effective(b0)
        if let i = b.stickies.firstIndex(where: { $0.id == id }) { change(&b.stickies[i]) }
        return b
    }
    func removeSticky(_ b0: BoardState?, id: String) -> BoardState {
        var b = effective(b0)
        b.stickies.removeAll { $0.id == id }
        b.links.removeAll { $0.from == id || $0.to == id }
        return b
    }
    func addLink(_ b0: BoardState?, from: String, to: String) -> BoardState {
        var b = effective(b0)
        guard from != to, !b.links.contains(where: { ($0.from == from && $0.to == to) || ($0.from == to && $0.to == from) }) else { return b }
        b.links.append(BoardLink(id: rid("l_"), from: from, to: to))
        return b
    }

    /// A finding from the inbox becomes the founder's own step with the morning's actions and draft.
    func takeInbox(_ b0: BoardState?, item: InboxItem, title: String) -> BoardState {
        var b = effective(b0)
        let id = rid("c_")
        b.cards[id] = CardOverride(title: title, what: item.why ?? "", cost: 0, effortHours: item.effortHours ?? 1, steps: item.steps ?? [],
                                   copy: item.draft.map { [CopyText(kind: "draft", label: "Draft", text: String($0.prefix(3000)))] }, from: item.id)
        let col = GrowthCols.all.contains(item.column ?? "") ? item.column! : "fix"
        b.order[col, default: []].append(id)
        if !b.inboxDone.contains(item.id) { b.inboxDone.append(item.id) }
        return b
    }
    func dismissInbox(_ b0: BoardState?, id: String) -> BoardState { var b = effective(b0); if !b.inboxDone.contains(id) { b.inboxDone.append(id) }; return b }

    /// A step the AI wrote from a note: a directory channel when one fits, else the founder's own; it takes the note's place.
    func stepFromAi(_ b0: BoardState?, out: JSONValue, sticky: String?) -> (BoardState, String) {
        var b = effective(b0)
        let channel = out["channel"]?.string
        let onBoard = Set(columns(b).flatMap { $0.cards.compactMap(\.channel) })
        let useChannel = channel != nil && !onBoard.contains(channel!) && dir[channel!] != nil
        let id = useChannel ? "x_" + channel! : rid("c_")
        let steps = out["steps"]?.array.compactMap(\.string) ?? []
        let copy = out["copy"]?.array.compactMap { c -> CopyText? in c["text"]?.string.map { CopyText(kind: c["kind"]?.string, label: c["label"]?.string, text: $0) } } ?? []
        b.cards[id] = useChannel
            ? CardOverride(channel: channel, why: out["why"]?.string, cost: out["cost"]?.double, steps: steps.isEmpty ? nil : steps, copy: copy.isEmpty ? nil : copy)
            : CardOverride(title: out["title"]?.string ?? "", what: out["what"]?.string ?? "", why: out["why"]?.string ?? "", cost: out["cost"]?.double ?? 0, effortHours: out["effort_hours"]?.double ?? 1, steps: steps, copy: copy)
        let col = GrowthCols.all.contains(out["column"]?.string ?? "") ? out["column"]!.string! : ((out["cost"]?.double ?? 0) > 0 ? "paid" : "free")
        strip(&b, id)
        b.order[col, default: []].append(id)
        if let sticky {
            b.links = b.links.map { var l = $0; if l.from == sticky { l.from = id }; if l.to == sticky { l.to = id }; return l }.filter { $0.from != $0.to }
            b.stickies.removeAll { $0.id == sticky }
        }
        return (b, id)
    }

    /// Two saves at once (mine built on `base`, theirs on the server now): keep both — whoever changed a thing wins.
    static func merge(base: BoardState?, local: BoardState, remote: BoardState?) -> BoardState {
        guard let remote else { return local }
        let base = base ?? BoardState()
        func enc<T: Encodable>(_ v: T?) -> Data? { v.flatMap { try? JSONEncoder().encode($0) } }
        func mergeMap<T: Encodable>(_ b: [String: T], _ l: [String: T], _ r: [String: T]) -> [String: T] {
            var out: [String: T] = [:]
            for id in Set(l.keys).union(r.keys) {
                let inB = b[id] != nil, inL = l[id] != nil, inR = r[id] != nil
                if inL && inR { out[id] = enc(l[id]) != enc(b[id]) ? l[id] : r[id] }
                else if inL { if !inB || enc(l[id]) != enc(b[id]) { out[id] = l[id] } }
                else if inR { if !inB || enc(r[id]) != enc(b[id]) { out[id] = r[id] } }
            }
            return out
        }
        func list<T: Encodable & Identifiable>(_ b: [T], _ l: [T], _ r: [T]) -> [T] where T.ID == String {
            let m = mergeMap(Dictionary(b.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }), Dictionary(l.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }), Dictionary(r.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }))
            var seen = Set<String>()
            return (l + r).filter { m[$0.id] != nil && seen.insert($0.id).inserted }.compactMap { m[$0.id] }
        }
        var out = BoardState()
        out.cards = mergeMap(base.cards, local.cards, remote.cards)
        let baseIds = Set(base.order.values.flatMap { $0 }), localIds = Set(local.order.values.flatMap { $0 }), remoteIds = Set(remote.order.values.flatMap { $0 })
        let iMoved = enc(local.order) != enc(base.order)
        let start = iMoved ? local.order : remote.order
        for k in GrowthCols.all { out.order[k] = (start[k] ?? []).filter { !(baseIds.contains($0) && (!localIds.contains($0) || !remoteIds.contains($0))) } }
        for k in GrowthCols.all { for id in (iMoved ? remote.order : local.order)[k] ?? [] where !baseIds.contains(id) && !out.order.values.flatMap({ $0 }).contains(id) { out.order[k, default: []].append(id) } }
        out.dismissed = Array(Set(local.dismissed + remote.dismissed))
        out.inboxDone = Array(Set(local.inboxDone + remote.inboxDone))
        out.stickies = list(base.stickies, local.stickies, remote.stickies)
        out.links = list(base.links, local.links, remote.links)
        out.frames = list(base.frames, local.frames, remote.frames)
        return out
    }
}
