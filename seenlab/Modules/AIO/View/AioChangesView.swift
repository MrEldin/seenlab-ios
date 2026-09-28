//
//  AioChangesView.swift
//  seenlab
//
//  Changes tab (web: ChangesPanel.vue): what changed since the previous measurement, per prompt and
//  assistant, and the logged experiments with the mention rate before and after.
//

import SwiftUI

struct AioChangesView: View {
    let data: AioOverview
    @Environment(\.channel) private var channel

    private var changes: [AioChange] { data.changes ?? [] }
    private var experiments: [AioExperiment] { data.experiments ?? [] }

    var body: some View {
        SLCard(padding: 0) {
            AioCardHead(title: t("aio.changes.title"), subtitle: t("aio.changes.subtitle"), kb: { channel.kb("changes") })
            RowDivider()
            if changes.isEmpty {
                Text(t("aio.changes.empty")).font(.dm(13.5)).foregroundStyle(Color.slInkMuted).padding(18)
            } else {
                RowList(items: changes) { c in changeRow(c) }
            }
        }

        SLCard(padding: 0) {
            AioCardHead(title: t("aio.experiments.title"), subtitle: t("aio.experiments.subtitle"))
            if !experiments.isEmpty {
                RowDivider()
                RowList(items: experiments) { e in experimentRow(e) }
            }
        }
        AioWebNote()
    }

    private func look(_ type: String?) -> (icon: String, tone: Tone) {
        switch type {
        case "lost": ("arrow.down", .bad)
        case "down": ("arrow.down.right", .warn)
        case "gained": ("star", .good)
        case "up": ("arrow.up.right", .good)
        default: ("circle", .neutral)
        }
    }

    private func changeRow(_ c: AioChange) -> some View {
        let l = look(c.type)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: l.icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(l.tone.fg)
                .frame(width: 28, height: 28).background(l.tone.bg, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                (Text(data.label(c.engine ?? "")).fontWeight(.semibold)
                 + Text(" · " + t("aio.changes.types." + (c.type ?? "up"), ["from": c.from?.display ?? "—", "to": c.to?.display ?? "—"])))
                    .font(.dm(13.5)).foregroundStyle(Color.slInk).monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                if let prompt = c.prompt { Text(prompt).font(.dm(12)).foregroundStyle(Color.slInkMuted).lineLimit(2) }
            }
            Spacer(minLength: 6)
            Text(Fmt.short(c.date)).font(.dm(11)).foregroundStyle(Color.slInkFaint)
        }
        .padding(.horizontal, 18).padding(.vertical, 13)
    }

    private func experimentRow(_ e: AioExperiment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(e.note ?? "").font(.dm(13.5, .medium)).foregroundStyle(Color.slInk).fixedSize(horizontal: false, vertical: true)
                Text(Fmt.short(e.startedOn)).font(.dm(12)).foregroundStyle(Color.slInkMuted)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                if e.ready == true {
                    let before = e.before?.double
                    let after = e.after?.double
                    let tone: Color = (after ?? 0) > (before ?? 0) ? .slGood : (after ?? 0) < (before ?? 0) ? .slBad : .slInk
                    (Text((before.map { Fmt.num($0) } ?? "—") + "%").foregroundStyle(Color.slInkMuted)
                     + Text(" → ").foregroundStyle(Color.slInk)
                     + Text((after.map { Fmt.num($0) } ?? "—") + "%").fontWeight(.bold).foregroundStyle(tone))
                        .font(.dm(12.5)).monospacedDigit()
                    Text(t("aio.experiments.rate")).font(.dm(11)).foregroundStyle(Color.slInkFaint)
                } else {
                    Text(t("aio.experiments.waiting", ["days": e.afterDays ?? 0])).font(.dm(12)).foregroundStyle(Color.slInkMuted).multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 13)
    }
}
