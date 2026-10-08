//
//  GrowthScreen.swift
//  seenlab
//
//  The Growth tab: the board fills the screen, like on the web. A floating header (the board and its maps, the
//  budget, the button that draws the map, the rest in a menu) and a floating bar at the bottom (lenses, notes,
//  the coach, undo). The first time, the budget card sits in the middle of the empty board. Free accounts see
//  the sample board with the way to Pro.
//

import SwiftUI

struct GrowthScreen: View {
    @EnvironmentObject private var projects: ProjectStore
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.openURL) private var openURL
    @StateObject private var real = GrowthStore()
    @StateObject private var sample = GrowthStore()
    private var store: GrowthStore { locked ? sample : real }
    @State private var lens: GrowthLens = .map
    @State private var openCard: OpenID?
    @State private var openSticky: OpenID?
    @State private var budgetOpen = false
    @State private var blank = false

    struct OpenID: Identifiable { let id: String }

    private var locked: Bool { real.sharedId == nil && auth.user?.subscription?.tools == false }
    private var showStart: Bool { !locked && !store.running && !store.hasPlan && (store.data?.maps.isEmpty ?? true) && store.cards.isEmpty && store.stickies.isEmpty && !blank && store.data != nil }
    private var started: Date? { locked ? Date().addingTimeInterval(-33 * 86400) : store.data?.generatedAt.flatMap { ISO8601DateFormatter().date(from: $0) } }

    var body: some View {
        ZStack(alignment: .top) {
            Color.slPaper.ignoresSafeArea()
            if store.data != nil {
                GrowthCanvas(store: store, lens: lens, readonly: locked, marks: store.marks, started: started,
                             onCard: { openCard = OpenID(id: $0) }, onSticky: { openSticky = OpenID(id: $0) },
                             onSuggestion: { s, kind in store.apply(store.engine.add(store.board, channel: s.channel, why: s.why, kind: kind).0) },
                             onInbox: { it in store.apply(store.engine.takeInbox(store.board, item: it, title: GrowthWords.inboxTitle(it))); store.notice = t("growth.inbox.taken") })
                    .id((store.sharedId ?? projects.currentId ?? 0).description + (store.data?.current?.description ?? "d"))
            } else if store.loading {
                ProgressView().tint(Color.slAccent600).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let e = store.error {
                ErrorCard(message: e) { Task { await store.load(project: projects.currentId) } }.padding(20).padding(.top, 80)
            }

            header.padding(.horizontal, 12).padding(.top, 6)

            if showStart {
                StartCard(budget: $real.budget, app: boardName, busy: store.running, onMake: { Task { await store.make() } }, onBlank: { blank = true })
                    .frame(maxHeight: .infinity).padding(.horizontal, 16)
            }
            if store.running {
                VStack(spacing: 10) {
                    ProgressView().tint(Color.slAccent600)
                    Text(store.job?.type == "growth_revise" ? t("growth.revising") : t("growth.making")).font(.dm(15, .semibold)).foregroundStyle(Color.slInk)
                    Text(t("growth.thinkingStep1")).font(.dm(13)).foregroundStyle(Color.slInkMuted).multilineTextAlignment(.center)
                }
                .padding(24).frame(maxWidth: 320).background(.white, in: RoundedRectangle(cornerRadius: 24)).shadow(color: Color.slInk.opacity(0.2), radius: 30, y: 20)
                .frame(maxHeight: .infinity)
            }
            if let n = store.notice {
                Text(n).font(.dm(13, .semibold)).foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.slInk, in: Capsule()).padding(.top, 70).transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: n) { try? await Task.sleep(for: .seconds(3.5)); withAnimation { store.notice = nil } }
            }
        }
        .overlay(alignment: .bottom) { if !showStart { bottomBar.padding(.horizontal, 12).padding(.bottom, 10) } }
        .task(id: projects.currentId) { await real.load(project: projects.currentId) }
        .task(id: locked) { if locked { sample.loadSample() } }
        .task { while !Task.isCancelled { try? await Task.sleep(for: .seconds(15)); await real.refreshIfShared() } }
        .sheet(item: $openCard) { o in
            if let c = store.cards.first(where: { $0.id == o.id }) { GrowthCardSheet(store: store, card: c, readonly: locked, unlock: unlock) }
        }
        .sheet(item: $openSticky) { o in if store.stickies.contains(where: { $0.id == o.id }) { GrowthStickySheet(store: store, id: o.id) { openCard = OpenID(id: $0) } } }
        .sheet(isPresented: $budgetOpen) { BudgetSheet(budget: store.budget) { b in Task { await store.setBudget(b) } } }
        .animation(.snappy, value: store.notice)
    }

    private var boardName: String { store.sharedId.flatMap { id in store.shared.first { $0.appId == id }?.name } ?? projects.current?.name ?? "" }
    private func unlock() { openURL(URL(string: "https://seenlab.io/app/checkout?plan=pro&interval=month")!) }

    // MARK: header

    private var header: some View {
        HStack(spacing: 8) {
            Menu {
                if let maps = store.data?.maps, !maps.isEmpty, !locked {
                    Section(t("growth.history.title")) {
                        ForEach(Array(maps.enumerated()), id: \.element.id) { i, m in
                            Button { Task { await store.openMap(m.id) } } label: {
                                Label((i == 0 ? t("growth.history.latest") : t("growth.history.version", ["n": maps.count - i])) + " · $" + Fmt.int(m.budget) + " · \(m.done ?? 0)/\(m.steps ?? 0)", systemImage: m.id == store.data?.current ? "checkmark" : "map")
                            }
                        }
                    }
                }
                if !store.shared.isEmpty {
                    Section(t("growth.team.boards")) {
                        if !projects.projects.isEmpty { Button { Task { await store.openShared(nil) } } label: { Label(projects.current?.name ?? "", systemImage: store.sharedId == nil ? "checkmark" : "person") } }
                        ForEach(store.shared) { b in Button { Task { await store.openShared(b.appId) } } label: { Label(b.name + " · " + t("growth.team.by", ["name": b.owner ?? ""]), systemImage: store.sharedId == b.appId ? "checkmark" : "person.2") } }
                    }
                }
                Section { ForEach(projects.projects) { p in Button { projects.select(p.id); Task { await store.openShared(nil) } } label: { Label(p.name, systemImage: p.id == projects.currentId && store.sharedId == nil ? "checkmark" : "app") } } }
            } label: {
                HStack(spacing: 8) {
                    RemoteIcon(url: projects.current?.iconUrl, size: 30, fallback: projects.current?.platformIcon ?? "app.fill")
                    VStack(alignment: .leading, spacing: 0) {
                        Text(t("growth.ws.hand")).font(.hand(15)).foregroundStyle(Color.slAccent600)
                        Text(boardName).font(.dm(14, .bold)).foregroundStyle(Color.slInk).lineLimit(1)
                    }
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.slInkMuted)
                }
            }
            Spacer(minLength: 4)
            if !locked {
                Button { budgetOpen = true } label: {
                    Text("$" + Fmt.int(Double(store.budget))).font(.dm(13.5, .heavy)).foregroundStyle(Color.slInk)
                        .padding(.horizontal, 10).frame(height: 34).background(.white, in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.slLine))
                }
                Button { Task { await store.make() } } label: {
                    Image(systemName: "map").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).frame(width: 36, height: 34).background(Color.slInk, in: RoundedRectangle(cornerRadius: 10))
                }
                .disabled(store.running).accessibilityLabel(store.hasPlan ? t("growth.remake") : t("growth.make"))
            }
            Menu {
                if !locked {
                    if store.hasPlan, store.data?.current != nil { Button { Task { await store.revise() } } label: { Label(t("growth.revise"), systemImage: "arrow.triangle.2.circlepath") } }
                    Button { Task { await store.make() } } label: { Label(store.hasPlan ? t("growth.remake") : t("growth.make"), systemImage: "map") }
                }
                Button { openURL(URL(string: "https://seenlab.io/app/growth")!) } label: { Label(t("ios.openWeb"), systemImage: "safari") }
                if locked { Button { unlock() } label: { Label(t("growth.locked.cta"), systemImage: "lock.open") } }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 16, weight: .bold)).foregroundStyle(Color.slInkSoft).frame(width: 34, height: 34)
            }
        }
        .padding(.horizontal, 10).frame(height: 54)
        .background(.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.slLine))
        .shadow(color: Color.slInk.opacity(0.12), radius: 20, y: 12)
    }

    // MARK: the bottom bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if locked {
                HStack(spacing: 10) {
                    Label(t("growth.locked.tag"), systemImage: "lock.fill").font(.dm(11, .heavy)).padding(.horizontal, 8).padding(.vertical, 4).background(Color.slMarker, in: Capsule()).foregroundStyle(Color.slInk)
                    Text(t("growth.locked.text")).font(.dm(12)).foregroundStyle(Color.slInkSoft).lineLimit(2)
                    Button(t("growth.locked.cta")) { unlock() }.font(.dm(12.5, .semibold)).padding(.horizontal, 12).padding(.vertical, 8).background(Color.slInk, in: Capsule()).foregroundStyle(.white)
                }
                .padding(10).background(.white, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.slLine))
            }
            HStack(spacing: 4) {
                ForEach(GrowthLens.allCases, id: \.self) { l in
                    Button { withAnimation(.snappy) { lens = l } } label: {
                        Image(systemName: l.icon).font(.system(size: 15, weight: .semibold)).frame(width: 38, height: 36)
                            .foregroundStyle(lens == l ? .white : Color.slInkSoft).background(lens == l ? Color.slInk : .clear, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityLabel(t("growth.lens." + l.rawValue)).accessibilityIdentifier("lens-" + l.rawValue)
                }
                if !locked {
                    Divider().frame(height: 22).padding(.horizontal, 2)
                    Menu {
                        ForEach(["note", "idea", "risk", "goal"], id: \.self) { k in
                            Button { addNote(k) } label: { Label(t("growth.notes.add." + k), systemImage: ["idea": "lightbulb", "risk": "exclamationmark.triangle", "goal": "target"][k] ?? "note.text") }
                        }
                    } label: { Image(systemName: "note.text.badge.plus").font(.system(size: 16, weight: .semibold)).frame(width: 38, height: 36).foregroundStyle(Color.slInkSoft) }
                        .accessibilityIdentifier("add-note")
                    if store.hasPlan {
                        Button { Task { await store.coach(spot: spot) } } label: {
                            Group { if store.busy.contains("coach") { ProgressView().scaleEffect(0.8) } else { Image(systemName: "wand.and.sparkles") } }
                                .font(.system(size: 15, weight: .semibold)).frame(width: 38, height: 36).foregroundStyle(Color.slInkSoft)
                        }
                        .accessibilityLabel(t("growth.coach.button")).accessibilityIdentifier("coach")
                    }
                    Button { store.undoLast() } label: { Image(systemName: "arrow.uturn.backward").font(.system(size: 15, weight: .semibold)).frame(width: 38, height: 36).foregroundStyle(store.canUndo ? Color.slInkSoft : Color.slInkFaint) }
                        .disabled(!store.canUndo).accessibilityLabel(t("growth.board.undo"))
                }
            }
            .padding(4).background(.white, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.slLine))
            .shadow(color: Color.slInk.opacity(0.12), radius: 18, y: 10)
        }
    }

    /// A free place next to some cards (the coach's notes), or under the first column.
    private func spot(_ ids: [String]) -> (Double, Double) {
        let cols = store.columns
        var rects: [CGRect] = []
        for (i, col) in cols.enumerated() { for (j, c) in col.cards.enumerated() where ids.contains(c.id) { rects.append(CGRect(x: BG.colX(i), y: BG.top + CGFloat(j) * (BG.cardH + BG.gapY), width: BG.cardW, height: BG.cardH)) } }
        let taken = store.stickies.map { CGRect(x: $0.x, y: $0.y, width: BG.noteW + 60, height: BG.noteH + 20) }
        var x = (rects.map(\.maxX).max() ?? BG.colX(0)) + 36, y = rects.map(\.minY).min() ?? (BG.top + 4 * (BG.cardH + BG.gapY))
        for _ in 0..<12 where taken.contains(where: { $0.intersects(CGRect(x: x, y: y, width: BG.noteW + 60, height: BG.noteH + 20)) }) { y += BG.noteH + 24 }
        if rects.isEmpty { x = BG.colX(0) }
        return (Double(x), Double(y))
    }

    private func addNote(_ type: String) {
        let (x, y) = spot([])
        let (b, id) = store.engine.addSticky(store.board, type: type, x: x, y: y)
        store.apply(b)
        openSticky = OpenID(id: id)
    }
}

/// The first time: the budget and the button, in the middle of the empty board.
struct StartCard: View {
    @Binding var budget: Int
    var app: String
    var busy: Bool
    var onMake: () -> Void
    var onBlank: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: t("growth.hand"))
            (Text(t("growth.headline").components(separatedBy: "{budget}").first ?? "") + Text("$" + Fmt.int(Double(budget))).foregroundStyle(Color.slInk).underline(color: Color.slMarker)
             + Text((t("growth.headline").components(separatedBy: "{budget}").last ?? "").replacingOccurrences(of: "{app}", with: app)))
                .font(.dm(24, .bold)).tracking(-0.5).foregroundStyle(Color.slInk)
            Text(t("growth.ws.startSub")).font(.dm(14)).foregroundStyle(Color.slInkSoft)
            VStack(alignment: .leading, spacing: 10) {
                Slider(value: Binding(get: { Double(budget) }, set: { budget = Int(($0 / 50).rounded() * 50) }), in: 0...5000).tint(Color.slAccent600)
                HStack(spacing: 6) {
                    ForEach([300, 1000, 3000], id: \.self) { b in
                        Button("$" + Fmt.int(Double(b))) { budget = b }.font(.dm(12.5, .bold)).padding(.horizontal, 12).padding(.vertical, 7)
                            .foregroundStyle(budget == b ? .white : Color.slInkSoft).background(budget == b ? Color.slInk : .white, in: Capsule()).overlay(Capsule().stroke(Color.slLine))
                    }
                }
            }
            .padding(14).background(Color.slPaper, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.slLine))
            ForEach(1...3, id: \.self) { n in
                HStack(spacing: 10) {
                    Text("\(n)").font(.dm(11, .heavy)).foregroundStyle(Color.slAccent800).frame(width: 22, height: 22).background(Color.slTint100, in: Circle())
                    Text(t("growth.ws.step\(n)")).font(.dm(13)).foregroundStyle(Color.slInkSoft)
                }
            }
            Button(action: onMake) { Label(t("growth.ws.draw", ["budget": "$" + Fmt.int(Double(budget))]), systemImage: "map").frame(maxWidth: .infinity) }
                .buttonStyle(SLButtonStyle(kind: .primary)).disabled(busy).padding(.top, 4)
            Button(t("growth.ws.blank"), action: onBlank).font(.dm(13, .semibold)).foregroundStyle(Color.slInkMuted).frame(maxWidth: .infinity)
        }
        .padding(22).background(.white, in: RoundedRectangle(cornerRadius: 26)).overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.slLine))
        .shadow(color: Color.slInk.opacity(0.2), radius: 40, y: 24)
    }
}

struct BudgetSheet: View {
    @State var budget: Int
    var onSave: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: t("growth.ws.budgetHand"))
            Text("$" + Fmt.int(Double(budget))).font(.dm(34, .bold)).foregroundStyle(Color.slInk)
            Slider(value: Binding(get: { Double(budget) }, set: { budget = Int(($0 / 50).rounded() * 50) }), in: 0...5000).tint(Color.slAccent600)
            HStack(spacing: 6) { ForEach([300, 1000, 3000], id: \.self) { b in Button("$" + Fmt.int(Double(b))) { budget = b }.font(.dm(12.5, .bold)).padding(.horizontal, 12).padding(.vertical, 7).foregroundStyle(budget == b ? .white : Color.slInkSoft).background(budget == b ? Color.slInk : .white, in: Capsule()).overlay(Capsule().stroke(Color.slLine)) } }
            Text(t("growth.reviseHint")).font(.dm(12)).foregroundStyle(Color.slInkMuted)
            Button(t("growth.ws.setBudget")) { onSave(budget); dismiss() }.buttonStyle(SLButtonStyle(kind: .primary)).frame(maxWidth: .infinity)
        }
        .padding(24)
        .presentationDetents([.height(360)])
    }
}
