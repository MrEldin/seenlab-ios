//
//  AioPromptsView.swift
//  seenlab
//
//  Prompts tab (web: PromptList.vue): the questions asked every morning, each with the latest result per
//  assistant (#place or "not mentioned") and 14 days of mention rate. Tap a prompt for the answers.
//

import SwiftUI

struct AioPromptsView: View {
    let data: AioOverview
    let open: (AioPromptRow) -> Void
    @Environment(\.channel) private var channel

    private var prompts: [AioPromptRow] { data.prompts ?? [] }
    private var activeCount: Int { prompts.filter { $0.isActive != false }.count }

    var body: some View {
        SLCard {
            HStack(alignment: .top, spacing: 10) {
                CardTitle(title: t("aio.prompts.title"), subtitle: t("aio.prompts.subtitle"), kb: { channel.kb("prompts") })
                Spacer(minLength: 0)
                Text(t("aio.prompts.count", ["n": activeCount, "limit": data.limit ?? 0]))
                    .font(.dm(11.5, .semibold)).monospacedDigit().foregroundStyle(Color.slInkSoft)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Color.slBg, in: Capsule())
                    .fixedSize()
            }
        }

        if prompts.isEmpty {
            EmptyCard(icon: "flask", title: t("aio.prompts.empty"), text: t("aio.prompts.emptyHint"))
            AioWebNote()
        } else {
            SLCard(padding: 0) {
                RowList(items: prompts) { p in
                    Button { open(p) } label: { AioPromptCell(prompt: p, engines: data.enabledEngines) }
                        .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct AioPromptCell: View {
    let prompt: AioPromptRow
    let engines: [AioEngine]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 8) {
                Text(prompt.text ?? "").font(.dm(14, .medium)).foregroundStyle(Color.slInk)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.slInkFaint).padding(.top, 3)
            }
            if prompt.isActive == false {
                Text(t("aio.prompts.paused")).font(.dm(11)).foregroundStyle(Color.slInkMuted)
            }
            AioFlow(spacing: 6) {
                ForEach(engines) { e in AioResultChip(engine: e, result: prompt.results?[e.key]) }
            }
            if let history = prompt.history, !history.isEmpty {
                HStack(spacing: 8) {
                    AioHistoryBars(values: history)
                    Text(t("aio.prompts.col.trend")).font(.dm(10.5)).foregroundStyle(Color.slInkFaint)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .opacity(prompt.isActive == false ? 0.5 : 1)
    }
}

/// Engine mark + "#2" / "not mentioned" / "failed" / "waiting".
struct AioResultChip: View {
    let engine: AioEngine
    let result: AioPromptResult?

    var body: some View {
        HStack(spacing: 6) {
            AioEngineMark(engine: engine.key, label: engine.name, size: 20)
            if let r = result {
                if r.failed {
                    Text(t("aio.prompts.error")).font(.dm(11.5)).foregroundStyle(Color.slBad)
                } else if r.mentioned == true {
                    HStack(spacing: 4) {
                        Text(AioFmt.place(r.position)).font(.dm(11.5, .bold))
                        if (r.samples ?? 1) > 1, let rate = r.rate {
                            Text(Fmt.num(rate, digits: 0) + "%").font(.dm(11.5, .medium)).foregroundStyle(Color.slInkMuted)
                        }
                    }
                    .monospacedDigit()
                    .foregroundStyle(Color.slGood)
                } else {
                    Text(t("aio.prompts.notMentioned")).font(.dm(11.5)).foregroundStyle(Color.slInkFaint)
                }
            } else {
                Text(t("aio.prompts.pending")).font(.dm(11.5)).foregroundStyle(Color.slInkFaint)
            }
        }
        .padding(.leading, 2).padding(.trailing, 9).padding(.vertical, 2)
        .background(Color.slBg, in: Capsule())
    }
}

/// 14 small bars: petrol height = mention rate, grey dash = asked but not mentioned, line = not asked.
struct AioHistoryBars: View {
    let values: [Double?]
    var height: CGFloat = 22

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(v == nil ? Color.slLine : (v! > 0 ? Color.slAccent600 : Color.slInkFaint.opacity(0.6)))
                    .frame(width: 5, height: v == nil ? 4 : (v! > 0 ? max(6, v! / 100 * height) : 6))
            }
        }
        .frame(height: height, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

/// Wraps its children onto new lines (chips, names).
struct AioFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.items {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row { var items: [Int] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            if !row.items.isEmpty, row.width + spacing + size.width > width {
                rows.append(row)
                row = Row(y: row.y + row.height + spacing)
            }
            row.width += (row.items.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.items.append(i)
        }
        if !row.items.isEmpty { rows.append(row) }
        return rows
    }
}
