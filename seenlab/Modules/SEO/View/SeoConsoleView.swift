//
//  SeoConsoleView.swift
//  seenlab
//
//  Search Console (web: SearchConsolePanel): the connection, totals against the previous period, clicks and
//  impressions per day, then the searches almost on page 1, top searches and top pages. Connecting Google
//  happens on the web; picking the range (7, 28, 90 days) is just reading.
//

import SwiftUI
import Charts

struct SeoConsoleView: View {
    let google: SeoGoogle?
    let report: SeoSlot<SeoGscReport>
    let days: Int
    let setDays: (Int) -> Void
    let retry: () -> Void

    var body: some View {
        if google?.connected != true {
            notConnected
        } else {
            status
            SeoSlotView(slot: report, retry: retry) { r in
                if let r, !r.isEmpty {
                    SeoGscKpis(totals: r.totals, prev: r.prev)
                    SeoGscChart(series: r.series)
                    rowsCard(title: t("seo.gsc.opportunities"), subtitle: t("seo.gsc.opportunitiesSub"), head: t("seo.gsc.col.query"),
                             rows: r.opportunities ?? [], empty: t("seo.gsc.noOpportunities"), kb: "striking")
                    rowsCard(title: t("seo.gsc.queries"), head: t("seo.gsc.col.query"), rows: Array((r.queries ?? []).prefix(50)), showMove: true)
                    rowsCard(title: t("seo.gsc.pages"), head: t("seo.gsc.col.page"), rows: Array((r.pages ?? []).prefix(50)), isUrl: true)
                } else {
                    EmptyCard(icon: "chart.line.uptrend.xyaxis", title: t("seo.gsc.noData"), text: t("seo.gsc.noDataSub"))
                }
            }
        }
        SeoWebOnly()
    }

    // MARK: - Connection

    private var notConnected: some View {
        SLCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 28, weight: .light)).foregroundStyle(Color.slAccent600)
                CardTitle(title: t("seo.gsc.connectTitle"), subtitle: t("seo.gsc.connectSub"), kb: nil)
                if google?.configured != true {
                    Text(t("seo.gsc.notConfigured")).font(.dm(12)).foregroundStyle(Color.slInkSoft)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.slBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.top, 4)
                }
            }
        }
    }

    @Environment(\.channel) private var channel

    private var status: some View {
        SLCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.circle").font(.system(size: 18)).foregroundStyle(Color.slGood)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("seo.gsc.connected", ["email": google?.email ?? "Google"])).font(.dm(13.5, .medium)).foregroundStyle(Color.slInk)
                    if google?.syncJob?.isRunning == true {
                        Text(t("seo.gsc.syncing")).font(.dm(12)).foregroundStyle(Color.slInkMuted)
                    } else if let at = google?.lastSyncedAt {
                        Text(t("seo.gsc.synced", ["time": Fmt.relative(at)])).font(.dm(12)).foregroundStyle(Color.slInkMuted)
                    }
                    if let error = google?.error { Text(error).font(.dm(12)).foregroundStyle(Color.slBad).fixedSize(horizontal: false, vertical: true) }
                    if let site = google?.siteUrl {
                        (Text(t("seo.gsc.property") + ": ").foregroundStyle(Color.slInkMuted) + Text(site).foregroundStyle(Color.slInkSoft))
                            .font(.dm(12)).lineLimit(1).truncationMode(.middle)
                    }
                }
                Spacer(minLength: 0)
            }
            HStack {
                Picker("", selection: Binding(get: { days }, set: { setDays($0) })) {
                    ForEach([7, 28, 90], id: \.self) { Text("\($0)d").tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
                Spacer()
                Button { channel.kb("search-console") } label: {
                    Text(t("kb.how")).font(.dm(12.5, .semibold)).foregroundStyle(Color.slAccent700)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 14)
        }
    }

    // MARK: - Rows

    private func rowsCard(title: String, subtitle: String? = nil, head: String, rows: [SeoGscReport.Row], empty: String? = nil,
                          kb: String? = nil, showMove: Bool = false, isUrl: Bool = false) -> some View {
        SeoSection(title: title, subtitle: subtitle, kb: kb) {
            if rows.isEmpty {
                if let empty { SeoNote(text: empty) }
            } else {
                VStack(spacing: 0) {
                    RowDivider()
                    HStack {
                        Text(head)
                        Spacer()
                        Text(t("seo.gsc.col.position"))
                    }
                    .font(.dm(11, .semibold)).foregroundStyle(Color.slInkMuted)
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(Color.slPaper)
                    SeoRows(items: rows) { r in row(r, showMove: showMove, isUrl: isUrl) }
                }
            }
        }
    }

    private func row(_ r: SeoGscReport.Row, showMove: Bool, isUrl: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                if isUrl {
                    SeoLinkText(url: r.key, text: Fmt.path(r.key), color: .slInk)
                } else {
                    Text(r.key).font(.dm(13.5)).foregroundStyle(Color.slInk).lineLimit(2)
                }
                (Text(SeoFmt.num(r.clicks)).foregroundStyle(Color.slInk) + Text(" " + t("seo.gsc.col.clicks").lowercased() + " · ").foregroundStyle(Color.slInkMuted)
                 + Text(SeoFmt.num(r.impressions)).foregroundStyle(Color.slInkSoft) + Text(" " + t("seo.gsc.col.impressions").lowercased() + " · ").foregroundStyle(Color.slInkMuted)
                 + Text(t("seo.gsc.col.ctr") + " " + Fmt.pct(r.ctr, digits: 2)).foregroundStyle(Color.slInkSoft))
                    .font(.dm(11.5)).monospacedDigit().lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 2) {
                Text(r.position.map { Fmt.num($0) } ?? "—").font(.dm(14, .semibold)).foregroundStyle(Color.slInk).monospacedDigit()
                if showMove, let prev = r.prevPosition, let now = r.position {
                    Text(t("seo.gsc.moved", ["n": Fmt.num(prev)])).font(.dm(11)).monospacedDigit()
                        .foregroundStyle(prev > now ? Color.slGood : prev < now ? Color.slBad : Color.slInkFaint)
                }
            }
        }
    }
}

// MARK: - Totals

private struct SeoGscKpis: View {
    let totals: SeoGscReport.Totals?
    let prev: SeoGscReport.Totals?

    private struct Kpi { let label: String; let value: String; let delta: Double?; let deltaText: String; var invert = false }

    private func pct(_ a: Double?, _ b: Double?) -> Double? {
        guard let a, let b, b != 0 else { return nil }
        return ((a - b) / b * 100).rounded()
    }

    private var kpis: [Kpi] {
        let n = totals, p = prev
        let clicks = pct(n?.clicks, p?.clicks), impr = pct(n?.impressions, p?.impressions)
        let ctr: Double? = (p?.impressions ?? 0) != 0 ? (((n?.ctr ?? 0) - (p?.ctr ?? 0)) * 10).rounded() / 10 : nil
        let pos: Double? = n?.position.flatMap { a in p?.position.map { b in ((a - b) * 10).rounded() / 10 } }
        return [
            Kpi(label: t("seo.gsc.kpi.clicks"), value: SeoFmt.num(n?.clicks), delta: clicks, deltaText: Fmt.int(abs(clicks ?? 0)) + "%"),
            Kpi(label: t("seo.gsc.kpi.impressions"), value: SeoFmt.num(n?.impressions), delta: impr, deltaText: Fmt.int(abs(impr ?? 0)) + "%"),
            Kpi(label: t("seo.gsc.kpi.ctr"), value: Fmt.pct(n?.ctr, digits: 2), delta: ctr, deltaText: Fmt.num(abs(ctr ?? 0)) + " pp"),
            Kpi(label: t("seo.gsc.kpi.position"), value: n?.position.map { Fmt.num($0) } ?? "—", delta: pos, deltaText: Fmt.num(abs(pos ?? 0)), invert: true),
        ]
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(Array(kpis.enumerated()), id: \.offset) { _, k in
                SLCard(padding: 16) {
                    Text(k.label).font(.dm(12, .medium)).foregroundStyle(Color.slInkMuted).lineLimit(1).minimumScaleFactor(0.8)
                    Text(k.value).font(.dm(26, .semibold)).tracking(-0.5).foregroundStyle(Color.slInk).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6).padding(.top, 2)
                    if let d = k.delta {
                        let good = k.invert ? d < 0 : d > 0
                        Text((d > 0 ? "▲ " : d < 0 ? "▼ " : "") + k.deltaText).font(.dm(12, .semibold)).monospacedDigit()
                            .foregroundStyle(d == 0 ? Color.slInkMuted : good ? Color.slGood : Color.slBad).padding(.top, 2)
                    } else {
                        Text(" ").font(.dm(12)).padding(.top, 2)
                    }
                }
            }
        }
    }
}

// MARK: - Chart

private struct SeoGscChart: View {
    let series: SeoGscReport.Series?

    private struct Day: Identifiable { let id: Int; let date: Date; let clicks: Double; let impressions: Double }

    private var days: [Day] {
        let labels = series?.labels ?? []
        return labels.enumerated().compactMap { i, label in
            guard let date = Fmt.date(label) else { return nil }
            let c = (series?.clicks ?? []).indices.contains(i) ? (series?.clicks?[i] ?? 0) : 0
            let m = (series?.impressions ?? []).indices.contains(i) ? (series?.impressions?[i] ?? 0) : 0
            return Day(id: i, date: date, clicks: c, impressions: m)
        }
    }

    /// Impressions are drawn on the clicks scale and labelled on the trailing axis (the web's second axis).
    private var scale: Double {
        let maxC = days.map(\.clicks).max() ?? 0, maxI = days.map(\.impressions).max() ?? 0
        guard maxI > 0 else { return 1 }
        return maxC > 0 ? maxC / maxI : 1 / maxI
    }

    private let clicksColor = Color.slGood
    private let imprColor = Color(rgb: 201, 150, 46)

    var body: some View {
        let d = days, s = scale
        let maxI = d.map(\.impressions).max() ?? 0
        SLCard {
            CardTitle(title: t("seo.gsc.chart"))
            HStack(spacing: 14) {
                legend(t("seo.gsc.kpi.clicks"), clicksColor, bar: true)
                legend(t("seo.gsc.kpi.impressions"), imprColor, bar: false)
            }
            .padding(.top, 8)
            Chart {
                ForEach(d) { day in
                    BarMark(x: .value("day", day.date, unit: .day), y: .value(t("seo.gsc.kpi.clicks"), day.clicks))
                        .foregroundStyle(clicksColor.opacity(0.85))
                        .cornerRadius(2)
                }
                ForEach(d) { day in
                    LineMark(x: .value("day", day.date, unit: .day), y: .value(t("seo.gsc.kpi.impressions"), day.impressions * s))
                        .foregroundStyle(imprColor)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.monotone)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Color.slLine)
                    AxisValueLabel { if let v = value.as(Double.self) { Text(SeoFmt.num(v)).font(.dm(10)).foregroundStyle(Color.slInkMuted) } }
                }
                AxisMarks(position: .trailing, values: trailingTicks(maxI).map { $0 * s }) { value in
                    AxisValueLabel { if let v = value.as(Double.self) { Text(SeoFmt.num(v / s)).font(.dm(10)).foregroundStyle(imprColor) } }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: d.count <= 10 ? 2 : d.count <= 31 ? 7 : 21)) { value in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true).font(.dm(10)).foregroundStyle(Color.slInkMuted)
                }
            }
            .frame(height: 220)
            .padding(.top, 12)
        }
    }

    private func trailingTicks(_ max: Double) -> [Double] {
        guard max > 0 else { return [0] }
        let raw = max / 3
        let mag = pow(10, floor(log10(raw)))
        let step = [1, 2, 2.5, 5, 10].map { $0 * mag }.first { $0 >= raw } ?? raw
        return stride(from: 0, through: max, by: step).map { $0 }
    }

    private func legend(_ text: String, _ color: Color, bar: Bool) -> some View {
        HStack(spacing: 6) {
            if bar { RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10) }
            else { Capsule().fill(color).frame(width: 14, height: 3) }
            Text(text).font(.dm(11.5)).foregroundStyle(Color.slInkMuted)
        }
    }
}
