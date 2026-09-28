//
//  AioRivalsView.swift
//  seenlab
//
//  Rivals tab (web: RivalsPanel.vue): share of all product mentions (own row on the marker) and the daily
//  mention rate, all assistants together (solid) and per assistant (dashed).
//

import SwiftUI
import Charts

struct AioRivalsView: View {
    let data: AioOverview
    @Environment(\.channel) private var channel

    private var brands: [AioBrand] { data.brands ?? [] }
    private var maxShare: Double { max(1, brands.compactMap(\.share).max() ?? 1) }

    var body: some View {
        SLCard {
            CardTitle(title: t("aio.rivals.title"), subtitle: t("aio.rivals.subtitle"), kb: { channel.kb("numbers") })
            if brands.isEmpty {
                Text(t("aio.rivals.empty")).font(.dm(13)).foregroundStyle(Color.slInkMuted).padding(.top, 14)
            } else {
                VStack(alignment: .leading, spacing: 13) {
                    ForEach(Array(brands.enumerated()), id: \.offset) { _, b in bar(b) }
                }
                .padding(.top, 16)
            }
        }

        SLCard {
            CardTitle(title: t("aio.rivals.trend"), subtitle: t("aio.rivals.trendSub"))
            AioTrendChart(data: data).padding(.top, 14)
        }
    }

    private func bar(_ b: AioBrand) -> some View {
        let own = b.own == true
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(b.name).font(.dm(13.5, own ? .bold : .regular)).foregroundStyle(Color.slInk).lineLimit(1)
                if own {
                    Text(t("aio.rivals.you")).font(.dm(10, .bold)).foregroundStyle(Color.slInk)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Color.slMarker.opacity(0.8), in: Capsule())
                } else if b.competitor == true {
                    Text(t("aio.rivals.tracked")).font(.dm(10, .semibold)).foregroundStyle(Color.slInkMuted)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Color.slBg, in: Capsule())
                        .overlay(Capsule().stroke(Color.slLine, lineWidth: 1))
                }
                Spacer(minLength: 6)
                Text(Fmt.pct(b.share)).font(.dm(12.5, .semibold)).monospacedDigit().foregroundStyle(Color.slInk)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.slBg)
                    Capsule().fill(own ? Color.slMarker : Color.slAccent600.opacity(0.7))
                        .frame(width: max(geo.size.width * 0.02, geo.size.width * (b.share ?? 0) / maxShare))
                }
            }
            .frame(height: 8)
            let mentions = Int(b.mentions ?? 0)
            Text(t("aio.rivals.mentions", ["n": mentions], count: mentions) + (b.avgRank.map { " · " + t("aio.rivals.avg", ["n": Fmt.num($0, digits: 1)]) } ?? ""))
                .font(.dm(11.5)).monospacedDigit().foregroundStyle(Color.slInkMuted)
        }
    }
}

/// Mention rate per day (web: TrendChart in RivalsPanel).
private struct AioTrendChart: View {
    let data: AioOverview

    private struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let series: String
        let dashed: Bool
    }

    private var lines: [(key: String, label: String, color: Color, dashed: Bool)] {
        let engines = data.series?.engines?.values ?? [:]
        var out: [(String, String, Color, Bool)] = []
        if engines["all"] != nil { out.append(("all", t("aio.rivals.all"), Color.slAccent600, false)) }
        for e in data.enabledEngines where engines[e.key] != nil {
            out.append((e.key, e.name, AioEngineMark.chartColor(e.key), true))
        }
        return out
    }

    private var points: [Point] {
        let labels = data.series?.labels ?? []
        let engines = data.series?.engines?.values ?? [:]
        var out: [Point] = []
        for line in lines {
            let values = engines[line.key] ?? []
            for (i, label) in labels.enumerated() {
                guard let date = Fmt.date(label) else { continue }
                let v = i < values.count ? (values[i] ?? 0) : 0
                out.append(Point(date: date, value: v, series: line.label, dashed: line.dashed))
            }
        }
        return out
    }

    private var hasData: Bool {
        (data.series?.engines?.values ?? [:]).values.contains { $0.contains { $0 != nil } }
    }

    var body: some View {
        if !hasData || points.isEmpty {
            Text(t("aio.rivals.empty")).font(.dm(13)).foregroundStyle(Color.slInkMuted)
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(Color.slPaper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            let lines = self.lines
            Chart(points) { p in
                if !p.dashed {
                    AreaMark(x: .value("day", p.date, unit: .day), y: .value("rate", p.value), series: .value("series", p.series))
                        .foregroundStyle(LinearGradient(colors: [Color.slAccent600.opacity(0.18), Color.slAccent600.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                }
                LineMark(x: .value("day", p.date, unit: .day), y: .value("rate", p.value), series: .value("series", p.series))
                    .foregroundStyle(by: .value("series", p.series))
                    .lineStyle(StrokeStyle(lineWidth: p.dashed ? 1.6 : 2.2, lineCap: .round, dash: p.dashed ? [4, 3] : []))
                    .interpolationMethod(.monotone)
            }
            .chartForegroundStyleScale(domain: lines.map(\.label), range: lines.map(\.color))
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { v in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.slLine)
                    AxisValueLabel { if let n = v.as(Int.self) { Text("\(n)%").font(.dm(10)).foregroundStyle(Color.slInkFaint) } }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { v in
                    AxisValueLabel {
                        if let d = v.as(Date.self) { Text(d.formatted(.dateTime.day().month(.abbreviated))).font(.dm(10)).foregroundStyle(Color.slInkFaint) }
                    }
                }
            }
            .chartLegend(position: .bottom, alignment: .leading, spacing: 12)
            .frame(height: 230)
            .environment(\.locale, Locale(identifier: L10n.shared.locale == "sr" ? "sr-Latn" : L10n.shared.locale))
        }
    }
}
