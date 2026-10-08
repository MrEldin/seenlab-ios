//
//  GrowthSheets.swift
//  seenlab
//
//  A step opened from its card (what, why, how, the ready texts, what it brought, the experiment, the mark, who does
//  it, the conversation), and a note opened from the board (its kind, its text, the AI on it).
//

import SwiftUI

struct GrowthCardSheet: View {
    @ObservedObject var store: GrowthStore
    let card: BoardCard
    var readonly: Bool
    var unlock: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var status = "todo"
    @State private var visitors = ""
    @State private var signups = ""
    @State private var spent = ""
    @State private var note = ""
    @State private var saving = false
    @State private var saved = false
    @State private var error: String?
    @State private var say = ""
    @State private var testOn = false
    @State private var metric = "clicks"
    @State private var target = "30"
    @State private var days = 14
    @State private var linking = false

    private var mark: Mark? { store.marks[card.id] }
    private var result: StepResult? { store.data?.results[card.id] }
    private var experiment: Experiment? { store.data?.experiments[card.id] }
    private var people: [Person] { store.data?.team?.people ?? [] }
    private var measured: Measured? { store.attribution[card.id] }
    private var bench: Benchmark? { store.benchmark(card.channel) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: kindIcon(card.kind)).font(.system(size: 20)).foregroundStyle(Color.slAccent700).frame(width: 44, height: 44).background(Color.slTint100, in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 3) {
                            Text((card.channelName.isEmpty ? t("growth.board.custom") : card.channelName) + " · " + t("growth.node.week", ["n": card.week])).font(.dm(11, .semibold)).foregroundStyle(Color.slInkMuted).textCase(.uppercase)
                            Text(card.title.isEmpty ? t("growth.board.customTitle") : card.title).font(.dm(19, .bold)).foregroundStyle(Color.slInk)
                        }
                    }
                    HStack(spacing: 10) {
                        KpiTile(label: t("growth.panel.cost"), value: card.cost > 0 ? "$" + Fmt.int(card.cost) : t("growth.node.free"))
                        KpiTile(label: t("growth.panel.effort"), value: t("growth.node.hours", ["n": Fmt.int(card.effortHours)]))
                    }
                    if !card.what.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(t("growth.panel.what")).font(.dm(11, .semibold)).foregroundStyle(Color.slAccent800).textCase(.uppercase)
                            Text(card.what).font(.dm(14)).foregroundStyle(Color.slInk)
                            if let u = card.url, let url = URL(string: u) { Link(destination: url) { Label(t("growth.panel.open", ["name": Fmt.host(u)]), systemImage: "arrow.up.right").font(.dm(13, .semibold)) }.tint(Color.slAccent700) }
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.slTint50, in: RoundedRectangle(cornerRadius: 16))
                    }
                    if !card.why.isEmpty { (Text(t("growth.panel.why") + " ").font(.hand(19)).foregroundStyle(Color.slAccent600) + Text(card.why).font(.dm(14)).foregroundStyle(Color.slInk)).padding(14).frame(maxWidth: .infinity, alignment: .leading).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.slLine)) }

                    if mark?.status == "done", let w = result?.d7 ?? result?.d30 { results(w) }
                    if !readonly { linkBox }
                    if !readonly, let b = bench { benchBox(b) }
                    if !readonly { experimentBox }

                    if !card.steps.isEmpty {
                        Text(t("growth.panel.steps")).font(.dm(14, .bold)).foregroundStyle(Color.slInk).padding(.top, 4)
                        ForEach(Array(card.steps.enumerated()), id: \.offset) { i, s in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(i + 1)").font(.dm(11, .heavy)).foregroundStyle(Color.slAccent800).frame(width: 24, height: 24).background(Color.slTint100, in: Circle())
                                Text(s).font(.dm(14)).foregroundStyle(Color.slInkSoft)
                            }
                        }
                    }
                    if !card.copy.isEmpty {
                        Text(t("growth.panel.copy")).font(.dm(14, .bold)).foregroundStyle(Color.slInk).padding(.top, 4)
                        ForEach(Array(card.copy.enumerated()), id: \.offset) { _, c in DraftBox(title: c.label ?? c.kind, text: c.text) }
                    }

                    if readonly {
                        Button(t("growth.locked.cta"), action: unlock).buttonStyle(SLButtonStyle(kind: .primary)).frame(maxWidth: .infinity).padding(.top, 8)
                    } else {
                        markBox
                        if people.count > 1 { whoBox }
                        commentsBox
                    }
                }
                .padding(20)
            }
            .background(Color.white)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button(t("ios.close")) { dismiss() }.accessibilityIdentifier("sheet-close") }
                if !readonly { ToolbarItem(placement: .topBarLeading) { Button(role: .destructive) { store.apply(store.engine.remove(store.board, id: card.id)); dismiss() } label: { Image(systemName: "trash") }.accessibilityLabel(t("growth.board.remove")) } }
            }
        }
        .onAppear {
            status = mark?.status ?? "todo"
            visitors = mark?.visitors.map { Fmt.int($0) } ?? ""; signups = mark?.signups.map { Fmt.int($0) } ?? ""; spent = mark?.spent.map { Fmt.int($0) } ?? ""; note = mark?.note ?? ""
            if let tst = card.test { testOn = true; metric = tst.metric; target = Fmt.int(tst.target); days = tst.days }
        }
    }

    private func results(_ w: ResultWindow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("growth.results.title")).font(.dm(11, .semibold)).foregroundStyle(Color.slGood).textCase(.uppercase)
            ForEach([("clicks", w.clicks), ("ratings", w.ratings), ("ai", w.ai)], id: \.0) { key, v in
                if let v, v.count == 2 {
                    HStack {
                        Text(t("growth.results." + key)).font(.dm(13.5)).foregroundStyle(Color.slInkSoft)
                        Spacer()
                        Text((v[0].map { Fmt.int($0) } ?? "—") + " → ").font(.dm(13.5)).foregroundStyle(Color.slInkMuted)
                        Text(v[1].map { Fmt.int($0) } ?? "—").font(.dm(13.5, .bold)).foregroundStyle((v[1] ?? 0) > (v[0] ?? 0) ? Color.slGood : Color.slInk)
                    }
                }
            }
        }
        .padding(14).background(Color.slGoodSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: what the card's link brought

    private var linkBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            linkHead
            if let m = measured { linkBody(m) } else { Text(t("growth.measure.whyLink")).font(.dm(12.5)).foregroundStyle(Color.slInkSoft) }
        }
        .padding(14).background(Color.slTint50.opacity(0.6), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.slAccent600.opacity(0.25)))
    }
    private var linkHead: some View {
        HStack {
            Label(t("growth.measure.cardTitle"), systemImage: "link").font(.dm(13.5, .bold)).foregroundStyle(Color.slInk)
            Spacer()
            if measured == nil {
                Button { linking = true; Task { await store.makeLink(card); linking = false } } label: { makeLinkLabel }
                    .padding(.horizontal, 12).padding(.vertical, 6).background(Color.slInk, in: Capsule()).foregroundStyle(.white).disabled(linking).accessibilityIdentifier("make-link")
            }
        }
    }
    @ViewBuilder private var makeLinkLabel: some View {
        if linking { ProgressView().tint(.white) } else { Text(t("growth.measure.makeLink")).font(.dm(12.5, .semibold)) }
    }
    private func shortURL(_ u: String) -> String { u.replacingOccurrences(of: #"^https?://"#, with: "", options: .regularExpression) }
    private func fromLine(_ m: Measured) -> String {
        let who = m.from.map { t("growth.measure.from." + $0) }.joined(separator: " · ")
        return t("growth.measure.fromLabel") + " " + who + (m.from.contains("apple") ? " — " + t("growth.measure.appleNote") : "")
    }
    private func numbers(_ m: Measured) -> [(String, Double, Bool)] {
        var out: [(String, Double, Bool)] = [(t("growth.measure.clicks"), Double(m.clicks), false)]
        if let v = m.visits { out.append((t("growth.measure.visits"), Double(v), false)) }
        if let v = m.installs { out.append((t("growth.measure.installs"), Double(v), false)) }
        if let v = m.signups { out.append((t("growth.measure.signups"), Double(v), false)) }
        if let v = m.revenue { out.append((t("growth.measure.revenue"), v, true)) }
        return out
    }
    @ViewBuilder private func linkBody(_ m: Measured) -> some View {
        HStack {
            Text(shortURL(m.url)).font(.system(size: 13, design: .monospaced)).foregroundStyle(Color.slInk).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 6)
            CopyButton(text: m.url)
        }
        .padding(10).background(.white, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.slLine))
        Text(t("growth.measure.pasteWhere")).font(.dm(12)).foregroundStyle(Color.slInkMuted)
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(numbers(m), id: \.0) { n in numTile(n.0, n.1, money: n.2) }
        }
        if !m.from.isEmpty {
            Text(fromLine(m)).font(.dm(11.5)).foregroundStyle(Color.slInkMuted)
        } else if m.clicks > 0 {
            Text(t("growth.measure.onlyClicks")).font(.dm(11.5)).foregroundStyle(Color.slInkMuted)
        }
    }
    private func numTile(_ label: String, _ v: Double, money: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.dm(11)).foregroundStyle(Color.slInkMuted)
            Text((money ? "$" : "") + Fmt.int(v)).font(.dm(19, .bold)).foregroundStyle(Color.slInk).monospacedDigit()
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 12))
    }

    /// What this channel brought similar products, and (before money goes) whether it paid back for them.
    private func benchBox(_ b: Benchmark) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(t("growth.bench.title." + b.scope, ["n": b.n])).font(.dm(11, .semibold)).foregroundStyle(Color.slInkMuted).textCase(.uppercase)
            if let r = b.results { Text(benchLead(b, r)).font(.dm(14.5, .semibold)).foregroundStyle(Color.slInk) }
            if let g = b.shareGood { Text(t("growth.bench.good", ["pct": g, "n": b.good ?? 20, "kind": t("growth.bench.kind." + b.kind)])).font(.dm(12.5)).foregroundStyle(Color.slInkSoft) }
            if let c = b.costPer { Text(t("growth.bench.cost", ["cost": Fmt.int(c), "kind": t("growth.bench.kindOne." + b.kind)])).font(.dm(12.5)).foregroundStyle(Color.slInkSoft) }
            if card.cost > 0, b.warns { benchWarn(b) }
            if let mine = benchMine(b), let r = b.results, r > 0 { benchMineLine(mine, r) }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.slLine))
    }
    private func benchLead(_ b: Benchmark, _ r: Double) -> String {
        let clicks = (b.clicks ?? 0) > 0 ? " · ~" + Fmt.int(b.clicks) + " " + t("growth.measure.clicksShort") : ""
        return "~" + Fmt.int(r) + " " + t("growth.bench.kind." + b.kind) + clicks
    }
    private func benchMine(_ b: Benchmark) -> Double? {
        let measuredValue: Int? = b.kind == "installs" ? (measured?.installs ?? measured?.signups) : measured?.signups
        if let v = measuredValue { return Double(v) }
        return mark?.signups
    }
    private func benchWarn(_ b: Benchmark) -> some View {
        Label(t("growth.bench.warn", ["ok": b.paidOk ?? 0, "n": b.paidN ?? 0]), systemImage: "exclamationmark.triangle").font(.dm(12.5, .semibold)).foregroundStyle(Color.slWarn)
            .padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Color.slWarnSoft, in: RoundedRectangle(cornerRadius: 12)).padding(.top, 4)
    }
    private func benchMineLine(_ mine: Double, _ r: Double) -> some View {
        let key = mine > r ? "above" : mine == r ? "same" : "below"
        return Text(t("growth.bench." + key, ["mine": Fmt.int(mine), "avg": Fmt.int(r)])).font(.dm(12.5, .semibold)).foregroundStyle(mine >= r ? Color.slGood : Color.slInkSoft).padding(.top, 2)
    }

    private var experimentBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(t("growth.test.heading"), systemImage: "flask").font(.dm(13.5, .bold)).foregroundStyle(Color.slInk)
                Spacer()
                Toggle("", isOn: $testOn).labelsHidden().tint(Color.slAccent600)
            }
            if testOn {
                Text(t("growth.test.explain")).font(.dm(12)).foregroundStyle(Color.slInkSoft)
                Picker(t("growth.test.metric"), selection: $metric) { ForEach(["clicks", "ratings", "ai", "visitors", "signups"], id: \.self) { Text(t("growth.test.metrics." + $0)).tag($0) } }.pickerStyle(.menu).tint(Color.slInk)
                HStack {
                    TextField(t("growth.test.target"), text: $target).keyboardType(.numberPad).font(.dm(15, .bold)).padding(10).background(Color.slPaper, in: RoundedRectangle(cornerRadius: 10))
                    Picker(t("growth.test.days"), selection: $days) { ForEach([7, 14, 30], id: \.self) { Text("\($0) " + t("growth.test.days").lowercased()).tag($0) } }.pickerStyle(.segmented)
                }
                if let e = experiment { Text(verdict(e)).font(.dm(13, .semibold)).foregroundStyle(e.verdict == "won" ? Color.slGood : e.verdict == "lost" ? Color.slBad : Color.slInk) }
            }
        }
        .padding(14).overlay(RoundedRectangle(cornerRadius: 16).stroke(style: StrokeStyle(lineWidth: 1.5, dash: testOn ? [] : [5, 4])).foregroundStyle(Color.slLineStrong))
        .onChange(of: testOn) { _, on in saveTest(on) }
        .onChange(of: metric) { _, _ in saveTest(testOn) }
        .onChange(of: days) { _, _ in saveTest(testOn) }
        .onSubmit { saveTest(testOn) }
    }
    private func saveTest(_ on: Bool) {
        let spec = on ? TestSpec(metric: metric, target: Double(target) ?? 0, days: days) : nil
        guard spec != card.test else { return }
        store.apply(store.engine.edit(store.board, id: card.id) { $0.test = spec })
    }
    private func verdict(_ e: Experiment) -> String {
        let unit = t("growth.test.units." + e.metric)
        switch e.verdict {
        case "running": return t("growth.test.v.running", ["n": e.elapsed ?? 0, "of": e.days ?? 0])
        case "won", "lost": return t("growth.test.v." + e.verdict, ["v": Fmt.int(e.value ?? 0), "unit": unit, "target": Fmt.int(e.target ?? 0)])
        case "nodata": return t("growth.test.v.nodata")
        default: return t("growth.test.v.waiting")
        }
    }

    private var markBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("growth.panel.status")).font(.dm(14, .bold)).foregroundStyle(Color.slInk).padding(.top, 6)
            Picker("", selection: $status) { ForEach(["todo", "doing", "done", "skipped"], id: \.self) { Text(t("growth.node." + $0)).tag($0) } }.pickerStyle(.segmented)
            if status == "done" {
                HStack(spacing: 8) {
                    field(t("growth.panel.visitors"), $visitors); field(t("growth.panel.signups"), $signups); field(t("growth.panel.spent"), $spent)
                }
            }
            TextField(t("growth.panel.note"), text: $note, axis: .vertical).font(.dm(14)).padding(10).background(Color.slPaper, in: RoundedRectangle(cornerRadius: 12))
            HStack {
                Button { Task { await saveMark() } } label: { if saving { ProgressView() } else { Text(t("growth.panel.save")) } }.buttonStyle(SLButtonStyle(kind: .primary)).disabled(saving)
                if saved { Text(t("growth.panel.saved")).font(.dm(12, .semibold)).foregroundStyle(Color.slGood) }
                if let error { Text(error).font(.dm(12, .semibold)).foregroundStyle(Color.slBad) }
            }
        }
    }
    private func field(_ label: String, _ v: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) { Text(label).font(.dm(11)).foregroundStyle(Color.slInkMuted); TextField("0", text: v).keyboardType(.numberPad).font(.dm(14, .semibold)).padding(8).background(Color.slPaper, in: RoundedRectangle(cornerRadius: 10)) }
    }
    private func saveMark() async {
        saving = true; error = nil; defer { saving = false }
        do {
            try await store.saveStep(card.id, status: status, visitors: Int(visitors), signups: Int(signups), spent: Int(spent), note: note.isEmpty ? nil : note)
            saved = true
        } catch { self.error = (error as? APIError)?.errorDescription }
    }

    private var whoBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("growth.team.who")).font(.dm(11, .semibold)).foregroundStyle(Color.slInkMuted).textCase(.uppercase)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(people) { p in
                        Button { store.apply(store.engine.edit(store.board, id: card.id) { $0.owner = card.owner == p.id ? nil : p.id }) } label: {
                            HStack(spacing: 6) {
                                Text(p.initials).font(.dm(9.5, .heavy)).foregroundStyle(.white).frame(width: 22, height: 22).background(Color(hex: p.color), in: Circle())
                                Text(p.id == store.data?.team?.me ? t("growth.team.me") : String(p.name.split(separator: " ").first ?? "")).font(.dm(12.5, .semibold))
                            }
                            .padding(.leading, 3).padding(.trailing, 10).padding(.vertical, 3)
                            .overlay(Capsule().stroke(card.owner == p.id ? Color.slInk : Color.slLine, lineWidth: 1.5))
                        }
                        .foregroundStyle(Color.slInk)
                    }
                }
            }
        }
    }

    private var commentsBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("growth.comments.title")).font(.dm(14, .bold)).foregroundStyle(Color.slInk).padding(.top, 8)
            let list = store.comments(for: card.id)
            if list.isEmpty { Text(t("growth.comments.empty")).font(.dm(12.5)).foregroundStyle(Color.slInkMuted) }
            ForEach(list) { c in
                HStack(alignment: .top, spacing: 10) {
                    Text(c.initials ?? "?").font(.dm(10, .heavy)).foregroundStyle(.white).frame(width: 28, height: 28).background(Color(hex: c.color ?? "#0F6E6E"), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text((c.user == store.data?.team?.me ? t("growth.team.me") : c.name ?? "") + "  " + Fmt.relative(c.at)).font(.dm(12, .semibold)).foregroundStyle(Color.slInkMuted)
                        Text(c.text).font(.dm(14)).foregroundStyle(Color.slInk)
                    }
                }
            }
            HStack(alignment: .bottom) {
                TextField(t("growth.comments.placeholder"), text: $say, axis: .vertical).font(.dm(14)).padding(10).background(Color.slPaper, in: RoundedRectangle(cornerRadius: 12))
                Button { let text = say.trimmingCharacters(in: .whitespacesAndNewlines); guard !text.isEmpty else { return }; say = ""; Task { try? await store.comment(card.id, text) } } label: {
                    Image(systemName: "paperplane.fill").foregroundStyle(.white).frame(width: 40, height: 40).background(Color.slInk, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

struct GrowthStickySheet: View {
    @ObservedObject var store: GrowthStore
    let id: String
    var openCard: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var type = "note"
    @State private var working = false

    private var note: Sticky? { store.stickies.first { $0.id == id } }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Picker("", selection: $type) { ForEach(["note", "idea", "risk", "goal"], id: \.self) { Text(t("growth.notes." + $0)).tag($0) } }.pickerStyle(.segmented)
                    .disabled(["answer", "coach", "link", "image"].contains(note?.type ?? ""))
                TextEditor(text: $text).accessibilityIdentifier("note-text").font(.hand(24)).scrollContentBackground(.hidden).padding(12).frame(minHeight: 180)
                    .background(type == "risk" ? Color.slBadSoft : type == "idea" ? Color.slTint100 : type == "goal" ? Color.slGoodSoft : Color.slMarker.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                if !text.isEmpty, ["note", "idea", "goal", "risk"].contains(type) {
                    Button {
                        save()
                        working = true
                        Task {
                            if let n = store.stickies.first(where: { $0.id == id }), let newCard = await store.assist(sticky: n) { dismiss(); openCard(newCard) } else { dismiss() }
                            working = false
                        }
                    } label: { Label(type == "risk" ? t("growth.ai.lower") : t("growth.ai.toStep"), systemImage: "sparkles").frame(maxWidth: .infinity) }
                        .buttonStyle(SLButtonStyle(kind: type == "risk" ? .primary : .accent)).disabled(working)
                    if working { Label(t("growth.ai.working"), systemImage: "sparkles").font(.dm(13, .semibold)).foregroundStyle(Color.slAccent800) }
                }
                Spacer()
            }
            .padding(20)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(role: .destructive) { store.apply(store.engine.removeSticky(store.board, id: id)); dismiss() } label: { Image(systemName: "trash") } }
                ToolbarItem(placement: .topBarTrailing) { Button(t("ios.close")) { save(); dismiss() }.accessibilityIdentifier("note-close") }
            }
        }
        .onAppear { text = note?.text ?? ""; type = note?.type ?? "note" }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard let n = note, n.text != text || n.type != type else { return }
        store.apply(store.engine.editSticky(store.board, id: id) { $0.text = String(text.prefix(600)); $0.type = type })
    }
}

/// A page worth being on: why it matters, who to write to, the message the AI writes for it, where it stands.
struct ProspectSheet: View {
    @ObservedObject var store: GrowthStore
    let id: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var busy = ""
    @State private var note = ""
    @State private var failed: String?

    private var p: Prospect? { store.prospects.first { $0.id == id } }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let p { content(p).padding(20) }
            }
            .background(Color.white)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(t("ios.close")) { dismiss() }.accessibilityIdentifier("sheet-close") } }
        }
        .onAppear { note = p?.note ?? "" }
    }

    @ViewBuilder private func content(_ p: Prospect) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(p.host + " · " + t("growth.lists.kinds." + p.kind)).font(.dm(11, .semibold)).foregroundStyle(Color.slInkMuted).textCase(.uppercase)
                Text(p.shownTitle).font(.dm(19, .bold)).foregroundStyle(Color.slInk).lineLimit(3)
                if let u = URL(string: p.url) { Link(destination: u) { Label(t("growth.lists.open"), systemImage: "arrow.up.right").font(.dm(13, .semibold)) }.tint(Color.slAccent700) }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(t("growth.lists.why")).font(.dm(11, .semibold)).foregroundStyle(Color.slAccent800).textCase(.uppercase)
                Text(t("growth.lists.whyText", ["n": p.answers, "engines": p.engines.joined(separator: ", ")])).font(.dm(14)).foregroundStyle(Color.slInk)
                if !p.rivals.isEmpty { Text(t("growth.lists.names", ["rivals": p.rivals.joined(separator: ", ")])).font(.dm(13)).foregroundStyle(Color.slInkSoft) }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.slTint50, in: RoundedRectangle(cornerRadius: 16))
            if p.status == "listed" {
                VStack(alignment: .leading, spacing: 4) {
                    Label(t("growth.lists.listedTitle"), systemImage: "checkmark.seal.fill").font(.dm(14, .bold)).foregroundStyle(Color.slGood)
                    if let e = p.effect, (e.days ?? 0) >= 7 { Text(t("growth.lists.effect", ["before": e.before.map(String.init) ?? "—", "after": e.after.map(String.init) ?? "—", "days": e.days ?? 0])).font(.dm(13)).foregroundStyle(Color.slInk) }
                    else { Text(t("growth.lists.effectWait")).font(.dm(13)).foregroundStyle(Color.slInkSoft) }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.slGoodSoft, in: RoundedRectangle(cornerRadius: 16))
            }
            if p.followUp { Label(t("growth.lists.nudgeText"), systemImage: "alarm").font(.dm(13, .semibold)).foregroundStyle(Color.slBad).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.slBadSoft, in: RoundedRectangle(cornerRadius: 14)) }
            who(p)
            message(p)
            where_(p)
        }
    }

    private func who(_ p: Prospect) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(t("growth.lists.who")).font(.dm(14, .bold)).foregroundStyle(Color.slInk)
                Spacer()
                Button { busy = "read"; Task { await store.readProspect(id); busy = "" } } label: {
                    if busy == "read" { ProgressView() } else { Label(p.readAt != nil ? t("growth.lists.readAgain") : t("growth.lists.read"), systemImage: "arrow.clockwise").font(.dm(12.5, .semibold)) }
                }
                .padding(.horizontal, 10).padding(.vertical, 5).overlay(Capsule().stroke(Color.slLine)).foregroundStyle(Color.slInk).disabled(!busy.isEmpty).accessibilityIdentifier("prospect-read")
            }
            if let c = p.contact, p.hasContact {
                if let a = c.author { Label(a, systemImage: "person").font(.dm(14, .semibold)).foregroundStyle(Color.slInk) }
                ForEach(c.emails ?? [], id: \.self) { e in HStack { Label(e, systemImage: "envelope").font(.dm(13.5)).foregroundStyle(Color.slInk).lineLimit(1); Spacer(); CopyButton(text: e) } }
                if let tw = c.twitter, let u = URL(string: "https://x.com/" + tw.replacingOccurrences(of: "@", with: "")) { Link(destination: u) { Label(tw, systemImage: "at").font(.dm(13.5, .semibold)) }.tint(Color.slAccent700) }
                if let l = c.linkedin, let u = URL(string: l) { Link(destination: u) { Label("LinkedIn", systemImage: "briefcase").font(.dm(13.5, .semibold)) }.tint(Color.slAccent700) }
                if let f = c.form, let u = URL(string: f) { Link(destination: u) { Label(t("growth.lists.form"), systemImage: "doc.text").font(.dm(13.5, .semibold)) }.tint(Color.slAccent700) }
            } else {
                Text(p.readAt != nil ? t("growth.lists.cantRead") : t("growth.lists.readFirst")).font(.dm(13)).foregroundStyle(Color.slInkMuted)
            }
        }
    }

    private func message(_ p: Prospect) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(t("growth.lists.message")).font(.dm(14, .bold)).foregroundStyle(Color.slInk)
                Spacer()
                Button { write() } label: {
                    if busy == "pitch" { ProgressView().tint(.white) } else { Label(p.draft != nil ? t("growth.lists.rewrite") : t("growth.lists.write"), systemImage: "sparkles").font(.dm(12.5, .semibold)) }
                }
                .padding(.horizontal, 12).padding(.vertical, 6).background(Color.slInk, in: Capsule()).foregroundStyle(.white).disabled(!busy.isEmpty).accessibilityIdentifier("prospect-write")
            }
            if let d = p.draft {
                if let s = d.summary, !s.isEmpty { Text(s).font(.dm(13.5)).foregroundStyle(Color.slInkSoft) }
                if let m = d.email, let body = m.body {
                    if let sub = m.subject { DraftBox(title: t("growth.lists.subject"), text: sub) }
                    DraftBox(title: t("growth.lists.body"), text: body)
                    if let to = p.contact?.emails?.first, let u = mailto(to, m.subject ?? "", body) {
                        Button { openURL(u) } label: { Label(t("growth.lists.openMail"), systemImage: "paperplane").font(.dm(13, .semibold)) }.tint(Color.slAccent700)
                    }
                }
                if let r = d.reply, !r.isEmpty { DraftBox(title: t("growth.lists.reply"), text: r) }
                if let l = d.listing, !l.isEmpty { DraftBox(title: t("growth.lists.listing"), text: l) }
                ForEach(Array((d.steps ?? []).enumerated()), id: \.offset) { i, s in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(i + 1)").font(.dm(11, .heavy)).foregroundStyle(Color.slAccent800).frame(width: 22, height: 22).background(Color.slTint100, in: Circle())
                        Text(s).font(.dm(13.5)).foregroundStyle(Color.slInkSoft)
                    }
                }
            } else {
                Text(t("growth.lists.noMessage")).font(.dm(13)).foregroundStyle(Color.slInkSoft)
            }
            if let failed { Text(failed).font(.dm(12.5, .semibold)).foregroundStyle(Color.slBad) }
            Text(t("growth.lists.ownMail")).font(.dm(12)).foregroundStyle(Color.slInkMuted)
        }
    }

    private func where_(_ p: Prospect) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("growth.lists.where")).font(.dm(14, .bold)).foregroundStyle(Color.slInk)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(["todo", "sent", "replied", "listed", "declined"], id: \.self) { st in
                        Button { Task { await store.updateProspect(id, status: st) } } label: {
                            Text(t("growth.lists.st." + st)).font(.dm(13, .semibold)).padding(.horizontal, 12).padding(.vertical, 7)
                                .foregroundStyle(p.status == st ? .white : Color.slInk).background(p.status == st ? Color.slInk : Color.slPaper, in: Capsule())
                        }
                        .accessibilityIdentifier("prospect-st-" + st)
                    }
                }
            }
            if let s = p.sentAt, p.status != "todo" { Text(t("growth.lists.sentAt", ["when": Fmt.short(s)])).font(.dm(12)).foregroundStyle(Color.slInkMuted) }
            TextField(t("growth.lists.notePlaceholder"), text: $note, axis: .vertical).font(.dm(14)).padding(10).background(Color.slPaper, in: RoundedRectangle(cornerRadius: 12))
                .onSubmit { Task { await store.updateProspect(id, note: note) } }
            if note != (p.note ?? "") { Button(t("growth.panel.save")) { Task { await store.updateProspect(id, note: note) } }.font(.dm(13, .semibold)).tint(Color.slAccent700) }
            Text(t("growth.lists.watch")).font(.dm(12)).foregroundStyle(Color.slInkMuted)
        }
    }

    private func write() {
        busy = "pitch"; failed = nil
        Task {
            do { try await store.pitch(id) } catch { failed = (error as? APIError)?.errorDescription ?? t("growth.ai.failed") }
            busy = ""
        }
    }
    private func mailto(_ to: String, _ subject: String, _ body: String) -> URL? {
        var c = URLComponents(); c.scheme = "mailto"; c.path = to
        c.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        return c.url
    }
}
