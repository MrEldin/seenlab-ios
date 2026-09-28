//
//  SeoRankView.swift
//  seenlab
//
//  Google rankings (web: RankPanel): tracked keywords with position, change, the 30-day line, AI Overview
//  and who is on top; the sites that outrank you; and local (Google Maps) positions.
//

import SwiftUI

struct SeoRankView: View {
    let data: SeoRankData?

    private let depth = 20

    var body: some View {
        let serp = data?.sources?.serp == true
        if let data, !serp {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle").font(.system(size: 14)).foregroundStyle(Color.slAccent700).padding(.top, 1)
                Text(data.sources?.gsc == true ? t("seo.rank.gscOnly") : t("seo.rank.noSource"))
                    .font(.dm(12.5)).foregroundStyle(Color.slInkSoft).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.slLine, lineWidth: 1))
        }

        organicCard
        competitorsCard(serp: serp)
        localCard(serp: serp)
        SeoWebOnly()
    }

    // MARK: - Organic

    private var organic: [SeoKeyword] { data?.organic ?? [] }

    private var organicCard: some View {
        SeoSection(title: t("seo.rank.title"), subtitle: t("seo.rank.subtitle"), kb: "rankings") {
            VStack(alignment: .trailing, spacing: 6) {
                if data?.job?.isRunning == true { Chip(text: t("seo.rank.tracking"), tone: .accent, icon: "arrow.triangle.2.circlepath") }
                if let limit = data?.limits?.organic {
                    Text("\(organic.count) / \(limit)").font(.dm(12)).foregroundStyle(Color.slInkMuted).monospacedDigit()
                }
            }
        } content: {
            if organic.isEmpty {
                SeoNote(text: t("seo.rank.empty"))
            } else {
                SeoRows(items: organic) { k in keywordRow(k) }
            }
        }
    }

    private func keywordRow(_ k: SeoKeyword) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    (Text(k.term ?? "").font(.dm(14, .medium)).foregroundStyle(Color.slInk)
                     + Text("  " + (k.country ?? "").uppercased()).font(.dm(11)).foregroundStyle(Color.slInkFaint))
                    if let url = k.url { SeoLinkText(url: url, text: SeoFmt.path(url), size: 11.5) }
                    if k.source == "gsc" { Text(t("seo.rank.fromGsc")).font(.dm(11)).foregroundStyle(Color.slInkFaint) }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    position(k, notFound: t("seo.rank.outside", ["n": depth]))
                    DeltaText(delta: k.delta)
                }
            }
            HStack(spacing: 10) {
                SeoSpark(series: k.series ?? [])
                if k.aiOverview == true {
                    Chip(text: k.aiOverviewOwn == true ? t("seo.rank.aioCites") : t("seo.rank.aioNot"), tone: k.aiOverviewOwn == true ? .good : .warn)
                }
                Spacer(minLength: 0)
            }
            if let top = k.top, !top.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(top.prefix(3).enumerated()), id: \.offset) { _, r in
                        (Text("\(r.position ?? 0). ").foregroundStyle(Color.slInkFaint) + Text(r.domain ?? r.title ?? "").foregroundStyle(Color.slInkSoft))
                            .font(.dm(11.5)).monospacedDigit().lineLimit(1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func position(_ k: SeoKeyword, notFound: String) -> some View {
        if let p = k.position {
            Text(Fmt.pos(p)).font(.dm(16, .bold)).foregroundStyle(Color.slInk).monospacedDigit()
        } else if k.capturedOn != nil {
            Text(notFound).font(.dm(12)).foregroundStyle(Color.slInkFaint)
        } else {
            Text(t("seo.rank.pending")).font(.dm(12)).foregroundStyle(Color.slInkFaint)
        }
    }

    // MARK: - Competitors

    private func competitorsCard(serp: Bool) -> some View {
        SeoSection(title: t("seo.rank.competitors"), subtitle: t("seo.rank.competitorsSub")) {
            if let list = data?.competitors, !list.isEmpty {
                SeoRows(items: list) { c in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            SeoLinkText(url: "https://" + c.domain, text: c.domain, color: .slInk, weight: .medium, size: 13.5)
                            let n = c.keywords ?? 0
                            Text(t("seo.rank.inKeywords", ["n": n], count: n)).font(.dm(12)).foregroundStyle(Color.slInkMuted)
                        }
                        Spacer(minLength: 8)
                        Text("⌀ " + Fmt.pos(c.avgPosition)).font(.dm(12)).foregroundStyle(Color.slInkSoft).monospacedDigit()
                        let ahead = c.ahead ?? 0
                        Text(t("seo.rank.ahead", ["n": ahead])).font(.dm(12, .semibold)).monospacedDigit()
                            .foregroundStyle(ahead > 0 ? Color.slBad : Color.slInkFaint)
                            .frame(minWidth: 56, alignment: .trailing)
                    }
                }
            } else {
                SeoNote(text: serp ? t("seo.rank.noCompetitors") : t("seo.rank.competitorsNeedSerp"))
            }
        }
    }

    // MARK: - Local

    private func localCard(serp: Bool) -> some View {
        let local = data?.local ?? []
        return SeoSection(title: t("seo.local.title"), subtitle: t("seo.local.subtitle"), kb: "local") {
            if let limit = data?.limits?.local, serp {
                Text("\(local.count) / \(limit)").font(.dm(12)).foregroundStyle(Color.slInkMuted).monospacedDigit()
            }
        } content: {
            if !serp {
                SeoNote(text: t("seo.local.needsSerp"))
            } else if !local.isEmpty {
                SeoRows(items: local) { k in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text([k.term, k.location].compactMap { $0 }.joined(separator: " · ")).font(.dm(14, .medium)).foregroundStyle(Color.slInk)
                            ForEach(Array((k.top ?? []).enumerated()), id: \.offset) { _, r in
                                (Text("\(r.position ?? 0). ").foregroundStyle(Color.slInkFaint)
                                 + Text(r.title ?? "").foregroundStyle(Color.slInkSoft)
                                 + Text(r.rating.map { " · ★ \(Fmt.num($0)) (\(Fmt.int(Double(r.reviews ?? 0))))" } ?? "").foregroundStyle(Color.slInkFaint))
                                    .font(.dm(11.5)).monospacedDigit().lineLimit(1)
                            }
                        }
                        Spacer(minLength: 8)
                        position(k, notFound: t("seo.local.notFound"))
                    }
                }
            }
        }
    }
}
