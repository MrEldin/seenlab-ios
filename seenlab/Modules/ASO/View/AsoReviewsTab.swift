//
//  AsoReviewsTab.swift
//  seenlab
//
//  Recenzije, as the web's AsoReviews: for every tracked app the star distribution, average, share of
//  1–2★ reviews, the freshest complaints and praise — then the latest AI review analysis, when there is one.
//

import SwiftUI

struct AsoReviewsTab: View {
    @EnvironmentObject private var store: AsoStore
    @Environment(\.channel) private var channel

    var body: some View {
        SLCard {
            CardTitle(title: t("aso.rev.title"), subtitle: t("aso.rev.subtitle"), kb: { channel.kb("conversion") })
        }
        if store.reviews.isEmpty || store.reviews.allSatisfy({ ($0.total ?? 0) == 0 }) {
            EmptyCard(icon: "star.bubble", title: t("aso.rev.empty"), text: t("aso.rev.emptyHint"))
        } else {
            ForEach(store.reviews) { AsoReviewCard(summary: $0) }
        }
        if let job = store.reviewsInsights, job.isDone, let result = job.result, let ins = result.insights, !ins.isEmpty {
            insights(result, ins)
        }
        AsoWebOnlyNote()
    }

    private func insights(_ r: AsoReviewsInsightsResult, _ ins: AsoReviewsInsights) -> some View {
        SLCard {
            CardTitle(eyebrow: t("aso.rev.analyze"), title: t("aso.rev.insightsTitle"),
                      subtitle: t("aso.rev.insightsSubtitle", ["count": Fmt.int(r.reviewsUsed ?? 0), "model": r.ai?.model ?? "—", "time": Fmt.relative(r.generatedAt)], count: Int(r.reviewsUsed ?? 0)))
            VStack(alignment: .leading, spacing: 18) {
                if let s = ins.marketSummary, !s.isEmpty {
                    Text(s).font(.dm(14)).foregroundStyle(Color.slInk).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.slTint50, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                if !ins.unmetNeeds.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        AsoSectionLabel(text: t("aso.rev.unmet"))
                        ForEach(Array(ins.unmetNeeds.enumerated()), id: \.offset) { _, u in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(u.need ?? "").font(.dm(14, .semibold)).foregroundStyle(Color.slInk).fixedSize(horizontal: false, vertical: true)
                                if let e = u.evidence, !e.isEmpty { Text(e).font(.dm(12)).foregroundStyle(Color.slInkMuted).fixedSize(horizontal: false, vertical: true) }
                                if let w = u.howYouCanWin, !w.isEmpty { Text("→ " + w).font(.dm(12.5)).foregroundStyle(Color.slAccent900).lineSpacing(2).fixedSize(horizontal: false, vertical: true).padding(.top, 2) }
                            }
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.slLine, lineWidth: 1))
                        }
                    }
                }
                if !ins.listingWords.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        AsoSectionLabel(text: t("aso.rev.words"))
                        AsoFlow(spacing: 6) { ForEach(ins.listingWords, id: \.self) { AsoWordChip(text: $0.word, fg: .slAccent900) } }
                    }
                }
                if !ins.objectionsToPreempt.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        AsoSectionLabel(text: t("aso.rev.objections"))
                        ForEach(Array(ins.objectionsToPreempt.enumerated()), id: \.offset) { _, o in AsoBullet(text: o) }
                    }
                }
                if !ins.featureIdeas.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        AsoSectionLabel(text: t("aso.rev.ideas"))
                        ForEach(Array(ins.featureIdeas.enumerated()), id: \.offset) { _, f in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(f.idea ?? "").font(.dm(13.5, .medium)).foregroundStyle(Color.slInk).fixedSize(horizontal: false, vertical: true)
                                    if let e = f.effort, !e.isEmpty { Chip(text: e.uppercased()) }
                                }
                                if let why = f.why, !why.isEmpty { Text(why).font(.dm(12)).foregroundStyle(Color.slInkSoft).fixedSize(horizontal: false, vertical: true) }
                            }
                        }
                    }
                }
                if let notes = ins.ownAppNotes, !notes.isEmpty {
                    Text(notes).font(.dm(13.5)).foregroundStyle(Color.slAccent900).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.slTint50, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.slTint200, lineWidth: 1))
                }
            }
            .padding(.top, 14)
        }
    }
}

/// One app's reviews: distribution 5★ → 1★, complaints and praise.
struct AsoReviewCard: View {
    let summary: AsoReviewSummary

    var body: some View {
        let total = summary.total ?? 0
        let dist = summary.distribution ?? []
        SLCard {
            HStack(spacing: 12) {
                RemoteIcon(url: summary.iconUrl, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(summary.name ?? "—").font(.dm(14.5, .semibold)).foregroundStyle(Color.slInk).lineLimit(1)
                        if summary.isOwn == true { AsoYouTag() }
                    }
                    Text(t("aso.rev.meta", ["total": Fmt.int(Double(total)), "avg": summary.avg.map { Fmt.num($0, digits: 2) } ?? "—", "recent": Fmt.int(Double(summary.last30d ?? 0))], count: total))
                        .font(.dm(11.5)).foregroundStyle(Color.slInkMuted).monospacedDigit()
                }
                Spacer(minLength: 0)
                if let avg = summary.avg {
                    VStack(spacing: 0) {
                        Text(Fmt.num(avg, digits: 1)).font(.dm(22, .semibold)).monospacedDigit().foregroundStyle(Color.slInk)
                        Text("★").font(.dm(11)).foregroundStyle(Color.slWarn)
                    }
                }
            }

            VStack(spacing: 5) {
                ForEach((1...5).reversed(), id: \.self) { star in
                    let n = dist.indices.contains(star - 1) ? dist[star - 1] : 0
                    HStack(spacing: 8) {
                        Text("\(star)★").font(.dm(11)).foregroundStyle(Color.slInkMuted).frame(width: 24, alignment: .trailing)
                        AsoMeterBar(fraction: total > 0 ? Double(n) / Double(total) : 0,
                                    tint: star >= 4 ? .slAccent500 : star == 3 ? Color(rgb: 214, 180, 120) : Color.slBad.opacity(0.6))
                        Text("\(n)").font(.dm(11)).monospacedDigit().foregroundStyle(Color.slInkMuted).frame(width: 34, alignment: .leading)
                    }
                }
            }
            .padding(.top, 14)

            if let low = summary.lowStarShare, low > 0 {
                Text(t("aso.rev.lowShare", ["pct": Fmt.int(low)])).font(.dm(11.5)).foregroundStyle(Color.slInkMuted).padding(.top, 8)
            }

            if let c = summary.complaints, !c.isEmpty {
                reviews(t("aso.rev.complaints"), Array(c.prefix(3)), bad: true)
            }
            if let p = summary.praise, !p.isEmpty {
                reviews(t("ios.aso.praise"), Array(p.prefix(3)), bad: false)
            }
        }
    }

    private func reviews(_ title: String, _ items: [AsoReviewSummary.Review], bad: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RowDivider()
            AsoSectionLabel(text: title).padding(.top, 4)
            ForEach(Array(items.enumerated()), id: \.offset) { _, r in
                (Text(Fmt.int(r.rating) + "★ ").fontWeight(.semibold).foregroundStyle(bad ? Color.slBad : Color.slGood)
                 + Text(r.title ?? "").fontWeight(.medium).foregroundStyle(Color.slInk)
                 + Text((r.body ?? "").isEmpty ? "" : " — " + (r.body ?? "")).foregroundStyle(Color.slInkMuted))
                    .font(.dm(12.5)).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 12)
    }
}
