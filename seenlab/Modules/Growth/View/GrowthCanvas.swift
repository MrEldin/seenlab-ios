//
//  GrowthCanvas.swift
//  seenlab
//
//  The growth board on the phone: the same board as the web, drawn at the same coordinates. One finger pans,
//  two fingers zoom, a tap opens a card or a note, holding a card or a note picks it up to move it (to another
//  column or position; in the weeks lens to another week). Lenses: map, status (late cards fade), results
//  (coloured by what each step brought), weeks.
//

import SwiftUI

enum GrowthLens: String, CaseIterable { case map, status, result, time
    var icon: String { switch self { case .map: "map"; case .status: "checklist"; case .result: "chart.line.uptrend.xyaxis"; case .time: "calendar" } }
}

/// Board geometry (board points), the same numbers as GrowthBoard.vue.
enum BG {
    static let cardW: CGFloat = 300, cardH: CGFloat = 172, sugH: CGFloat = 156, gapY: CGFloat = 28, gapX: CGFloat = 250, pad: CGFloat = 48, framePad: CGFloat = 24, head: CGFloat = 130
    static let colStep = cardW + framePad * 2 + gapX
    static let top = pad + head + framePad
    static let weekW = cardW + 64
    static let noteW: CGFloat = 220, noteH: CGFloat = 132
    static let inboxW = cardW + framePad * 2 + 150, inboxH: CGFloat = 196
    static let prosH: CGFloat = 184
    static func colX(_ i: Int) -> CGFloat { pad + framePad + CGFloat(i) * colStep }
}

struct PlacedCard: Identifiable { var id: String { card.id }; var card: BoardCard; var kind: String; var x: CGFloat; var y: CGFloat }
struct PlacedSug: Identifiable { var id: String { sug.channel }; var sug: BoardSuggestion; var kind: String; var x: CGFloat; var y: CGFloat }

struct GrowthCanvas: View {
    @ObservedObject var store: GrowthStore
    var lens: GrowthLens
    var readonly: Bool
    var marks: [String: Mark]
    var started: Date?
    var onCard: (String) -> Void
    var onSticky: (String) -> Void
    var onSuggestion: (BoardSuggestion, String) -> Void
    var onInbox: (InboxItem) -> Void
    var onProspect: (Int) -> Void = { _ in }

    @State private var offset: CGSize = .zero
    @State private var panBase: CGSize = .zero
    @State private var scale: CGFloat = 0.5
    @State private var scaleBase: CGFloat = 0.5
    @State private var pinching = false
    @State private var fitted = false
    @State private var held: Held?

    struct Held: Equatable { var id: String; var sticky: Bool; var at: CGPoint; var grab: CGSize }

    // MARK: layout

    private var columns: [BoardColumn] { store.columns }
    private var timed: Bool { lens == .time }

    private var placed: (cards: [PlacedCard], sugs: [PlacedSug], bottom: CGFloat, weeks: [(Int, CGFloat)]) {
        var cards: [PlacedCard] = [], sugs: [PlacedSug] = []
        var bottom = BG.top + BG.cardH
        if timed {
            let all = columns.flatMap { col in col.cards.map { ($0, col.kind) } }
            let weeks = Array(Set(all.map { max(1, $0.0.week) })).sorted()
            let span = weeks.isEmpty ? [1] : Array(weeks.first!...weeks.last!)
            var heads: [(Int, CGFloat)] = []
            for (i, w) in span.enumerated() {
                let x = BG.pad + BG.framePad + CGFloat(i) * BG.weekW
                heads.append((w, x))
                for (j, (c, k)) in all.filter({ max(1, $0.0.week) == w }).enumerated() {
                    let y = BG.top + CGFloat(j) * (BG.cardH + BG.gapY)
                    cards.append(PlacedCard(card: c, kind: k, x: x, y: y)); bottom = max(bottom, y + BG.cardH)
                }
            }
            return (cards, [], bottom, heads)
        }
        for (i, col) in columns.enumerated() {
            var y = BG.top
            for c in col.cards { cards.append(PlacedCard(card: c, kind: col.kind, x: BG.colX(i), y: y)); y += BG.cardH + BG.gapY }
            if col.cards.isEmpty { y += BG.cardH + BG.gapY }
            for s in col.suggestions where !readonly && lens != .status { sugs.append(PlacedSug(sug: s, kind: col.kind, x: BG.colX(i), y: y)); y += BG.sugH + BG.gapY }
            bottom = max(bottom, y - BG.gapY)
        }
        return (cards, sugs, bottom, [])
    }

    private var showInbox: Bool { !timed && lens != .status && !readonly && !store.inbox.isEmpty }
    private var inboxX: CGFloat { BG.pad + BG.framePad - BG.inboxW }
    private var minX: CGFloat { showInbox ? inboxX - BG.framePad - 8 : 0 }
    // the pages worth being on, a lane after the last column (map lens only)
    private var showLists: Bool { lens == .map && !readonly && !store.prospects.isEmpty }
    private var listsX: CGFloat { BG.colX(max(4, columns.count)) }
    private var listsBottom: CGFloat { BG.top + CGFloat(store.prospects.count) * (BG.prosH + BG.gapY) - BG.gapY }
    private func boardSize(_ bottom: CGFloat, weeks: Int) -> CGSize {
        let w = timed ? BG.pad * 2 + BG.framePad * 2 + CGFloat(weeks) * BG.weekW : BG.pad * 2 + BG.colStep * CGFloat(showLists ? max(4, columns.count) + 1 : 4) - BG.gapX
        var s = CGSize(width: w - minX, height: max(bottom, showInbox ? BG.top + CGFloat(store.inbox.count) * (BG.inboxH + BG.gapY) : 0, showLists ? listsBottom : 0) + BG.framePad + BG.pad)
        for n in store.stickies { s.width = max(s.width, n.x + BG.noteW + BG.pad - minX); s.height = max(s.height, n.y + BG.noteH + BG.pad) }
        return s
    }

    // MARK: lenses

    private var nowWeek: Int? { started.map { Int(Date().timeIntervalSince($0) / 86400 / 7) + 1 } }
    private func status(_ id: String) -> String { marks[id]?.status ?? "todo" }
    private func late(_ c: BoardCard) -> Bool { guard let now = nowWeek else { return false }; return status(c.id) == "todo" && c.week < now }
    private var heat: [String: Double] {
        var score: [String: Double] = [:]
        for c in store.cards where status(c.id) == "done" {
            let m = marks[c.id]; let r = store.data?.results[c.id]?.d7
            var s = (m?.visitors ?? 0) + (m?.signups ?? 0) * 10
            if let cl = r?.clicks, cl.count == 2, let a = cl[0], let b = cl[1] { s += max(0, (b - a) * Double(r?.elapsed ?? 7)) }
            if let ra = r?.ratings, ra.count == 2, let a = ra[0], let b = ra[1] { s += max(0, b - a) * 5 }
            score[c.id] = s
        }
        let top = score.values.max() ?? 0
        return score.mapValues { top > 0 ? $0 / top : 0 }
    }

    // MARK: view

    var body: some View {
        GeometryReader { geo in
            let p = placed
            let size = boardSize(p.bottom, weeks: p.weeks.count)
            ZStack(alignment: .topLeading) {
                DotGrid(offset: offset, scale: scale).accessibilityElement().accessibilityIdentifier("growth-canvas")
                board(p, size: size)
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
                    .scaleEffect(scale, anchor: .topLeading)
                    .offset(offset)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .clipped()
            .contentShape(Rectangle())
            .gesture(panGesture.simultaneously(with: zoomGesture))
            .onAppear { if !fitted { fit(geo.size, size); fitted = true } }
            .onChange(of: lens) { _, _ in fit(geo.size, size) }
            .overlay(alignment: .bottomTrailing) {
                Button { withAnimation(.snappy) { fit(geo.size, size, all: true) } } label: { Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 15, weight: .semibold)).frame(width: 40, height: 40).background(.white, in: Circle()).overlay(Circle().stroke(Color.slLine)) }
                    .foregroundStyle(Color.slInkSoft).padding(.trailing, 14).padding(.bottom, readonly ? 168 : 92).accessibilityLabel(t("growth.canvas.fit"))
            }
        }
    }

    private func fit(_ view: CGSize, _ size: CGSize, all: Bool = false) {
        let k = all ? min(1, max(0.2, min((view.width - 24) / size.width, (view.height - 180) / size.height))) : min(0.62, max(0.42, (view.width - 24) / (BG.cardW + BG.framePad * 2 + 30)))
        scale = k; scaleBase = k
        let x = all ? max(12, (view.width - size.width * k) / 2) : 12 - (showInbox && !all ? (BG.inboxW - 0) * k : 0)
        offset = CGSize(width: x, height: 74); panBase = offset
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { v in guard held == nil, !pinching else { return }; offset = CGSize(width: panBase.width + v.translation.width, height: panBase.height + v.translation.height) }
            .onEnded { _ in panBase = offset }
    }
    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { v in
                pinching = true
                let k = min(1.5, max(0.2, scaleBase * v.magnification))
                // the point under the fingers stays under the fingers
                let a = v.startLocation
                offset = CGSize(width: a.x - (a.x - panBase.width) * (k / scaleBase), height: a.y - (a.y - panBase.height) * (k / scaleBase))
                scale = k
            }
            .onEnded { _ in scaleBase = scale; panBase = offset; pinching = false }
    }

    /// Screen point (in the canvas) → board point.
    private func toBoard(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - offset.width) / scale + minX, y: (p.y - offset.height) / scale) }

    private typealias Placed = (cards: [PlacedCard], sugs: [PlacedSug], bottom: CGFloat, weeks: [(Int, CGFloat)])

    private func board(_ p: Placed, size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            BoardLines(columns: columns, placed: p.cards, stickies: store.stickies, links: store.links, frames: timed ? [] : store.frames, bottom: p.bottom, timed: timed, dx: -minX, inbox: showInbox ? store.inbox.count : 0, inboxX: inboxX)
            headsLayer(p)
            inboxLayer
            listsLayer
            sugLayer(p)
            cardsLayer(p)
            stickiesLayer
            heldLayer
        }
        .coordinateSpace(name: "board")
    }

    @ViewBuilder private func headsLayer(_ p: Placed) -> some View {
        let dx = -minX
        if timed {
            ForEach(p.weeks, id: \.0) { w, x in
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("growth.node.week", ["n": w])).font(.hand(28)).foregroundStyle(w == nowWeek ? Color.slAccent700 : Color.slInk)
                    if w == nowWeek { Chip(text: t("growth.lens.now"), tone: .accent) }
                }
                .offset(x: x + dx, y: BG.top - 80)
            }
        } else {
            ForEach(Array(columns.enumerated()), id: \.element.kind) { i, col in
                ColumnHead(kind: col.kind, title: col.title, note: col.note).frame(width: BG.cardW, height: 190, alignment: .bottomLeading).offset(x: BG.colX(i) + dx, y: BG.top - BG.framePad - 10 - 190)
            }
        }
    }

    @ViewBuilder private var inboxLayer: some View {
        if showInbox {
            let dx = -minX
            ColumnHead(kind: "inbox", title: t("growth.inbox.title"), note: t("growth.inbox.note")).frame(width: BG.cardW, height: 190, alignment: .bottomLeading).offset(x: inboxX + dx, y: BG.top - BG.framePad - 10 - 190)
            ForEach(Array(store.inbox.enumerated()), id: \.element.id) { i, it in
                InboxCard(item: it, onTake: { onInbox(it) }, onDismiss: { store.apply(store.engine.dismissInbox(store.board, id: it.id)) })
                    .frame(width: BG.cardW, height: BG.inboxH).offset(x: inboxX + dx, y: BG.top + CGFloat(i) * (BG.inboxH + BG.gapY))
            }
        }
    }

    @ViewBuilder private var listsLayer: some View {
        if showLists {
            let x = listsX - minX
            RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color.slGoodSoft.opacity(0.35))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.slGood.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [7, 6])))
                .frame(width: BG.cardW + BG.framePad * 2, height: listsBottom - BG.top + BG.framePad * 2).offset(x: x - BG.framePad, y: BG.top - BG.framePad)
            ColumnHead(kind: "lists", title: t("growth.lists.title"), note: t("growth.lists.note")).frame(width: BG.cardW, height: 190, alignment: .bottomLeading).offset(x: x, y: BG.top - BG.framePad - 10 - 190)
            ForEach(Array(store.prospects.enumerated()), id: \.element.id) { i, pr in
                ProspectTile(p: pr).frame(width: BG.cardW, height: BG.prosH).offset(x: x, y: BG.top + CGFloat(i) * (BG.prosH + BG.gapY))
                    .accessibilityElement(children: .combine).accessibilityIdentifier("prospect-\(pr.id)")
                    .onTapGesture { onProspect(pr.id) }
            }
        }
    }

    private func sugLayer(_ p: Placed) -> some View {
        ForEach(p.sugs) { s in
            SuggestionCard(sug: s.sug, onAdd: { onSuggestion(s.sug, s.kind) }, onDismiss: { store.apply(store.engine.dismiss(store.board, channel: s.sug.channel)) })
                .frame(width: BG.cardW, height: BG.sugH).offset(x: s.x - minX, y: s.y)
        }
    }

    private func cardsLayer(_ p: Placed) -> some View {
        let h = heat
        return ForEach(p.cards) { pc in cardView(pc, heat: h[pc.card.id]) }
    }

    private func cardView(_ pc: PlacedCard, heat: Double?) -> some View {
        let c = pc.card
        let owner = store.data?.team?.people.first { $0.id == c.owner }
        return CardTile(card: c, status: status(c.id), mark: marks[c.id], lens: lens, late: late(c), heat: heat, experiment: store.data?.experiments[c.id], owner: owner, comments: store.comments(for: c.id).count, lateBy: max(1, (nowWeek ?? c.week) - c.week), measured: readonly ? nil : store.attribution[c.id], bench: readonly ? nil : store.benchmark(c.channel))
            .frame(width: BG.cardW, height: BG.cardH)
            .opacity(held?.id == c.id ? 0.25 : 1)
            .offset(x: pc.x - minX, y: pc.y)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("card-" + c.id)
            .onTapGesture { onCard(c.id) }
            .gesture(holdDrag(id: c.id, sticky: false, origin: CGPoint(x: pc.x, y: pc.y)))
    }

    @ViewBuilder private var stickiesLayer: some View {
        if !timed {
            ForEach(store.stickies) { n in stickyView(n) }
        }
    }

    private func stickyView(_ n: Sticky) -> some View {
        let w: CGFloat = n.type == "image" ? (n.w ?? 260) : (["answer", "coach"].contains(n.type) ? BG.noteW + 60 : BG.noteW)
        return StickyTile(note: n, busy: store.busy.contains(n.id))
            .frame(width: w)
            .opacity(held?.id == n.id || lens == .status ? 0.25 : 1)
            .offset(x: n.x - minX, y: n.y)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("note-" + n.id)
            .onTapGesture { onSticky(n.id) }
            .gesture(holdDrag(id: n.id, sticky: true, origin: CGPoint(x: n.x, y: n.y)))
    }

    @ViewBuilder private var heldLayer: some View {
        if let held {
            heldTile(held)
                .rotationEffect(.degrees(-1.5))
                .shadow(color: Color.slInk.opacity(0.35), radius: 24, y: 18)
                .offset(x: held.at.x - held.grab.width - minX, y: held.at.y - held.grab.height)
        }
    }

    @ViewBuilder private func heldTile(_ held: Held) -> some View {
        if held.sticky, let n = store.stickies.first(where: { $0.id == held.id }) {
            StickyTile(note: n, busy: false).frame(width: BG.noteW)
        } else if let c = store.cards.first(where: { $0.id == held.id }) {
            CardTile(card: c, status: status(c.id), mark: marks[c.id], lens: .map, late: false, heat: nil, experiment: nil, owner: nil, comments: 0).frame(width: BG.cardW, height: BG.cardH)
        }
    }

    /// Hold a card or a note for a moment, then move it.
    private func holdDrag(id: String, sticky: Bool, origin: CGPoint) -> some Gesture {
        let hold = LongPressGesture(minimumDuration: 0.3)
        let drag = DragGesture(minimumDistance: 0, coordinateSpace: .named("board"))
        return hold.sequenced(before: drag)
            .onChanged { (v: SequenceGesture<LongPressGesture, DragGesture>.Value) in holdChanged(v, id: id, sticky: sticky, origin: origin) }
            .onEnded { (_: SequenceGesture<LongPressGesture, DragGesture>.Value) in holdEnded() }
    }

    private func holdChanged(_ v: SequenceGesture<LongPressGesture, DragGesture>.Value, id: String, sticky: Bool, origin: CGPoint) {
        guard !readonly, case .second(true, let drag) = v else { return }
        if held == nil { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        guard let drag else {
            if held == nil { held = Held(id: id, sticky: sticky, at: origin, grab: .zero) }
            return
        }
        let at = CGPoint(x: drag.location.x + minX, y: drag.location.y)
        let grab: CGSize = held?.grab ?? CGSize(width: drag.startLocation.x + minX - origin.x, height: drag.startLocation.y - origin.y)
        held = Held(id: id, sticky: sticky, at: at, grab: grab)
    }

    private func holdEnded() {
        defer { held = nil; panBase = offset }
        guard let h = held, !readonly else { return }
        let topLeft = CGPoint(x: h.at.x - h.grab.width, y: h.at.y - h.grab.height)
        if h.sticky {
            store.apply(store.engine.editSticky(store.board, id: h.id) { $0.x = topLeft.x.rounded(); $0.y = topLeft.y.rounded() })
        } else if timed {
            dropOnWeek(h.id, at: topLeft)
        } else {
            dropInColumn(h.id, at: topLeft)
        }
    }

    private func dropOnWeek(_ id: String, at topLeft: CGPoint) {
        let weeks = placed.weeks
        guard !weeks.isEmpty else { return }
        let i = Int(((topLeft.x - BG.pad - BG.framePad) / BG.weekW).rounded())
        let w: Int = i < 0 ? max(1, weeks[0].0 - 1) : (i >= weeks.count ? weeks[weeks.count - 1].0 + 1 : weeks[i].0)
        store.apply(store.engine.edit(store.board, id: id) { $0.week = Double(min(104, w)) })
    }

    private func dropInColumn(_ id: String, at topLeft: CGPoint) {
        let raw = Int(((topLeft.x + BG.cardW / 2 - BG.pad + BG.gapX / 2) / BG.colStep).rounded(.down))
        var kind = GrowthCols.all[max(0, min(3, raw))]
        let cost: Double = store.cards.first { $0.id == id }?.cost ?? 0
        // the free path holds only what costs nothing
        if kind == "free", cost > 0 { kind = "paid" }
        let others: [BoardCard] = (columns.first { $0.kind == kind }?.cards ?? []).filter { $0.id != id }
        var index = 0
        for j in 0..<others.count where BG.top + CGFloat(j) * (BG.cardH + BG.gapY) + BG.cardH / 2 < topLeft.y + BG.cardH / 2 { index = j + 1 }
        let from: BoardColumn? = columns.first { $0.cards.contains { $0.id == id } }
        let at: Int = from?.cards.firstIndex { $0.id == id } ?? -1
        let target = (from?.kind == kind && at < index) ? index + 1 : index
        store.apply(store.engine.move(store.board, id: id, to: kind, index: target))
    }
}

// MARK: - Pieces

struct DotGrid: View {
    var offset: CGSize; var scale: CGFloat
    var body: some View {
        Canvas { ctx, size in
            let step = max(12, 40 * scale)
            let ox = offset.width.truncatingRemainder(dividingBy: step), oy = offset.height.truncatingRemainder(dividingBy: step)
            var y = oy
            while y < size.height { var x = ox; while x < size.width { ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)), with: .color(Color.slInk.opacity(0.1))); x += step }; y += step }
        }
        .background(Color.slPaper)
    }
}

struct ColumnHead: View {
    var kind: String; var title: String; var note: String
    private var color: Color { ["fix": .slWarn, "free": .slAccent600, "paid": .slInk, "scale": .slMarker, "inbox": .slAccent800, "lists": .slGood][kind] ?? .slInk }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(kind == "inbox" ? t("growth.inbox.kind").uppercased() : kind == "lists" ? t("growth.lists.kind").uppercased() : t("growth.phase." + kind).uppercased())
                .font(.dm(10.5, .heavy)).tracking(1.2).foregroundStyle(kind == "scale" ? Color.slInk : .white)
                .padding(.horizontal, 9).padding(.vertical, 4).background(color, in: Capsule())
            Text(title.isEmpty ? t("growth.board.phaseDefault." + kind) : title).font(.hand(30)).foregroundStyle(Color.slInk).lineLimit(2)
            if !note.isEmpty { Text(note).font(.hand(19)).foregroundStyle(Color.slAccent600).lineLimit(2) }
        }
    }
}

struct CardTile: View {
    var card: BoardCard; var status: String; var mark: Mark?; var lens: GrowthLens; var late: Bool; var heat: Double?; var experiment: Experiment?; var owner: Person?; var comments: Int
    var lateBy: Int = 1
    var measured: Measured? = nil
    var bench: Benchmark? = nil

    /// The status lens: where the step stands, in one word and one colour.
    private var stKey: String { late && status == "todo" ? "late" : status }
    private var stColor: Color { ["done": .slGood, "doing": .slMarker, "late": .slBad, "skipped": .slLineStrong][stKey] ?? .slInkMuted }
    private var bg: Color {
        if lens == .status { return ["done": Color.slGoodSoft, "doing": Color.slMarker.opacity(0.2), "late": Color.slBadSoft.opacity(0.6)][stKey] ?? Color.slPaper }
        if lens == .result, status == "done" { return Color.slGood.opacity(0.08 + 0.3 * (heat ?? 0)) }
        if status == "done" { return Color.slGoodSoft.opacity(0.7) }
        if lens == .status, status == "doing" { return Color.slMarker.opacity(0.25) }
        return card.source == "custom" ? Color.slMarker.opacity(0.14) : .white
    }
    private var dim: Bool { (lens == .status && status == "skipped") || (lens == .result && status != "done") }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: kindIcon(card.kind)).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.slAccent600)
                Text(card.channelName.isEmpty ? t("growth.board.custom") : card.channelName).font(.dm(12, .semibold)).foregroundStyle(Color.slInkMuted).lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: status == "done" ? "checkmark.circle.fill" : status == "doing" ? "play.circle.fill" : "circle").font(.system(size: 18)).foregroundStyle(status == "done" ? Color.slGood : status == "doing" ? Color.slMarker : Color.slLineStrong)
            }
            Text(card.title.isEmpty ? t("growth.board.customTitle") : card.title).font(.dm(16.5, .bold)).foregroundStyle(Color.slInk).lineLimit(2)
            Text(card.what).font(.dm(12.5)).foregroundStyle(Color.slInkSoft).lineLimit(2)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Text(card.cost > 0 ? "$" + Fmt.int(card.cost) : t("growth.node.free")).font(.dm(12.5, .heavy))
                    .padding(.horizontal, 7).padding(.vertical, 1).background(card.cost > 0 ? Color.slMarker.opacity(0.5) : Color.slTint100, in: RoundedRectangle(cornerRadius: 6))
                if let m = measured, m.clicks > 0, lens != .result {
                    measuredText(m)
                } else if let v = mark?.signups ?? mark?.visitors {
                    Text("\(Fmt.int(v)) " + (mark?.signups != nil ? t("growth.panel.signupsShort") : t("growth.panel.visitorsShort"))).font(.dm(11.5, .semibold)).foregroundStyle(Color.slInk)
                } else {
                    Label(t("growth.node.hours", ["n": Fmt.int(card.effortHours)]), systemImage: "clock").font(.dm(12)).foregroundStyle(Color.slInkMuted).labelStyle(.titleAndIcon)
                }
                if let b = bench, let r = b.results, status != "done", (measured?.clicks ?? 0) == 0 {
                    let warn = card.cost > 0 && b.warns
                    Label(t("growth.bench.chip", ["n": Fmt.int(r)]), systemImage: warn ? "exclamationmark.triangle" : "person.2").font(.dm(10.5, .semibold)).lineLimit(1).fixedSize()
                        .padding(.horizontal, 7).padding(.vertical, 2).foregroundStyle(warn ? Color.slWarn : Color.slInkMuted).background(warn ? Color.slWarnSoft : Color.slPaper, in: Capsule())
                }
                Spacer(minLength: 0)
                if let e = experiment { TestPill(e: e) }
                if comments > 0 { Label("\(comments)", systemImage: "bubble.left").font(.dm(11.5, .bold)).foregroundStyle(Color.slInkSoft) }
                if let owner { Text(owner.initials).font(.dm(10, .heavy)).foregroundStyle(.white).frame(width: 24, height: 24).background(Color(hex: owner.color), in: Circle()) }
            }
        }
        .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 14)
        .background(bg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(lens == .status ? stColor : status == "done" ? Color.slGood.opacity(0.7) : card.source == "custom" ? Color.slMarker : Color.slLine, style: StrokeStyle(lineWidth: 1.5, dash: lens == .status && (stKey == "todo" || stKey == "late") ? [6, 5] : [])))
        .overlay(alignment: .leading) { if lens == .status { UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20).fill(stColor).frame(width: 6) } }
        .overlay(alignment: .topLeading) {
            Text(t("growth.node.week", ["n": card.week])).font(.hand(17)).foregroundStyle(Color.slAccent700)
                .padding(.horizontal, 8).padding(.vertical, 1).background(Color.slPaper, in: Capsule()).overlay(Capsule().stroke(Color.slLine)).offset(x: 14, y: -11)
        }
        .overlay(alignment: .topTrailing) {
            if lens == .status {
                Text(stKey == "late" ? t("growth.lens.st.late", ["n": lateBy]) : t("growth.lens.st." + stKey)).font(.dm(11, .heavy)).textCase(.uppercase)
                    .foregroundStyle(stKey == "doing" || stKey == "skipped" ? Color.slInk : .white).padding(.horizontal, 9).padding(.vertical, 3).background(stColor, in: Capsule()).offset(x: -14, y: -11)
            } else if status == "done" { Text("✓ " + (mark?.auto == true ? t("growth.board.seen") : t("growth.board.doneStamp"))).font(.hand(16)).foregroundStyle(.white).padding(.horizontal, 8).background(Color.slGood, in: Capsule()).rotationEffect(.degrees(-3)).offset(x: -14, y: -11) }
        }
        .opacity(dim ? 0.45 : 1)
        .shadow(color: Color.slInk.opacity(0.08), radius: 12, y: 8)
    }
}

extension CardTile {
    /// "378 clicks · 42 accounts": what the card's own link brought.
    fileprivate func measuredText(_ m: Measured) -> some View {
        let more = m.signups.map { " · \(Fmt.int(Double($0))) " + t("growth.panel.signupsShort") } ?? m.installs.map { " · \(Fmt.int(Double($0))) " + t("growth.measure.installsShort") } ?? ""
        return Text("\(Fmt.int(Double(m.clicks))) " + t("growth.measure.clicksShort") + more).font(.dm(11.5, .semibold)).foregroundStyle(Color.slInk).lineLimit(1)
    }
}

/// A page worth being on, in the lists lane: whose list it is, why it matters, where it stands.
struct ProspectTile: View {
    var p: Prospect
    private var stColor: Color { p.followUp ? .slBad : ["sent": .slAccent600, "replied": .slMarker, "listed": .slGood, "declined": .slLineStrong][p.status] ?? .slInkMuted }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(p.host).font(.dm(11.5, .semibold)).foregroundStyle(Color.slInkMuted).lineLimit(1)
                Spacer(minLength: 4)
                Text(p.followUp ? t("growth.lists.nudge") : t("growth.lists.st." + p.status)).font(.dm(10.5, .heavy)).textCase(.uppercase)
                    .foregroundStyle(p.status == "todo" && !p.followUp ? Color.slInkSoft : .white).padding(.horizontal, 8).padding(.vertical, 2)
                    .background(p.status == "todo" && !p.followUp ? Color.slPaper : stColor, in: Capsule())
            }
            Text(p.shownTitle).font(.dm(15.5, .bold)).foregroundStyle(Color.slInk).lineLimit(2)
            Text(t("growth.lists.cited", ["n": p.answers, "engines": p.engines.count]) + (p.rivals.isEmpty ? "" : " · " + t("growth.lists.names", ["rivals": p.rivals.prefix(3).joined(separator: ", ")])))
                .font(.dm(12)).foregroundStyle(Color.slInkSoft).lineLimit(2)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                if p.hasContact {
                    Label(p.contact?.author ?? t("growth.lists.contact"), systemImage: "person.crop.circle.badge.checkmark").font(.dm(11.5, .semibold)).foregroundStyle(Color.slAccent700).lineLimit(1)
                } else {
                    Text(p.readAt != nil ? t("growth.lists.noContact") : t("growth.lists.notRead")).font(.dm(11.5)).foregroundStyle(Color.slInkMuted).lineLimit(1)
                }
                Spacer(minLength: 0)
                if let e = p.effect, let a = e.after, (e.days ?? 0) >= 7 { Text("AI \(e.before.map(String.init) ?? "—")% → \(a)%").font(.dm(11, .heavy)).foregroundStyle(.white).padding(.horizontal, 7).padding(.vertical, 2).background(Color.slGood, in: Capsule()) }
                else if p.draft != nil { Label(t("growth.lists.hasDraft"), systemImage: "envelope").font(.dm(11)).foregroundStyle(Color.slInkMuted).lineLimit(1) }
            }
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)
        .background(p.status == "listed" ? Color.slGoodSoft : .white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(p.followUp ? Color.slBad.opacity(0.6) : p.status == "listed" ? Color.slGood.opacity(0.6) : Color.slLine, lineWidth: 1.5))
        .shadow(color: Color.slInk.opacity(0.07), radius: 12, y: 8)
    }
}

struct TestPill: View {
    var e: Experiment
    var body: some View {
        let text: String = {
            switch e.verdict {
            case "running": return t("growth.test.day", ["n": e.elapsed ?? 0, "of": e.days ?? 0])
            case "won": return "✓ " + Fmt.int(e.value ?? 0)
            case "lost": return "✗ " + Fmt.int(e.value ?? 0)
            case "nodata": return t("growth.test.nodata")
            default: return t("growth.test.waiting")
            }
        }()
        Label(text, systemImage: "flask").font(.dm(11, .heavy)).labelStyle(.titleAndIcon)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .foregroundStyle(e.verdict == "won" || e.verdict == "lost" ? .white : Color.slInk)
            .background(e.verdict == "won" ? Color.slGood : e.verdict == "lost" ? Color.slBad : e.verdict == "running" ? Color.slMarker.opacity(0.4) : Color.slBg, in: Capsule())
    }
}

struct SuggestionCard: View {
    var sug: BoardSuggestion; var onAdd: () -> Void; var onDismiss: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(sug.rival != nil ? t("growth.rivals.chip") : t("growth.board.suggestion"), systemImage: sug.rival != nil ? "person.2" : "sparkles").font(.dm(10.5, .heavy)).foregroundStyle(Color.slAccent700).textCase(.uppercase)
            Text(sug.name).font(.dm(12.5, .semibold)).foregroundStyle(Color.slInkMuted)
            Text(sug.rival.map { t("growth.rivals.why", ["rivals": $0.rivals.joined(separator: ", "), "host": $0.host ?? "", "n": $0.answers ?? 0]) } ?? sug.why).font(.dm(12.5)).foregroundStyle(Color.slInkSoft).lineLimit(3)
            Spacer(minLength: 0)
            HStack {
                Text(sug.cost > 0 ? "$" + Fmt.int(sug.cost) : t("growth.node.free")).font(.dm(12.5, .heavy))
                Spacer()
                Button(t("growth.board.dismiss"), action: onDismiss).font(.dm(12, .semibold)).foregroundStyle(Color.slInkMuted).fixedSize()
                Button(action: onAdd) { Label(t("growth.board.accept"), systemImage: "plus.circle").font(.dm(12, .semibold)).lineLimit(1).fixedSize().padding(.horizontal, 10).padding(.vertical, 5).background(Color.slInk, in: Capsule()).foregroundStyle(.white) }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])).foregroundStyle(sug.rival != nil ? Color.slInk.opacity(0.35) : Color.slAccent500))
    }
}

struct InboxCard: View {
    var item: InboxItem; var onTake: () -> Void; var onDismiss: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(t("growth.inbox.src." + item.source), systemImage: ["seo": "magnifyingglass", "aio": "bubble.left.and.text.bubble.right", "aso": "iphone"][item.source] ?? "bell").font(.dm(10.5, .heavy)).foregroundStyle(Color.slInkMuted).textCase(.uppercase)
            Text(GrowthWords.inboxTitle(item)).font(.dm(15, .bold)).foregroundStyle(Color.slInk).lineLimit(2)
            Text(item.why?.isEmpty == false ? item.why! : GrowthWords.inboxWhy(item)).font(.dm(12.5)).foregroundStyle(Color.slInkSoft).lineLimit(3)
            Spacer(minLength: 0)
            HStack {
                Text(t("growth.node.free")).font(.dm(12.5, .heavy)).padding(.horizontal, 7).background(Color.slTint100, in: RoundedRectangle(cornerRadius: 6)).fixedSize()
                Text(t("growth.node.hours", ["n": Fmt.int(item.effortHours ?? 1)])).font(.dm(12)).foregroundStyle(Color.slInkMuted).fixedSize()
                Spacer(minLength: 4)
                Button(t("growth.board.dismiss"), action: onDismiss).font(.dm(12, .semibold)).foregroundStyle(Color.slInkMuted).fixedSize()
                Button(action: onTake) { Label(t("growth.inbox.take"), systemImage: "plus.circle").font(.dm(12, .semibold)).lineLimit(1).fixedSize().padding(.horizontal, 10).padding(.vertical, 5).background(Color.slInk, in: Capsule()).foregroundStyle(.white) }
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(alignment: .leading) { UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18).fill(item.source == "aio" ? Color.purple : item.source == "aso" ? Color.slWarn : Color.slAccent600).frame(width: 4) }
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.slLine, lineWidth: 1.5))
    }
}

struct StickyTile: View {
    var note: Sticky; var busy: Bool
    private var bg: Color { ["idea": .slTint100, "risk": .slBadSoft, "goal": .slGoodSoft, "link": .white, "answer": .white, "coach": .white, "image": .white][note.type] ?? Color.slMarker.opacity(0.62) }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if note.type == "image", let u = URL(string: note.url) {
                AsyncImage(url: u) { $0.resizable().scaledToFill() } placeholder: { Color.slBg }.frame(height: note.h ?? 180).clipped()
            } else {
                Label(t("growth.notes." + note.type), systemImage: ["idea": "lightbulb", "risk": "exclamationmark.triangle", "goal": "target", "link": "link", "answer": "sparkles", "coach": "checklist"][note.type] ?? "note.text")
                    .font(.dm(10.5, .heavy)).foregroundStyle(note.type == "risk" ? Color.slBad : note.type == "goal" ? Color.slGood : Color.slInk.opacity(0.6)).textCase(.uppercase)
                if let title = note.meta?.title { Text(title).font(.dm(13.5, .bold)).foregroundStyle(Color.slInk).lineLimit(2) }
                if note.type == "link", !note.url.isEmpty { Text(note.meta?.site ?? Fmt.host(note.url)).font(.dm(12, .semibold)).foregroundStyle(Color.slAccent800) }
                Text(note.text.isEmpty ? t("growth.notes.empty") : note.text)
                    .font(["answer", "coach"].contains(note.type) ? .dm(13.5, .medium) : .hand(21))
                    .foregroundStyle(note.text.isEmpty ? Color.slInk.opacity(0.4) : Color.slInk)
                if busy { Label(t("growth.ai.working"), systemImage: "sparkles").font(.dm(12, .bold)).foregroundStyle(Color.slAccent800) }
            }
        }
        .padding(note.type == "image" ? 0 : 14)
        .frame(minHeight: note.type == "image" ? nil : BG.noteH, alignment: .topLeading)
        .background(bg, in: RoundedRectangle(cornerRadius: note.type == "note" || note.type == "idea" || note.type == "risk" || note.type == "goal" ? 6 : 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(note.type == "coach" ? Color.slInk : note.type == "answer" ? Color.slAccent500 : .clear, style: StrokeStyle(lineWidth: 1.5, dash: note.type == "coach" ? [5, 4] : [])))
        .clipShape(RoundedRectangle(cornerRadius: note.type == "image" ? 10 : 16))
        .shadow(color: Color.slInk.opacity(0.18), radius: 14, y: 10)
        .rotationEffect(.degrees(["note", "idea", "risk", "goal"].contains(note.type) ? Double((Int(note.id.unicodeScalars.dropFirst(2).first?.value ?? 0) % 5) - 2) * 0.6 : 0))
    }
}

/// Frames, column arrows, card-to-card arrows and the notes' arrows, drawn under the cards.
struct BoardLines: View {
    var columns: [BoardColumn]; var placed: [PlacedCard]; var stickies: [Sticky]; var links: [BoardLink]; var frames: [BoardFrame]
    var bottom: CGFloat; var timed: Bool; var dx: CGFloat; var inbox: Int; var inboxX: CGFloat

    var body: some View {
        Canvas { ctx, _ in
            let rects: [String: CGRect] = {
                var m: [String: CGRect] = [:]
                for p in placed { m[p.card.id] = CGRect(x: p.x + dx, y: p.y, width: BG.cardW, height: BG.cardH) }
                for n in stickies { m[n.id] = CGRect(x: n.x + dx, y: n.y, width: n.type == "image" ? (n.w ?? 260) : BG.noteW, height: n.type == "image" ? (n.h ?? 180) : BG.noteH) }
                return m
            }()
            if !timed {
                let colors: [String: Color] = ["fix": .slWarn, "free": .slAccent500, "paid": .slInk.opacity(0.4), "scale": .slInk.opacity(0.5)]
                for (i, col) in columns.enumerated() {
                    let r = CGRect(x: BG.colX(i) - BG.framePad + dx, y: BG.top - BG.framePad, width: BG.cardW + BG.framePad * 2, height: bottom - BG.top + BG.framePad * 2)
                    let path = Path(roundedRect: r, cornerRadius: 28)
                    ctx.fill(path, with: .color(col.kind == "fix" ? Color.slWarnSoft.opacity(0.35) : col.kind == "free" ? Color.slTint50.opacity(0.85) : Color.white.opacity(0.6)))
                    ctx.stroke(path, with: .color(colors[col.kind] ?? .slLineStrong), style: StrokeStyle(lineWidth: 1.5, dash: [7, 7]))
                    if i < 3 {
                        var a = Path(); let y = BG.top + BG.cardH / 2
                        a.move(to: CGPoint(x: BG.colX(i) + BG.cardW + BG.framePad + dx, y: y)); a.addLine(to: CGPoint(x: BG.colX(i + 1) - BG.framePad - 4 + dx, y: y))
                        ctx.stroke(a, with: .color(Color.slAccent700), lineWidth: 2.5)
                        ctx.fill(arrowHead(at: CGPoint(x: BG.colX(i + 1) - BG.framePad + dx, y: y), angle: 0), with: .color(Color.slAccent700))
                    }
                }
                if inbox > 0 {
                    let r = CGRect(x: inboxX - BG.framePad + dx, y: BG.top - BG.framePad, width: BG.cardW + BG.framePad * 2, height: CGFloat(inbox) * (BG.inboxH + BG.gapY) - BG.gapY + BG.framePad * 2)
                    ctx.stroke(Path(roundedRect: r, cornerRadius: 28), with: .color(Color.slAccent600.opacity(0.55)), style: StrokeStyle(lineWidth: 1.5, dash: [7, 7]))
                }
                // frames: a box around each run of a frame's cards in a column
                for f in frames {
                    let members = placed.filter { f.cards.contains($0.card.id) }
                    for x in Set(members.map(\.x)) {
                        let ys = members.filter { $0.x == x }.map(\.y)
                        guard let lo = ys.min(), let hi = ys.max() else { continue }
                        let r = CGRect(x: x - 10 + dx, y: lo - 10, width: BG.cardW + 20, height: hi - lo + BG.cardH + 20)
                        ctx.stroke(Path(roundedRect: r, cornerRadius: 24), with: .color(Color.slAccent600), lineWidth: 2)
                    }
                }
            }
            let cardIds = Set(placed.map(\.card.id))
            for l in links {
                // in the weeks lens the notes are not on the board: only the arrows between cards stay
                if timed && !(cardIds.contains(l.from) && cardIds.contains(l.to)) { continue }
                guard let a = rects[l.from], let b = rects[l.to] else { continue }
                let p1 = edge(a, toward: CGPoint(x: b.midX, y: b.midY)), p2 = edge(b, toward: CGPoint(x: a.midX, y: a.midY))
                var path = Path()
                path.move(to: p1)
                let mid = CGPoint(x: (p1.x + p2.x) / 2 - (p2.y - p1.y) * 0.12, y: (p1.y + p2.y) / 2 + (p2.x - p1.x) * 0.12)
                path.addQuadCurve(to: p2, control: mid)
                let dep = placed.contains { $0.card.id == l.from } && placed.contains { $0.card.id == l.to }
                ctx.stroke(path, with: .color(dep ? Color.slInk : Color.slInkSoft), style: StrokeStyle(lineWidth: dep ? 2.2 : 2, lineCap: .round, dash: dep ? [] : [2, 6]))
                ctx.fill(arrowHead(at: p2, angle: atan2(p2.y - mid.y, p2.x - mid.x)), with: .color(dep ? Color.slInk : Color.slInkSoft))
            }
        }
    }

    private func edge(_ r: CGRect, toward p: CGPoint) -> CGPoint {
        let dx = p.x - r.midX, dy = p.y - r.midY
        guard dx != 0 || dy != 0 else { return CGPoint(x: r.midX, y: r.midY) }
        let s = min(abs((r.width / 2 + 6) / (dx == 0 ? 1e-6 : dx)), abs((r.height / 2 + 6) / (dy == 0 ? 1e-6 : dy)))
        return CGPoint(x: r.midX + dx * s, y: r.midY + dy * s)
    }
    private func arrowHead(at p: CGPoint, angle: CGFloat) -> Path {
        var path = Path()
        let l: CGFloat = 10, w: CGFloat = 5
        path.move(to: p)
        path.addLine(to: CGPoint(x: p.x - l * cos(angle) + w * sin(angle), y: p.y - l * sin(angle) - w * cos(angle)))
        path.addLine(to: CGPoint(x: p.x - l * cos(angle) - w * sin(angle), y: p.y - l * sin(angle) + w * cos(angle)))
        path.closeSubpath()
        return path
    }
}

func kindIcon(_ k: String) -> String {
    ["launch": "paperplane", "community": "person.3", "directory": "folder", "content": "square.and.pencil", "newsletter": "envelope", "creator": "video", "ads": "dollarsign.circle", "fix": "slider.horizontal.3", "custom": "pencil"][k] ?? "star"
}

enum GrowthWords {
    static func inboxTitle(_ it: InboxItem) -> String {
        guard it.kind == "store_drop" else { return it.title ?? "" }
        if let now = it.data?.now { return t("growth.inbox.storeDrop", ["term": it.data?.term ?? "", "was": it.data?.was ?? 0, "now": now]) }
        return t("growth.inbox.storeGone", ["term": it.data?.term ?? "", "was": it.data?.was ?? 0])
    }
    static func inboxWhy(_ it: InboxItem) -> String { it.kind == "store_drop" ? t("growth.inbox.storeDropWhy") : "" }
}

extension Color {
    /// "#0F6E6E" → a colour (the people's colours on the board).
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let v = UInt64(h, radix: 16) ?? 0x0F6E6E
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}
