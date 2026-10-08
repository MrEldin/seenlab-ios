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

    private var mark: Mark? { store.marks[card.id] }
    private var result: StepResult? { store.data?.results[card.id] }
    private var experiment: Experiment? { store.data?.experiments[card.id] }
    private var people: [Person] { store.data?.team?.people ?? [] }

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
