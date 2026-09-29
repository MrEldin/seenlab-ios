//
//  CardFlow.swift
//  seenlab
//
//  How a channel screen lays out its cards. On a phone: one column, as before. On an iPad (wide enough for two
//  cards): cards flow into two columns, each new card going under the shorter column (a masonry, so there are no
//  holes), while wide things — the header, tab strips, tables and long lists, notes — span the whole row and the
//  columns continue underneath. Cards stay the width they were designed for; nothing is stretched or shrunk.
//

import SwiftUI

/// Whether a card takes a column or the whole row on a wide screen.
nonisolated enum CardSpan: Equatable, Sendable { case column, full }

private nonisolated struct CardSpanKey: LayoutValueKey { static let defaultValue: CardSpan = .full }

extension View {
    /// Wide screens only: `.column` lets the card sit next to another one; `.full` gives it the whole row.
    func cardSpan(_ span: CardSpan) -> some View { layoutValue(key: CardSpanKey.self, value: span) }
}

nonisolated struct CardFlow: Layout {
    var spacing: CGFloat = 14
    /// Two columns from this width up (a phone is at most ~440 pt wide).
    var twoColumnsFrom: CGFloat = 700

    private func place(_ width: CGFloat, _ subviews: Subviews) -> (frames: [CGRect], height: CGFloat) {
        let cols = width >= twoColumnsFrom ? 2 : 1
        let colW = cols == 1 ? width : (width - spacing) / 2
        var heights = Array(repeating: CGFloat(0), count: cols)   // where each column's next card starts
        var frames: [CGRect] = []
        for view in subviews {
            let full = cols == 1 || view[CardSpanKey.self] == .full
            if full {
                let y = heights.max() ?? 0
                let h = view.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
                frames.append(CGRect(x: 0, y: y, width: width, height: h))
                heights = heights.map { _ in y + h + (h > 0 ? spacing : 0) }
            } else {
                let c = heights.firstIndex(of: heights.min() ?? 0) ?? 0
                let h = view.sizeThatFits(ProposedViewSize(width: colW, height: nil)).height
                frames.append(CGRect(x: CGFloat(c) * (colW + spacing), y: heights[c], width: colW, height: h))
                heights[c] += h + (h > 0 ? spacing : 0)
            }
        }
        return (frames, max(0, (heights.max() ?? 0) - spacing))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 390
        return CGSize(width: width, height: place(width, subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (frames, _) = place(bounds.width, subviews)
        for (view, f) in zip(subviews, frames) {
            view.place(at: CGPoint(x: bounds.minX + f.minX, y: bounds.minY + f.minY), anchor: .topLeading, proposal: ProposedViewSize(width: f.width, height: f.height))
        }
    }
}
