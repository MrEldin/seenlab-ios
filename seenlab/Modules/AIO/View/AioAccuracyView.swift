//
//  AioAccuracyView.swift
//  seenlab
//
//  Accuracy tab (web: AccuracyPanel.vue): how each assistant describes the product next to how it wants to
//  be described, then the claims in the answers checked against the product facts.
//

import SwiftUI

struct AioAccuracyView: View {
    let data: AioOverview
    let openSetup: () -> Void
    @Environment(\.channel) private var channel

    private var perception: [AioPerception] { data.perception ?? [] }
    private var counts: AioAccuracy.Counts? { data.accuracy?.counts }
    private var items: [AioClaimItem] { data.accuracy?.items ?? [] }
    private var hasFacts: Bool { !(data.facts ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        SLCard {
            CardTitle(title: t("aio.perception.title"), subtitle: t("aio.perception.subtitle"), kb: { channel.kb("accuracy") })
            if let wanted = data.positioning, !wanted.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("ios.aio.wanted")).font(.dm(11.5, .semibold)).foregroundStyle(Color.slAccent800)
                    Text(Fmt.quote(wanted)).font(.dm(13.5, .medium)).foregroundStyle(Color.slInk).fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.slTint50, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.slTint200, lineWidth: 1))
                .padding(.top, 14)
            }
            if perception.isEmpty {
                Text(t("aio.perception.empty")).font(.dm(12.5)).foregroundStyle(Color.slInkMuted).padding(.top, 14)
            } else {
                VStack(spacing: 8) {
                    ForEach(perception, id: \.engine) { p in
                        HStack(alignment: .top, spacing: 10) {
                            AioEngineMark(engine: p.engine, label: data.label(p.engine), size: 20)
                            Text(Fmt.quote(p.summary ?? "")).font(.dm(13.5)).foregroundStyle(Color.slInk).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(Color.slPaper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.top, 14)
            }
        }

        SLCard {
            CardTitle(title: t("aio.accuracy.title"), subtitle: t("aio.accuracy.subtitle"))
            AioFlow(spacing: 6) {
                Chip(text: t("aio.accuracy.wrong", ["n": counts?.wrong ?? 0]), tone: .bad)
                Chip(text: t("aio.accuracy.unclear", ["n": counts?.unclear ?? 0]), tone: .warn)
                Chip(text: t("aio.accuracy.correct", ["n": counts?.correct ?? 0]), tone: .good)
            }
            .monospacedDigit()
            .padding(.top, 12)
            if !hasFacts {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle").font(.system(size: 14)).foregroundStyle(Color.slAccent700)
                    (Text(t("aio.accuracy.noFacts") + " ").foregroundStyle(Color.slInkSoft)
                     + Text(t("aio.accuracy.addFacts")).foregroundStyle(Color.slAccent700).fontWeight(.semibold))
                        .font(.dm(12.5))
                        .fixedSize(horizontal: false, vertical: true)
                        .onTapGesture(perform: openSetup)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.slTint50, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, 14)
            }
        }

        if items.isEmpty {
            EmptyCard(icon: "checkmark.shield", title: t("aio.accuracy.empty"))
        } else {
            SLCard(padding: 0) {
                RowList(items: items) { c in claimRow(c) }
                AioCardTip(text: t("aio.accuracy.tip"))
            }
        }
    }

    private func claimRow(_ c: AioClaimItem) -> some View {
        let wrong = c.verdict == "wrong"
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: wrong ? "xmark.circle.fill" : "questionmark.circle")
                .font(.system(size: 17)).foregroundStyle(wrong ? Color.slBad : Color.slWarn)
            VStack(alignment: .leading, spacing: 5) {
                Text(Fmt.quote(c.claim ?? "")).font(.dm(14)).foregroundStyle(Color.slInk).fixedSize(horizontal: false, vertical: true)
                if let fix = c.fix, !fix.isEmpty {
                    (Text(t("aio.accuracy.truth") + ": ").font(.dm(12.5, .semibold)).foregroundStyle(Color.slGood)
                     + Text(fix).font(.dm(12.5)).foregroundStyle(Color.slInkSoft))
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 6) {
                    AioEngineMarks(engines: c.engines ?? [], label: data.label, size: 18)
                    if let prompt = c.prompt { Text("· " + prompt).font(.dm(11.5)).foregroundStyle(Color.slInkMuted).lineLimit(1) }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
    }
}
