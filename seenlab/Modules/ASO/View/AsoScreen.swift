//
//  AsoScreen.swift
//  seenlab
//
//  The ASO channel, as the web's Marketing page: the briefing header (what moved, next steps, the four
//  numbers), the tabs, and one tab at a time. A website project has no store listing, so it gets the
//  web's "attach an app" notice with links to SEO and AIO instead.
//

import SwiftUI

struct AsoScreen: View {
    @EnvironmentObject private var projects: ProjectStore
    @StateObject private var store = AsoStore()
    @AppStorage("aso.tab") private var tab = AsoTab.overview.rawValue

    var body: some View {
        if let project = projects.current, !project.hasStore {
            ChannelScroll { AsoAttachNotice(project: project) }
        } else if projects.currentId == nil {
            ChannelScroll { EmptyCard(title: t("ios.nothing")) }
        } else {
            dashboard
        }
    }

    private var dashboard: some View {
        ChannelScroll(refresh: { await store.load(project: projects.currentId, force: true) }) {
            if store.overview == nil {
                if let error = store.error, !store.loading {
                    ErrorCard(message: error) { Task { await store.load(project: projects.currentId, force: true) } }
                } else {
                    LoadingCard()
                }
            } else {
                // On a phone the tabs sit right under the headline; the next steps and the four numbers
                // (inside the header card on the web) open the overview tab.
                AsoHeader(go: { tab = $0.rawValue }, details: false)
                ChannelTabs(tabs: tabs, selection: $tab).padding(.horizontal, -16)
                if let error = store.error { AsoErrorBanner(text: error) }
                if tab == AsoTab.overview.rawValue { AsoHeader(go: { tab = $0.rawValue }, details: true) }
                content
            }
        }
        .environmentObject(store)
        .task(id: store.key(project: projects.currentId)) { await store.load(project: projects.currentId) }
        .onAppear { if AsoTab(rawValue: tab) == nil { tab = AsoTab.overview.rawValue } }
    }

    @ViewBuilder private var content: some View {
        switch AsoTab(rawValue: tab) ?? .overview {
        case .overview: AsoOverviewTab(go: { tab = $0.rawValue })
        case .keywords: AsoKeywordsTab()
        case .competitors: AsoCompetitorsTab()
        case .audit: AsoAuditTab()
        case .ai: AsoAiTab()
        case .reviews: AsoReviewsTab()
        }
    }

    private var tabs: [TabItem] {
        let ov = store.overview
        return [
            TabItem(key: AsoTab.overview.rawValue, label: t("aso.tabs.overview"), icon: "house"),
            TabItem(key: AsoTab.keywords.rawValue, label: t("aso.tabs.keywords"), icon: "magnifyingglass", count: ov?.keywordsCount),
            TabItem(key: AsoTab.competitors.rawValue, label: t("aso.tabs.competitors"), icon: "person.2", count: ov?.competitorsCount),
            TabItem(key: AsoTab.audit.rawValue, label: t("aso.tabs.audit"), icon: "checklist"),
            TabItem(key: AsoTab.ai.rawValue, label: t("aso.tabs.ai"), icon: "wand.and.stars"),
            TabItem(key: AsoTab.reviews.rawValue, label: t("ios.aso.reviews"), icon: "star.bubble"),
        ]
    }
}

enum AsoTab: String { case overview, keywords, competitors, audit, ai, reviews }

// MARK: - Header

/// The briefing: date · store · last measurement, the country, a headline from the biggest moves,
/// up to three next steps, and the four numbers behind it.
struct AsoHeader: View {
    let go: (AsoTab) -> Void
    /// false: the card with date, country and headline. true: the next steps and the four numbers.
    var details = false
    @EnvironmentObject private var store: AsoStore
    @EnvironmentObject private var projects: ProjectStore
    @Environment(\.channel) private var channel

    var body: some View {
        if details {
            VStack(alignment: .leading, spacing: 10) {
                if !actions.isEmpty {
                    VStack(spacing: 8) { ForEach(actions) { AsoActionCard(action: $0) } }
                }
                SLCard { KpiGrid(items: stats) }
            }
        } else {
            ChannelHeader(channel: "aso", status: status) {
                VStack(alignment: .leading, spacing: 16) {
                    AsoCountryMenu()
                    Text(headline)
                        .font(.dm(26, .bold))
                        .tracking(-0.6)
                        .lineSpacing(1)
                        .foregroundStyle(Color.slInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var status: String? {
        let name = projects.current?.storeName
        guard let track = store.overview?.lastTrack, let finished = track.finishedAt, !track.isRunning else { return name }
        return [name, t("aso.hdr.measured", ["time": Fmt.relative(finished)])].compactMap { $0 }.joined(separator: " · ")
    }

    // Headline: the two biggest moves since the last measurement, drops included.
    private var headline: AttributedString {
        let movers = (store.overview?.movers ?? []).filter { ($0.delta ?? 0) != 0 }
            .sorted { abs($0.delta ?? 0) > abs($1.delta ?? 0) }
            .prefix(2)
        guard !movers.isEmpty else {
            let ranked = store.uniqueKeywords.filter { $0.position != nil }.count
            return AsoText.slots(t("aso.hdr.lead"), ["ranked": AsoText.marked("\(ranked)"), "total": AttributedString("\(store.uniqueKeywords.count)")])
        }
        var out = AttributedString()
        for (i, m) in movers.enumerated() {
            if i > 0 { out += AttributedString(t("aso.hdr.news.and")) }
            let kind: String, what: String, tone: Color?
            if m.to == nil {
                kind = "dropped"; what = t("aso.hdr.news.droppedWhat"); tone = .slBad
            } else if m.from == nil {
                kind = "entered"; what = t("aso.hdr.news.enteredWhat", ["to": Fmt.int(m.to)]); tone = .slGood
            } else if (m.delta ?? 0) > 0 {
                kind = "up"; what = t("aso.hdr.news.upWhat", ["n": Int(m.delta ?? 0)]); tone = .slGood
            } else {
                kind = "down"; what = t("aso.hdr.news.downWhat", ["n": Int(-(m.delta ?? 0))]); tone = nil
            }
            var whatText = AttributedString(what)
            if let tone { whatText.swiftUI.foregroundColor = tone }
            out += AsoText.slots(t("aso.hdr.news." + kind), ["term": AsoText.marked(m.term), "what": whatText])
        }
        out += AttributedString(".")
        return out
    }

    // Next steps from the insights the backend computes (the web's ACTIONS map).
    private var actions: [AsoAction] {
        let all = (store.overview?.insights ?? []).compactMap { i -> AsoAction? in
            let target: AsoAction.Target
            let tone: Color
            switch i.key {
            case "few_ratings": target = .kb("conversion"); tone = .slWarn
            case "no_keyword_field": target = .tab(.audit); tone = .slWarn
            case "opportunity_uncovered": target = .tab(.ai); tone = .slAccent700
            case "opportunity_covered": target = .kb("search-ads"); tone = .slAccent700
            case "competitor_changed": target = .tab(.competitors); tone = .slInkMuted
            case "stale_release": target = .tab(.audit); tone = .slInkMuted
            default: return nil
            }
            let value: String
            if i.key == "competitor_changed" {
                value = (i.value?.string ?? "").split(separator: ",").map { AsoFmt.field($0.trimmingCharacters(in: .whitespaces)) }.joined(separator: ", ")
            } else {
                value = i.value?.string ?? ""
            }
            let p: [String: Any] = ["term": i.term ?? "", "value": value, "position": i.position.map { Fmt.int($0) } ?? "—"]
            let k = i.key == "few_ratings" && (i.value?.double ?? 0) == 0 ? "no_ratings" : i.key
            let base = "aso.hdr.act.\(k)."
            let go = self.go, channel = self.channel
            return AsoAction(id: i.key + (i.term ?? ""), tone: tone, kind: t(base + "kind"), title: t(base + "title", p), body: t(base + "body", p), cta: t(base + "cta")) {
                switch target {
                case .tab(let tab): go(tab)
                case .kb(let chapter): channel.kb(chapter)
                }
            }
        }
        return Array(all.prefix(3))
    }

    private var stats: [KpiTile] {
        let unique = store.uniqueKeywords
        let ranked = unique.filter { $0.position != nil }
        let best = ranked.min { ($0.position ?? 999) < ($1.position ?? 999) }
        let v = (store.overview?.visibility ?? []).map { $0.score ?? 0 }
        let now = v.last, prev = v.count > 1 ? v[v.count - 2] : nil
        let avg = store.overview?.avgPosition
        let dropped = prev != nil && now != nil && now! < prev!
        return [
            KpiTile(label: t("aso.hdr.inTop200"), value: "\(ranked.count)", sub: t("aso.hdr.ofN", ["n": unique.count])),
            KpiTile(label: t("aso.hdr.bestLabel"), value: AsoFmt.pos(best?.position), sub: best?.term),
            KpiTile(label: t("aso.hdr.avgLabel"), value: avg.map { "#" + Fmt.int($0) } ?? "—"),
            KpiTile(label: t("aso.hdr.visibility"), value: now.map { Fmt.int($0) } ?? "—",
                    sub: prev != nil && prev != now ? t("aso.hdr.was", ["n": Fmt.int(prev)]) : nil,
                    tone: dropped ? .bad : nil),
        ]
    }
}

/// One next-step card under the headline.
struct AsoAction: Identifiable {
    enum Target { case tab(AsoTab), kb(String) }
    let id: String
    let tone: Color
    let kind: String
    let title: String
    let body: String
    let cta: String
    let run: () -> Void
}

struct AsoActionCard: View {
    let action: AsoAction

    var body: some View {
        Button(action: action.run) {
            VStack(alignment: .leading, spacing: 4) {
                Text(action.kind.uppercased()).font(.dm(11, .semibold)).tracking(0.7).foregroundStyle(action.tone)
                Text(action.title).font(.dm(14.5, .semibold)).foregroundStyle(Color.slInk).fixedSize(horizontal: false, vertical: true)
                Text(action.body).font(.dm(12.5)).foregroundStyle(Color.slInkMuted).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                Text(action.cta + " →").font(.dm(12.5, .semibold)).foregroundStyle(Color.slAccent800).padding(.top, 4)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.slLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// The storefront picker: flag + name, a menu of the countries the overview lists.
struct AsoCountryMenu: View {
    @EnvironmentObject private var store: AsoStore

    var body: some View {
        Menu {
            Picker(t("ios.country"), selection: Binding(get: { store.country }, set: { store.setCountry($0) })) {
                ForEach(list, id: \.self) { c in
                    Text(AsoFmt.flag(c) + "  " + AsoFmt.countryName(c) + " · " + c.uppercased()).tag(c)
                }
            }
        } label: {
            HStack(spacing: 7) {
                Text(AsoFmt.flag(store.country)).font(.system(size: 15))
                Text(AsoFmt.countryName(store.country)).font(.dm(13, .medium)).foregroundStyle(Color.slInk).lineLimit(1)
                Text(store.country.uppercased()).font(.dm(11.5, .semibold)).foregroundStyle(Color.slInkMuted)
                if store.loading {
                    ProgressView().controlSize(.mini).tint(Color.slAccent600)
                } else {
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.slInk.opacity(0.6))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.slTint100, in: Capsule())
        }
        .accessibilityLabel(t("ios.country"))
    }

    private var list: [String] {
        let l = store.countries.isEmpty ? ["us", "gb", "de", "rs"] : store.countries
        return l.contains(store.country) ? l : [store.country] + l
    }
}

/// A failed refresh while older data stays on screen.
struct AsoErrorBanner: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(Color.slBad)
            Text(text).font(.dm(13)).foregroundStyle(Color.slBad).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.slBadSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Website project

/// A website has no store listing: the web's attach notice, with the channels that do work.
struct AsoAttachNotice: View {
    let project: Project
    @Environment(\.channel) private var channel

    var body: some View {
        SLCard(padding: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: t("sl.attach.eyebrow"))
                Text(t("sl.attach.title")).font(.dm(24, .bold)).tracking(-0.5).foregroundStyle(Color.slInk).fixedSize(horizontal: false, vertical: true)
                Text(t("sl.attach.sub", ["name": project.name])).font(.dm(14)).foregroundStyle(Color.slInkSoft).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button(t("sl.attach.seo")) { channel.open(.seo) }.buttonStyle(SLButtonStyle(kind: .primary))
                    Button(t("sl.attach.aio")) { channel.open(.aio) }.buttonStyle(SLButtonStyle(kind: .secondary))
                }
                .padding(.top, 6)
            }
        }
        AsoWebOnlyNote()
    }
}

// MARK: - Text with slots

enum AsoText {
    /// Fills `{name}` slots of a translated template with styled pieces (the web's i18n-t slots).
    static func slots(_ template: String, _ slots: [String: AttributedString]) -> AttributedString {
        var out = AttributedString()
        var rest = Substring(template)
        while let open = rest.firstIndex(of: "{"), let close = rest[open...].firstIndex(of: "}") {
            out += AttributedString(String(rest[..<open]))
            let name = String(rest[rest.index(after: open)..<close])
            out += slots[name] ?? AttributedString(String(rest[open...close]))
            rest = rest[rest.index(after: close)...]
        }
        out += AttributedString(String(rest))
        return out
    }

    /// A word with the yellow marker behind it.
    static func marked(_ s: String) -> AttributedString {
        var a = AttributedString(s)
        a.swiftUI.backgroundColor = Color.slMarker.opacity(0.85)
        return a
    }
}
