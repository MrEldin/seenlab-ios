//
//  SeoAuditView.swift
//  seenlab
//
//  Site audit (web: AuditPanel, AuditTrend, LinksPanel): health score and its history, what changed since the
//  previous audit, sitemap and robots.txt, PageSpeed, issues by severity with the affected pages, the crawled
//  pages, and internal link suggestions.
//

import SwiftUI

struct SeoAuditView: View {
    let site: SeoSite
    let audit: SeoSlot<SeoAuditJob>
    let links: [SeoLink]
    let retry: () -> Void

    private var job: SeoAuditJob? { audit.value }
    /// The full report once loaded; the site's summary until then.
    private var report: SeoAuditReport? { (job?.isDone == true ? job?.result : nil) ?? site.audit?.summary }
    private var running: Bool { job?.isRunning ?? (site.audit?.job?.isRunning == true) }

    var body: some View {
        if site.audit == nil {
            never(failed: nil)
        } else if let report {
            if running { runningCard }
            if let history = job?.history, history.count > 1 { SeoAuditTrend(history: history, diff: job?.diff) }
            SeoScoreCard(report: report)
            if report.sitemap != nil || report.robots != nil { SeoCrawlCard(report: report) }
            SeoSpeedCard(pagespeed: report.pagespeed)
            SeoIssuesCard(issues: report.issues ?? [])
            if let pages = report.pages, !pages.isEmpty { SeoPagesCard(pages: pages) }
            SeoLinksCard(links: links)
            SeoWebOnly()
        } else if running {
            runningCard
        } else if audit.firstLoad || !audit.loaded && audit.error == nil {
            LoadingCard()
        } else if let error = audit.error, !audit.loaded {
            ErrorCard(message: error, retry: retry)
        } else {
            never(failed: job?.status == "failed" ? (job?.error ?? "") : nil)
        }
    }

    private var runningCard: some View {
        let done = job?.result?.progress.map { Fmt.int($0) } ?? "0"
        let total = job?.result?.total.map { Fmt.int($0) } ?? "…"
        return SLCard {
            HStack(spacing: 12) {
                ProgressView().tint(Color.slAccent600)
                Text(t("seo.audit.running", ["done": done, "total": total])).font(.dm(13.5, .medium)).foregroundStyle(Color.slInk)
            }
        }
    }

    private func never(failed: String?) -> some View {
        SLCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "flask").font(.system(size: 30, weight: .light)).foregroundStyle(Color.slAccent600)
                Text(t("seo.audit.never")).font(.dm(17, .semibold)).foregroundStyle(Color.slInk)
                Text(t("seo.audit.neverSub")).font(.dm(13.5)).foregroundStyle(Color.slInkSoft).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                if let failed { Text(t("seo.audit.failed", ["error": failed])).font(.dm(12)).foregroundStyle(Color.slBad) }
                Text(t("ios.webOnly")).font(.dm(12)).foregroundStyle(Color.slInkMuted).fixedSize(horizontal: false, vertical: true).padding(.top, 4)
            }
        }
    }
}

// MARK: - Score over time

private struct SeoAuditTrend: View {
    let history: [SeoAuditJob.Point]
    let diff: SeoAuditJob.Diff?

    var body: some View {
        SLCard {
            CardTitle(title: t("seo.trend.title"), subtitle: t("seo.trend.subtitle"))
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(history.enumerated()), id: \.offset) { i, h in
                    VStack(spacing: 4) {
                        Text(h.score.map { Fmt.int($0) } ?? "—").font(.dm(10)).foregroundStyle(Color.slInkMuted).monospacedDigit()
                        UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5)
                            .fill(i == history.count - 1 ? Color.slAccent600 : Color.slTint200)
                            .frame(height: max(4, CGFloat(h.score ?? 0) * 0.56))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 80, alignment: .bottom)
            .padding(.top, 14)

            VStack(alignment: .leading, spacing: 8) {
                if let diff {
                    let score = diff.score ?? 0
                    HStack(spacing: 6) {
                        Text(t("seo.trend.since")).font(.dm(14, .semibold)).foregroundStyle(Color.slInk)
                        Text((score > 0 ? "+" : "") + Fmt.int(score)).font(.dm(12, .semibold)).monospacedDigit()
                            .foregroundStyle(score > 0 ? Color.slGood : score < 0 ? Color.slBad : Color.slInkMuted)
                    }
                    chips(t("seo.trend.fixed"), diff.fixed ?? [], .good)
                    chips(t("seo.trend.new"), diff.new ?? [], .bad)
                    ForEach(diff.changed ?? [], id: \.code) { c in
                        let better = (c.to ?? 0) < (c.from ?? 0)
                        (Text(SeoFmt.issueTitle(c.code) + ": ").foregroundStyle(Color.slInkSoft)
                         + Text(Fmt.int(c.from) + " → ").foregroundStyle(Color.slInkSoft)
                         + Text(Fmt.int(c.to)).fontWeight(.bold).foregroundStyle(better ? Color.slGood : Color.slBad))
                            .font(.dm(12)).monospacedDigit()
                    }
                    if (diff.fixed ?? []).isEmpty && (diff.new ?? []).isEmpty && (diff.changed ?? []).isEmpty {
                        Text(t("seo.trend.same")).font(.dm(12)).foregroundStyle(Color.slInkMuted)
                    }
                } else {
                    Text(t("seo.trend.first")).font(.dm(12)).foregroundStyle(Color.slInkMuted)
                }
            }
            .padding(.top, 16)
        }
    }

    @ViewBuilder
    private func chips(_ label: String, _ codes: [String], _ tone: Tone) -> some View {
        if !codes.isEmpty {
            SeoFlow(spacing: 6) {
                Text(label).font(.dm(12)).foregroundStyle(Color.slInkMuted)
                ForEach(codes, id: \.self) { Chip(text: SeoFmt.issueTitle($0), tone: tone) }
            }
        }
    }
}

// MARK: - Score, crawl, speed

private struct SeoScoreCard: View {
    let report: SeoAuditReport
    @Environment(\.channel) private var channel

    var body: some View {
        SLCard {
            HStack(alignment: .center, spacing: 16) {
                ScoreRing(score: report.score, size: 84, label: t("seo.audit.score"))
                VStack(alignment: .leading, spacing: 3) {
                    if let url = report.url { Text(url).font(.dm(12)).foregroundStyle(Color.slInkMuted).lineLimit(1) }
                    let n = report.pagesCrawled ?? 0
                    Text(t("seo.audit.last", ["time": Fmt.relative(report.crawledAt), "n": n], count: n) + " · " + t("seo.audit.weekly"))
                        .font(.dm(13)).foregroundStyle(Color.slInkSoft).fixedSize(horizontal: false, vertical: true)
                }
            }
            SeoFlow(spacing: 6) {
                ForEach(["error", "warning", "notice"], id: \.self) { sev in
                    let n = report.count(sev)
                    Chip(text: t("seo.audit.severity." + sev, ["n": n], count: n), tone: SeoFmt.severityTone(sev))
                }
            }
            .padding(.top, 14)
            Button { channel.kb("audit") } label: {
                Text(t("kb.how")).font(.dm(12.5, .semibold)).foregroundStyle(Color.slAccent700)
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        }
    }
}

private struct SeoCrawlCard: View {
    let report: SeoAuditReport

    var body: some View {
        SLCard(padding: 0) {
            CardTitle(title: t("ios.seo.crawlTitle")).padding(18)
            VStack(spacing: 0) {
                RowDivider()
                row("Sitemap", found: report.sitemap?.found == true,
                    sub: report.sitemap?.found == true ? t("ios.seo.sitemapUrls", ["n": report.sitemap?.urls ?? 0]) : report.sitemap?.files?.first.map(SeoFmt.fullPath))
                if let robots = report.robots {
                    RowDivider().padding(.leading, 18)
                    row("robots.txt", found: robots.found == true, sub: nil)
                }
            }
        }
    }

    private func row(_ name: String, found: Bool, sub: String?) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 13.5, design: .monospaced)).foregroundStyle(Color.slInk)
                if let sub, !sub.isEmpty { Text(sub).font(.dm(12)).foregroundStyle(Color.slInkMuted).monospacedDigit().lineLimit(1) }
            }
            Spacer(minLength: 8)
            Chip(text: found ? t("seo.ai.llmsFound") : t("seo.ai.llmsMissing"), tone: found ? .good : .warn)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
    }
}

private struct SeoSpeedCard: View {
    let pagespeed: SeoPageSpeed?

    var body: some View {
        SLCard {
            CardTitle(title: t("seo.audit.speed"), subtitle: t("seo.audit.speedSub"))
            if let ps = pagespeed, ps.error == nil {
                HStack(spacing: 18) {
                    ScoreRing(score: ps.score, size: 72)
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 5) {
                        ForEach(metrics(ps), id: \.0) { m in
                            GridRow {
                                Text(m.0).font(.dm(12)).foregroundStyle(Color.slInkMuted)
                                Text(m.1).font(.dm(12.5, .semibold)).monospacedDigit().foregroundStyle(m.2).gridColumnAlignment(.trailing)
                            }
                        }
                    }
                }
                .padding(.top, 14)
                Text(ps.field != nil ? t("seo.audit.speedField") : t("seo.audit.speedLab")).font(.dm(11)).foregroundStyle(Color.slInkFaint).padding(.top, 8)
            } else if let error = pagespeed?.error {
                Text(error.range(of: "quota", options: .caseInsensitive) != nil ? t("seo.audit.speedQuota") : t("seo.audit.speedError", ["error": error]))
                    .font(.dm(12.5)).foregroundStyle(Color.slInkMuted).lineSpacing(2).fixedSize(horizontal: false, vertical: true).padding(.top, 10)
            }
        }
    }

    /// Core Web Vitals, coloured by Google's good / needs-improvement thresholds.
    private func metrics(_ ps: SeoPageSpeed) -> [(String, String, Color)] {
        let f = ps.field, l = ps.lab
        func tone(_ v: Double?, _ good: Double, _ bad: Double) -> Color {
            guard let v else { return .slInkFaint }
            return v <= good ? .slGood : v <= bad ? .slWarn : .slBad
        }
        let lcp = f?.lcpMs ?? l?.lcpMs
        let cls = f?.cls ?? l?.cls
        let second: (String, String, Color) = f?.inpMs != nil
            ? ("INP", SeoFmt.ms(f?.inpMs), tone(f?.inpMs, 200, 500))
            : ("TBT", SeoFmt.ms(l?.tbtMs), tone(l?.tbtMs, 200, 600))
        return [
            ("LCP", SeoFmt.ms(lcp), tone(lcp, 2500, 4000)),
            second,
            ("CLS", cls.map { String(format: "%.2f", $0) } ?? "—", tone(cls, 0.1, 0.25)),
            ("FCP", SeoFmt.ms(l?.fcpMs), tone(l?.fcpMs, 1800, 3000)),
        ]
    }
}

// MARK: - Issues and pages

private struct SeoIssuesCard: View {
    let issues: [SeoAuditReport.Issue]
    @State private var open: String?

    var body: some View {
        SLCard(padding: 0) {
            if issues.isEmpty {
                Text(t("seo.audit.clean")).font(.dm(14, .medium)).foregroundStyle(Color.slGood).padding(18)
            } else {
                RowList(items: issues) { issue in row(issue) }
            }
        }
    }

    private func row(_ i: SeoAuditReport.Issue) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy) { open = open == i.code ? nil : i.code }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Circle().fill(SeoFmt.severityColor(i.severity)).frame(width: 10, height: 10).padding(.top, 4)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(SeoFmt.issueTitle(i.code)).font(.dm(14, .semibold)).foregroundStyle(Color.slInk).multilineTextAlignment(.leading)
                        if let fix = SeoFmt.issueFix(i.code) {
                            Text(fix).font(.dm(12)).foregroundStyle(Color.slInkMuted).lineSpacing(2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 6)
                    let n = i.count ?? 0
                    Text(t("seo.audit.pagesAffected", ["n": n], count: n)).font(.dm(12, .semibold)).foregroundStyle(Color.slInkSoft).monospacedDigit().fixedSize()
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.slInkMuted)
                        .rotationEffect(.degrees(open == i.code ? 180 : 0)).padding(.top, 3)
                }
                .padding(.horizontal, 18).padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open == i.code, let pages = i.pages, !pages.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { _, p in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            SeoLinkText(url: p.url, text: SeoFmt.fullPath(p.url))
                            if let v = p.value, !v.isNull { Text(v.display).font(.dm(12)).foregroundStyle(Color.slInkMuted).monospacedDigit() }
                        }
                    }
                }
                .padding(.leading, 40).padding(.trailing, 18).padding(.bottom, 14).padding(.top, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.slPaper)
            }
        }
    }
}

private struct SeoPagesCard: View {
    let pages: [SeoAuditReport.Page]

    var body: some View {
        SeoSection(title: t("seo.audit.pagesTitle")) {
            SeoRows(items: pages) { p in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        SeoLinkText(url: p.url, text: SeoFmt.fullPath(p.url), color: .slInk, weight: .medium)
                        Text(p.title ?? "—").font(.dm(12)).foregroundStyle(Color.slInkSoft).lineLimit(1)
                        HStack(spacing: 8) {
                            let bad = (p.status ?? 0) >= 400 || p.status == nil
                            Text(p.status.map(String.init) ?? "—").fontWeight(bad ? .semibold : .regular).foregroundStyle(bad ? Color.slBad : Color.slInkMuted)
                            Text("\(p.words ?? 0) " + t("seo.audit.col.words").lowercased()).fontWeight(p.jsOnly == true ? .semibold : .regular)
                                .foregroundStyle(p.jsOnly == true ? Color.slBad : Color.slInkMuted)
                            Text(Fmt.int(p.ms) + " ms").foregroundStyle((p.ms ?? 0) > 2500 ? Color.slWarn : Color.slInkMuted)
                        }
                        .font(.dm(11.5)).monospacedDigit()
                    }
                    Spacer(minLength: 6)
                    badges(p.issues ?? [])
                }
            }
        }
    }

    @ViewBuilder
    private func badges(_ issues: [SeoAuditReport.PageIssue]) -> some View {
        if issues.isEmpty {
            Image(systemName: "checkmark.circle").font(.system(size: 14)).foregroundStyle(Color.slGood)
        } else {
            HStack(spacing: 4) {
                ForEach(["error", "warning", "notice"], id: \.self) { sev in
                    let n = issues.filter { $0.severity == sev }.count
                    if n > 0 {
                        Text("\(n)").font(.dm(11, .bold)).monospacedDigit().padding(.horizontal, 6).padding(.vertical, 1)
                            .foregroundStyle(SeoFmt.severityTone(sev).fg).background(SeoFmt.severityTone(sev).bg, in: Capsule())
                    }
                }
            }
        }
    }
}

// MARK: - Internal links

private struct SeoLinksCard: View {
    let links: [SeoLink]

    var body: some View {
        SeoSection(title: t("seo.links.title"), subtitle: t("seo.links.subtitle"), kb: "links") {
            if links.isEmpty {
                SeoNote(text: t("seo.links.empty"))
            } else {
                SeoRows(items: links) { l in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            SeoLinkText(url: l.url, text: SeoFmt.path(l.url), color: .slInk, weight: .medium)
                            Chip(text: (l.inbound ?? 0) > 0 ? t("seo.links.one") : t("seo.links.orphan"), tone: (l.inbound ?? 0) > 0 ? .warn : .bad)
                        }
                        if let from = l.from, !from.isEmpty {
                            SeoFlow(spacing: 4) {
                                Text(t("seo.links.from")).font(.dm(12)).foregroundStyle(Color.slInkMuted)
                                ForEach(Array(from.enumerated()), id: \.offset) { _, f in SeoLinkText(url: f.url, text: SeoFmt.path(f.url), size: 12) }
                            }
                        }
                        if let anchor = l.anchor, !anchor.isEmpty {
                            HStack(spacing: 8) {
                                (Text(t("seo.links.anchor") + ": ").foregroundStyle(Color.slInkSoft) + Text(Fmt.quote(anchor)).fontWeight(.semibold).foregroundStyle(Color.slInk))
                                    .font(.dm(12)).lineLimit(2)
                                Spacer(minLength: 0)
                                CopyButton(text: "<a href=\"\(l.url ?? "")\">\(anchor)</a>", label: t("seo.links.copyLink"))
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Shared bits

/// A page address that opens in Safari.
struct SeoLinkText: View {
    let url: String?
    let text: String
    var color: Color = .slAccent700
    var weight: Font.Weight = .regular
    var size: CGFloat = 13

    var body: some View {
        if let u = URL.seoWeb(url) {
            Link(destination: u) { Text(text).font(.dm(size, weight)).foregroundStyle(color).lineLimit(1).truncationMode(.middle) }
        } else {
            Text(text).font(.dm(size, weight)).foregroundStyle(color).lineLimit(1)
        }
    }
}

/// Wraps its children onto new lines (chips, lists of links).
struct SeoFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + CGFloat(max(0, rows.count - 1)) * spacing
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.items {
                let size = subviews[i].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                subviews[i].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
                x += min(size.width, bounds.width) + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var items: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(ProposedViewSize(width: width, height: nil))
            let w = min(size.width, width)
            if !rows[rows.count - 1].items.isEmpty && rows[rows.count - 1].width + spacing + w > width { rows.append(Row()) }
            var r = rows[rows.count - 1]
            r.width += (r.items.isEmpty ? 0 : spacing) + w
            r.height = max(r.height, size.height)
            r.items.append(i)
            rows[rows.count - 1] = r
        }
        return rows.filter { !$0.items.isEmpty }
    }
}
