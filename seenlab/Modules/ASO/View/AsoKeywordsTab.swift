//
//  AsoKeywordsTab.swift
//  seenlab
//
//  Ključne reči, as the web's AsoKeywords table: every tracked term with its rank, change, 30-day line
//  and traffic/difficulty. Tapping a term opens its rank history against the tracked competitors and
//  today's top 10.
//

import SwiftUI
import Charts

struct AsoKeywordsTab: View {
    @EnvironmentObject private var store: AsoStore
    @Environment(\.channel) private var channel
    @State private var filter = ""
    @AppStorage("aso.kw.sort") private var sort = AsoKeywordSort.opportunity.rawValue
    @State private var open: AsoKeyword?

    var body: some View {
        SLCard(padding: 0) {
            CardTitle(title: t("aso.kw.tableTitle", ["country": store.country.uppercased()]), subtitle: t("aso.kw.tableSubtitle"), kb: { channel.kb("keyword-strategy") })
                .padding([.horizontal, .top], 18)
            controls.padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 6)
            if rows.isEmpty {
                AsoInlineEmpty(title: t("aso.kw.empty"), hint: t("aso.kw.emptyHint"), icon: "number").padding(.bottom, 10)
            } else {
                VStack(spacing: 0) {
                    ForEach(rows) { k in
                        RowDivider()
                        Button { open = k } label: { AsoKeywordRow(keyword: k) }.buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(item: $open) { AsoKeywordSheet(keyword: $0).environmentObject(store) }
        AsoWebOnlyNote()
    }

    private var controls: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(Color.slInkFaint)
                TextField(t("aso.kw.filter"), text: $filter)
                    .font(.dm(13.5))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.slLine, lineWidth: 1))

            Menu {
                Picker("", selection: $sort) {
                    ForEach(AsoKeywordSort.allCases, id: \.rawValue) { Text($0.label).tag($0.rawValue) }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.arrow.down").font(.system(size: 11, weight: .semibold))
                    Text((AsoKeywordSort(rawValue: sort) ?? .opportunity).label).font(.dm(12.5, .medium)).lineLimit(1)
                }
                .foregroundStyle(Color.slInkSoft)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.slLine, lineWidth: 1))
            }
        }
    }

    private var rows: [AsoKeyword] {
        let q = filter.trimmingCharacters(in: .whitespaces).lowercased()
        let list = q.isEmpty ? store.keywords : store.keywords.filter { $0.term.lowercased().contains(q) }
        let pos: (AsoKeyword) -> Double = { $0.position ?? 999 }
        switch AsoKeywordSort(rawValue: sort) ?? .opportunity {
        case .position: return list.sorted { pos($0) < pos($1) }
        case .opportunity: return list.sorted { $0.opportunity > $1.opportunity }
        case .traffic: return list.sorted { ($0.traffic ?? 0) > ($1.traffic ?? 0) }
        case .difficulty: return list.sorted { ($0.difficulty ?? 101) < ($1.difficulty ?? 101) }
        case .term: return list.sorted { $0.term.localizedCompare($1.term) == .orderedAscending }
        }
    }
}

enum AsoKeywordSort: String, CaseIterable {
    case position, opportunity, traffic, difficulty, term

    var label: String {
        switch self {
        case .position: t("aso.kw.sortPosition")
        case .opportunity: t("aso.kw.sortOpportunity")
        case .traffic: t("aso.kw.sortTraffic")
        case .difficulty: t("aso.kw.sortDifficulty")
        case .term: "A–Z"
        }
    }
}

/// One keyword: term and result count, rank with change, the 30-day line, traffic and difficulty.
struct AsoKeywordRow: View {
    let keyword: AsoKeyword

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(keyword.term).font(.dm(14.5, .medium)).foregroundStyle(Color.slInk).lineLimit(2)
                    if let n = keyword.resultsCount, n > 0 {
                        Text(t("aso.kw.results", ["count": Fmt.int(n)], count: Int(n))).font(.dm(11.5)).foregroundStyle(Color.slInkMuted)
                    }
                }
                Spacer(minLength: 8)
                AsoPositionPill(position: keyword.position, delta: keyword.delta, size: 16)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.slInkFaint)
            }
            HStack(spacing: 12) {
                AsoSparkline(points: (keyword.series ?? []).compactMap(\.p)).frame(width: 92, height: 22)
                Spacer(minLength: 4)
                AsoScores(traffic: keyword.traffic, difficulty: keyword.difficulty)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Detail

/// A keyword's rank history (own app bold, competitors dashed), its numbers and today's top 10.
struct AsoKeywordSheet: View {
    let keyword: AsoKeyword
    @EnvironmentObject private var store: AsoStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.channel) private var channel
    @State private var history: AsoKeywordHistory?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        AsoSectionLabel(text: (keyword.country ?? store.country).uppercased() + " · " + t("aso.kw.historyTitle"))
                        Text(keyword.term).font(.dm(26, .bold)).tracking(-0.5).foregroundStyle(Color.slInk)
                    }
                    .padding(.horizontal, 4)

                    SLCard {
                        HStack(spacing: 8) {
                            AsoStatBox(label: t("aso.kw.colPosition"), value: AsoFmt.pos(keyword.position))
                            AsoStatBox(label: t("aso.kw.colBest"), value: AsoFmt.pos(keyword.best))
                        }
                        AsoScores(traffic: keyword.traffic, difficulty: keyword.difficulty).padding(.top, 12)
                        Text(t("aso.kw.trafficHint")).font(.dm(11.5)).foregroundStyle(Color.slInkMuted).padding(.top, 10).fixedSize(horizontal: false, vertical: true)
                        Text(t("aso.kw.difficultyHint")).font(.dm(11.5)).foregroundStyle(Color.slInkMuted).padding(.top, 2).fixedSize(horizontal: false, vertical: true)
                    }

                    SLCard {
                        CardTitle(title: t("aso.kw.historyTitle").prefix(1).uppercased() + t("aso.kw.historyTitle").dropFirst(), subtitle: t("aso.kw.colTrend"), kb: { channel.kb("how-search-works") })
                        if !loaded {
                            HStack { Spacer(); ProgressView().tint(Color.slAccent600); Spacer() }.frame(height: 220)
                        } else if let history, !lines(history).isEmpty {
                            AsoHistoryChart(lines: lines(history)).padding(.top, 14)
                        } else {
                            AsoInlineEmpty(title: t("aso.kw.historyEmpty"))
                        }
                    }

                    if let comps = keyword.competitors, !comps.isEmpty {
                        SLCard {
                            CardTitle(title: t("aso.kw.colCompetitors"))
                            RowList(items: comps.sorted { ($0.position ?? 999) < ($1.position ?? 999) }) { c in
                                HStack(spacing: 10) {
                                    RemoteIcon(url: c.iconUrl, size: 30)
                                    Text(c.name ?? "—").font(.dm(13.5)).foregroundStyle(Color.slInk).lineLimit(1)
                                    Spacer(minLength: 8)
                                    AsoPositionPill(position: c.position)
                                }
                                .padding(.vertical, 8)
                            }
                            .padding(.top, 8)
                        }
                    }

                    let top = history?.topApps ?? keyword.topApps ?? []
                    if !top.isEmpty {
                        SLCard {
                            CardTitle(title: t("aso.kw.top10Title"))
                            RowList(items: top) { a in AsoTopAppRow(app: a) }.padding(.top, 8)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.slBg)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t("ios.close")) { dismiss() }.font(.dm(15, .semibold)).tint(Color.slAccent700)
                }
            }
            .toolbarBackground(Color.slBg, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            history = await store.history(for: keyword)
            loaded = true
        }
    }

    private func lines(_ h: AsoKeywordHistory) -> [AsoHistoryLine] {
        let dates = (h.dates ?? []).map { Fmt.date($0) }
        return (h.series ?? []).compactMap { s in
            let pts = zip(dates, s.positions ?? []).compactMap { d, p -> (Date, Double)? in
                guard let d, let p else { return nil }
                return (d, p)
            }
            guard !pts.isEmpty else { return nil }
            return AsoHistoryLine(name: s.name ?? "—", own: s.isOwn == true, points: pts.map { AsoHistoryLine.Point(date: $0.0, position: $0.1) })
        }
    }
}

struct AsoHistoryLine: Identifiable {
    struct Point: Hashable { let date: Date; let position: Double }
    let name: String
    let own: Bool
    let points: [Point]
    var id: String { name }
}

/// Positions over time; #1 on top.
struct AsoHistoryChart: View {
    let lines: [AsoHistoryLine]

    private static let palette: [Color] = [Color(rgb: 166, 106, 10), Color(rgb: 198, 61, 47), Color(rgb: 84, 110, 170), Color(rgb: 140, 96, 160), Color(rgb: 87, 154, 154), Color(rgb: 122, 115, 104)]

    private var colors: [Color] {
        var i = 0
        return lines.map { l in
            if l.own { return .slAccent800 }
            defer { i += 1 }
            return AsoHistoryChart.palette[i % AsoHistoryChart.palette.count]
        }
    }

    var body: some View {
        Chart {
            ForEach(lines) { line in
                ForEach(line.points, id: \.self) { p in
                    LineMark(x: .value("date", p.date, unit: .day), y: .value("#", p.position))
                        .foregroundStyle(by: .value("app", line.name))
                        .lineStyle(line.own ? StrokeStyle(lineWidth: 3, lineCap: .round) : StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .interpolationMethod(.monotone)
                    if line.points.count == 1 || line.own {
                        PointMark(x: .value("date", p.date, unit: .day), y: .value("#", p.position))
                            .foregroundStyle(by: .value("app", line.name))
                            .symbolSize(line.own ? 22 : 12)
                    }
                }
            }
        }
        .chartForegroundStyleScale(domain: lines.map(\.name), range: colors)
        .chartYScale(domain: .automatic(includesZero: false, reversed: true))
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { v in
                AxisGridLine().foregroundStyle(Color.slLine)
                AxisValueLabel { if let n = v.as(Double.self) { Text("#" + Fmt.int(n)).font(.dm(10)).foregroundStyle(Color.slInkMuted) } }
            }
        }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in AxisValueLabel(format: .dateTime.day().month(.defaultDigits)).font(.dm(10)).foregroundStyle(Color.slInkMuted) } }
        .chartLegend(position: .bottom, alignment: .leading, spacing: 12)
        .frame(height: 260)
    }
}

/// One of today's top results: rank, icon, name, rating.
struct AsoTopAppRow: View {
    let app: AsoTopApp

    var body: some View {
        HStack(spacing: 10) {
            Text(app.position.map { Fmt.int($0) } ?? "—").font(.dm(12, .semibold)).monospacedDigit().foregroundStyle(Color.slInkMuted).frame(width: 22, alignment: .trailing)
            RemoteIcon(url: app.iconUrl, size: 32)
            Text(app.name ?? "—").font(.dm(13.5)).foregroundStyle(Color.slInk).lineLimit(1)
            Spacer(minLength: 8)
            Text("★ " + (app.rating.map { Fmt.num($0, digits: 2) } ?? "—") + " · " + Fmt.int(app.ratingCount ?? 0))
                .font(.dm(11.5)).monospacedDigit().foregroundStyle(Color.slInkMuted).lineLimit(1)
        }
        .padding(.vertical, 8)
    }
}
