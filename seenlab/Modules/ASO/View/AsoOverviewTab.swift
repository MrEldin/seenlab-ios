//
//  AsoOverviewTab.swift
//  seenlab
//
//  Pregled, as the web's AsoOverview: today's insights, the headline numbers, the own listing, the
//  visibility trend, ratings velocity, the latest experiment, biggest movers and listing changes.
//

import SwiftUI
import Charts

struct AsoOverviewTab: View {
    let go: (AsoTab) -> Void
    @EnvironmentObject private var store: AsoStore
    @Environment(\.channel) private var channel

    var body: some View {
        if let ov = store.overview, let own = ov.own {
            if let insights = ov.insights, !insights.isEmpty { insightsCard(insights) }
            kpis(ov, own: own)
            listing(ov, own: own)
            visibility(ov)
            ratings(ov, own: own)
            experiment
            movers(ov)
            changes(ov)
        } else {
            EmptyCard(icon: "iphone", title: t("aso.overview.noOwnTitle"), text: t("aso.overview.noOwnHint"))
        }
        AsoWebOnlyNote()
    }

    // MARK: Insights

    private func insightsCard(_ insights: [AsoInsight]) -> some View {
        SLCard {
            CardTitle(title: t("aso.overview.insightsTitle"), subtitle: t("aso.overview.insightsSubtitle"), kb: { channel.kb("reading-numbers") })
            VStack(spacing: 8) {
                ForEach(Array(insights.enumerated()), id: \.offset) { _, i in AsoInsightRow(insight: i) }
            }
            .padding(.top, 14)
        }
    }

    // MARK: KPIs

    private func kpis(_ ov: AsoOverview, own: AsoApp) -> some View {
        SLCard {
            KpiGrid(items: [
                KpiTile(label: t("aso.overview.kpiKeywords"), value: Fmt.int(Double(ov.keywordsCount ?? 0)), sub: t("aso.overview.kpiKeywordsHint", ["ranked": Fmt.int(Double(ov.ranked ?? 0))])),
                KpiTile(label: t("aso.overview.kpiTop10"), value: Fmt.int(Double(ov.top10 ?? 0)), sub: t("aso.overview.kpiTop10Hint", ["top50": Fmt.int(Double(ov.top50 ?? 0))])),
                KpiTile(label: t("aso.overview.kpiAvg"), value: ov.avgPosition.map { "#" + Fmt.num($0, digits: 1) } ?? "—"),
                KpiTile(label: t("aso.overview.kpiRating"), value: (own.rating ?? 0) > 0 ? Fmt.num(own.rating, digits: 2) : "—",
                        sub: t("aso.overview.kpiRatingHint", ["count": Fmt.int(own.ratingCount ?? 0)], count: Int(own.ratingCount ?? 0))),
            ])
        }
    }

    // MARK: Listing

    private func listing(_ ov: AsoOverview, own: AsoApp) -> some View {
        SLCard {
            CardTitle(title: t("aso.overview.listingTitle"), subtitle: t("aso.overview.listingSubtitle"), kb: { channel.kb("audit") })
            HStack(alignment: .top, spacing: 14) {
                RemoteIcon(url: own.iconUrl, size: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text(own.name ?? "—").font(.dm(16, .semibold)).foregroundStyle(Color.slInk).fixedSize(horizontal: false, vertical: true)
                    Text((own.subtitle ?? "").isEmpty ? t("aso.overview.noSubtitle") : own.subtitle!)
                        .font(.dm(13.5)).foregroundStyle((own.subtitle ?? "").isEmpty ? Color.slBad : Color.slInkSoft)
                    Text([own.developer, own.version.map { "v" + $0.display }, own.price?.display].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.dm(12)).foregroundStyle(Color.slInkMuted).padding(.top, 3)
                    if let url = own.storeUrl.flatMap(URL.init(string:)) {
                        Link(destination: url) {
                            Label(store.isAndroid ? "Google Play" : "App Store", systemImage: "arrow.up.right").labelStyle(AsoTrailingIcon())
                                .font(.dm(12, .semibold)).foregroundStyle(Color.slAccent800)
                        }
                        .padding(.top, 3)
                    }
                }
            }
            .padding(.top, 14)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                AsoStatBox(label: t("aso.overview.titleChars"), value: "\((own.name ?? "").count)", sub: "/ 30")
                AsoStatBox(label: store.isAndroid ? t("aso.audit.fieldShortDescription") : t("aso.overview.subtitleChars"), value: "\((own.subtitle ?? "").count)", sub: store.isAndroid ? "/ 80" : "/ 30")
                AsoStatBox(label: t("aso.overview.lastUpdate"), value: own.versionReleasedAt.map { Fmt.relative($0) } ?? "—")
                AsoStatBox(label: t("aso.overview.competitors"), value: "\(ov.competitorsCount ?? 0)")
            }
            .padding(.top, 14)
        }
    }

    // MARK: Visibility

    private func visibility(_ ov: AsoOverview) -> some View {
        let points = (ov.visibility ?? []).compactMap { p -> (Date, Double)? in Fmt.date(p.date).map { ($0, p.score ?? 0) } }
        return SLCard {
            CardTitle(title: t("aso.overview.visTitle"), subtitle: t("aso.overview.visSubtitle"), kb: { channel.kb("reading-numbers") })
            if points.contains(where: { $0.1 > 0 }) {
                Chart {
                    ForEach(points, id: \.0) { d, v in
                        AreaMark(x: .value("date", d, unit: .day), y: .value(t("aso.overview.kpiVisibility"), v))
                            .foregroundStyle(LinearGradient(colors: [Color.slAccent500.opacity(0.25), Color.slAccent500.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("date", d, unit: .day), y: .value(t("aso.overview.kpiVisibility"), v))
                            .foregroundStyle(Color.slAccent600)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)
                    }
                }
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in AxisGridLine().foregroundStyle(Color.slLine); AxisValueLabel().font(.dm(10)).foregroundStyle(Color.slInkMuted) } }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in AxisValueLabel(format: .dateTime.day().month(.defaultDigits)).font(.dm(10)).foregroundStyle(Color.slInkMuted) } }
                .frame(height: 190)
                .padding(.top, 16)
            } else {
                AsoInlineEmpty(title: t("aso.overview.visEmpty"), hint: t("aso.overview.visEmptyHint"))
            }
        }
    }

    // MARK: Ratings

    private func ratings(_ ov: AsoOverview, own: AsoApp) -> some View {
        let rows = ov.ratings ?? []
        let points = rows.compactMap { r -> (Date, Double)? in Fmt.date(r.date).map { ($0, r.new ?? 0) } }
        let new30 = rows.reduce(0) { $0 + ($1.new ?? 0) }
        return SLCard {
            CardTitle(title: t("aso.overview.ratingsTitle"), subtitle: t("aso.overview.ratingsSubtitle"), kb: { channel.kb("conversion") })
            if rows.count > 1 {
                Chart {
                    ForEach(points, id: \.0) { d, v in
                        BarMark(x: .value("date", d, unit: .day), y: .value(t("aso.overview.ratingsNew"), v), width: .ratio(0.6))
                            .foregroundStyle(Color.slAccent500)
                            .cornerRadius(4)
                    }
                }
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in AxisGridLine().foregroundStyle(Color.slLine); AxisValueLabel().font(.dm(10)).foregroundStyle(Color.slInkMuted) } }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in AxisValueLabel(format: .dateTime.day().month(.defaultDigits)).font(.dm(10)).foregroundStyle(Color.slInkMuted) } }
                .frame(height: 140)
                .padding(.top, 16)
            } else {
                AsoInlineEmpty(title: t("aso.overview.ratingsEmpty"), hint: t("aso.overview.ratingsEmptyHint"), icon: "star")
            }
            HStack(spacing: 8) {
                AsoStatBox(label: t("aso.overview.ratingsTotal"), value: Fmt.int(own.ratingCount ?? 0))
                AsoStatBox(label: t("aso.overview.ratingsNew30"), value: "+" + Fmt.int(new30))
            }
            .padding(.top, 12)
        }
    }

    // MARK: Latest experiment

    private var experiment: some View {
        let last = store.listingChanges.first
        return SLCard {
            CardTitle(title: t("aso.chg.effectTitle"),
                      subtitle: last.map { t("aso.chg.effectSubtitle", ["date": AsoFmt.day($0.changedAt), "note": $0.note ?? ""]) } ?? t("aso.chg.effectNone"),
                      kb: { channel.kb("weekly-routine") })
            Group {
                if let last, let effect = last.effect {
                    if effect.ready == true, let before = effect.before, let after = effect.after {
                        HStack(spacing: 8) {
                            AsoEffectTile(label: t("aso.overview.kpiAvg"), before: before.avgPosition, after: after.avgPosition, lowerBetter: true, pos: true)
                            AsoEffectTile(label: t("aso.overview.kpiKeywords"), before: before.ranked, after: after.ranked)
                            AsoEffectTile(label: t("aso.overview.kpiVisibility"), before: before.visibility, after: after.visibility)
                        }
                    } else {
                        Text(t("aso.chg.effectWaiting", ["days": effect.daysAfter ?? 0]))
                            .font(.dm(12.5)).foregroundStyle(Color.slInkSoft).lineSpacing(2)
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.slTint50, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    if let per = effect.perKeyword, !per.isEmpty {
                        RowList(items: Array(per.prefix(6))) { k in
                            HStack {
                                Text(k.term).font(.dm(13.5)).foregroundStyle(Color.slInk).lineLimit(1)
                                Spacer(minLength: 8)
                                AsoFromTo(from: k.before, to: k.after)
                                if let d = k.delta, d != 0 {
                                    Text((d > 0 ? "▲" : "▼") + Fmt.num(abs(d), digits: 1)).font(.dm(11.5, .semibold)).monospacedDigit()
                                        .foregroundStyle(d > 0 ? Color.slAccent800 : Color.slBad)
                                }
                            }
                            .padding(.vertical, 7)
                        }
                        .padding(.top, 6)
                    }
                } else {
                    Text(t("aso.chg.effectHint")).font(.dm(13)).foregroundStyle(Color.slInkMuted).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 12)
        }
    }

    // MARK: Movers

    private func movers(_ ov: AsoOverview) -> some View {
        SLCard {
            CardTitle(title: t("aso.overview.moversTitle"), subtitle: t("aso.overview.moversSubtitle"))
            if let movers = ov.movers, !movers.isEmpty {
                RowList(items: movers) { m in
                    HStack(spacing: 10) {
                        Text(m.term).font(.dm(14, .medium)).foregroundStyle(Color.slInk).lineLimit(1)
                        Spacer(minLength: 8)
                        AsoFromTo(from: m.from, to: m.to)
                        let d = m.delta ?? 0
                        Text((d > 0 ? "▲ " : "▼ ") + Fmt.int(min(200, abs(d))))
                            .font(.dm(11, .semibold)).monospacedDigit()
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .foregroundStyle(d > 0 ? Color.slGood : Color.slBad)
                            .background(d > 0 ? Color.slGoodSoft : Color.slBadSoft, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .padding(.vertical, 10)
                }
                .padding(.top, 8)
            } else {
                AsoInlineEmpty(title: t("aso.overview.moversEmpty"), hint: t("aso.overview.moversEmptyHint"), icon: "arrow.up.arrow.down")
            }
        }
    }

    // MARK: Listing changes

    private func changes(_ ov: AsoOverview) -> some View {
        SLCard {
            CardTitle(title: t("aso.overview.changesTitle"), subtitle: t("aso.overview.changesSubtitle"), kb: { channel.kb("competitors") })
            if let changes = ov.recentChanges, !changes.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(changes.enumerated()), id: \.offset) { _, c in AsoChangeBox(change: c) }
                }
                .padding(.top, 14)
            } else {
                AsoInlineEmpty(title: t("aso.overview.changesEmpty"), hint: t("aso.overview.changesEmptyHint"), icon: "bell")
            }
        }
    }
}

// MARK: - Pieces

/// One insight, tinted by its level like the web.
struct AsoInsightRow: View {
    let insight: AsoInsight

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.system(size: 14, weight: .medium)).padding(.top, 1)
            Text(text).font(.dm(13.5)).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(fg)
        .padding(12)
        .background(bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(border, lineWidth: 1))
    }

    private var text: String {
        let value: String
        if insight.key == "competitor_changed" {
            value = (insight.value?.string ?? "").split(separator: ",").map { AsoFmt.field($0.trimmingCharacters(in: .whitespaces)) }.joined(separator: ", ")
        } else {
            value = insight.value?.string ?? ""
        }
        return t("aso.overview.insights.\(insight.key)", ["term": insight.term ?? "", "value": value, "position": insight.position.map { Fmt.int($0) } ?? "—"])
    }

    private var icon: String {
        switch insight.level { case "warn": "exclamationmark.triangle"; case "opportunity": "scope"; case "good": "arrow.up"; default: "info.circle" }
    }
    private var fg: Color {
        switch insight.level { case "warn": .slBad; case "opportunity": .slAccent900; case "good": .slInk; default: .slInkSoft }
    }
    private var bg: Color {
        switch insight.level { case "warn": .slBadSoft; case "opportunity": .slTint50; default: .white }
    }
    private var border: Color {
        switch insight.level { case "warn": .slBadSoft; case "opportunity", "good": .slTint200; default: .slLine }
    }
}

/// "#14 → #9": before and after a move.
struct AsoFromTo: View {
    let from: Double?
    let to: Double?

    var body: some View {
        (Text(AsoFmt.pos(from)).foregroundStyle(Color.slInkMuted)
         + Text(" → ").foregroundStyle(Color.slInkMuted)
         + Text(AsoFmt.pos(to)).fontWeight(.semibold).foregroundStyle(Color.slInk))
            .font(.dm(12)).monospacedDigit()
    }
}

/// Before → after of one experiment metric, with the change coloured by whether it helped.
struct AsoEffectTile: View {
    let label: String
    let before: Double?
    let after: Double?
    var lowerBetter = false
    var pos = false

    var body: some View {
        let d: Double? = (before != nil && after != nil) ? ((lowerBetter ? before! - after! : after! - before!) * 10).rounded() / 10 : nil
        VStack(spacing: 3) {
            Text(label).font(.dm(11)).foregroundStyle(Color.slInkMuted).lineLimit(1).minimumScaleFactor(0.8)
            (Text(fmt(before)).foregroundStyle(Color.slInkSoft) + Text(" → ").foregroundStyle(Color.slInkMuted) + Text(fmt(after)).fontWeight(.semibold).foregroundStyle(Color.slInk))
                .font(.dm(13)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
            Text(d.map { ($0 >= 0 ? "+" : "") + Fmt.num($0, digits: 1) } ?? "—")
                .font(.dm(12, .semibold)).monospacedDigit()
                .foregroundStyle((d ?? 0) >= 0 ? Color.slAccent800 : Color.slBad)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10).padding(.horizontal, 6)
        .background(Color.slTint50, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func fmt(_ v: Double?) -> String {
        guard let v else { return "—" }
        return pos ? "#" + Fmt.num(v, digits: 1) : Fmt.num(v, digits: 1)
    }
}

/// A listing change the snapshot noticed: app, date and what changed.
struct AsoChangeBox: View {
    let change: AsoRecentChange

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(change.app ?? "—").font(.dm(13.5, .medium)).foregroundStyle(Color.slInk).lineLimit(1)
                if change.isOwn == true { AsoYouTag() }
                Spacer(minLength: 8)
                Text(AsoFmt.day(change.date)).font(.dm(11.5)).foregroundStyle(Color.slInkMuted)
            }
            ForEach(Array((change.changes ?? []).enumerated()), id: \.offset) { _, ch in AsoFieldChangeLine(change: ch) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.slTint50.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.slLine, lineWidth: 1))
    }
}

/// "SUBTITLE: old (struck) new".
struct AsoFieldChangeLine: View {
    let change: AsoFieldChange

    var body: some View {
        let from = change.from.flatMap { $0.isNull ? nil : $0.display }
        let to = change.to.flatMap { $0.isNull ? nil : $0.display }
        var line = Text(AsoFmt.field(change.field).uppercased() + ": ").font(.dm(11.5, .semibold)).foregroundStyle(Color.slInkMuted)
        if from == nil && to == nil {
            line = line + Text(t("aso.overview.descriptionChanged")).foregroundStyle(Color.slInkSoft)
        } else {
            if let from { line = line + Text(from).strikethrough().foregroundStyle(Color.slInkMuted) + Text(" ") }
            if let to { line = line + Text(to).fontWeight(.medium).foregroundStyle(Color.slInk) }
        }
        return line.font(.dm(12)).fixedSize(horizontal: false, vertical: true)
    }
}

/// Label with the icon after the title ("App Store ↗").
struct AsoTrailingIcon: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) { configuration.title; configuration.icon.imageScale(.small) }
    }
}
