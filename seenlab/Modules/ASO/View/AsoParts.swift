//
//  AsoParts.swift
//  seenlab
//
//  Small pieces the ASO tabs share, drawn like the web's PositionPill, ScoreBadge, sparkline and the
//  audit's field meter.
//

import SwiftUI

enum AsoFmt {
    /// "🇺🇸" for "us".
    static func flag(_ code: String) -> String {
        code.uppercased().unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value) }.map { String($0) }.joined()
    }

    /// "United States" / "Sjedinjene Države" in the app's language.
    static func countryName(_ code: String) -> String {
        let id = L10n.shared.locale == "sr" ? "sr-Latn" : L10n.shared.locale
        return Locale(identifier: id).localizedString(forRegionCode: code.uppercased()) ?? code.uppercased()
    }

    /// "#12" or "—" (whole ranks, like the web).
    static func pos(_ v: Double?) -> String { v.map { "#" + Fmt.int($0) } ?? "—" }

    /// The field names the snapshot reports ("name", "subtitle") in the reader's words.
    static func field(_ f: String?) -> String {
        guard let f else { return "" }
        return L10n.shared.has("aso.hdr.fields.\(f)") ? t("aso.hdr.fields.\(f)") : f
    }

    /// A date-only string ("2026-09-25") as the short local date.
    static func day(_ s: String?) -> String { Fmt.short(s) }
}

/// Rank with its change: green in the top 10, a ▲/▼ chip for the move (positive = better).
struct AsoPositionPill: View {
    let position: Double?
    var delta: Double? = nil
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 4) {
            Text(AsoFmt.pos(position))
                .font(.dm(size, .semibold))
                .foregroundStyle(color)
                .monospacedDigit()
            if let delta, delta != 0 {
                Text((delta > 0 ? "▲" : "▼") + Fmt.int(min(200, abs(delta))))
                    .font(.dm(10, .semibold)).monospacedDigit()
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .foregroundStyle(delta > 0 ? Color.slGood : Color.slBad)
                    .background(delta > 0 ? Color.slGoodSoft : Color.slBadSoft, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
        }
    }

    private var color: Color {
        guard let position else { return .slInkFaint }
        return position <= 10 ? .slGood : position <= 50 ? .slInk : .slInkSoft
    }
}

/// A 0–100 score with a dot. Difficulty: low is good. Traffic: high is good.
struct AsoScoreBadge: View {
    enum Kind { case traffic, difficulty }
    let value: Double?
    var kind: Kind = .difficulty

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(tone.fg.opacity(0.7)).frame(width: 5, height: 5)
            Text(value.map { Fmt.int($0) } ?? "—").font(.dm(11, .semibold)).monospacedDigit()
        }
        .padding(.horizontal, 7).padding(.vertical, 2)
        .foregroundStyle(value == nil ? Color.slInkFaint : tone.fg)
        .background(value == nil ? Color.slTint50 : tone.bg, in: Capsule())
    }

    private var tone: Tone {
        guard let v = value else { return .neutral }
        let good = kind == .difficulty ? v <= 35 : v >= 60
        let mid = kind == .difficulty ? v <= 65 : v >= 35
        return good ? .good : mid ? .warn : .bad
    }
}

/// Traffic + difficulty side by side, with their labels.
struct AsoScores: View {
    let traffic: Double?
    let difficulty: Double?

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Text(t("aso.kw.colTraffic")).font(.dm(11)).foregroundStyle(Color.slInkMuted)
                AsoScoreBadge(value: traffic, kind: .traffic)
            }
            HStack(spacing: 4) {
                Text(t("aso.kw.colDifficulty")).font(.dm(11)).foregroundStyle(Color.slInkMuted)
                AsoScoreBadge(value: difficulty, kind: .difficulty)
            }
        }
    }
}

/// Position over the last 30 days; lower is better, so the axis is inverted (up = climbing).
struct AsoSparkline: View {
    let points: [Double]

    var body: some View {
        if points.count < 2 {
            Text("—").font(.dm(10)).foregroundStyle(Color.slInkFaint).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            let up = points.last! <= points.first!
            GeometryReader { geo in
                Path { path in
                    let maxV = max(points.max()!, 1), minV = points.min()!
                    let w = geo.size.width, h = geo.size.height
                    for (i, v) in points.enumerated() {
                        let x = CGFloat(i) / CGFloat(points.count - 1) * w
                        let y = maxV == minV ? h / 2 : CGFloat((v - minV) / (maxV - minV)) * (h - 6) + 3
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(up ? Color.slAccent600 : Color.slBad, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

/// A field's text with its length against the store limit (the audit's FieldBar).
struct AsoFieldMeter: View {
    let label: String
    let text: String?
    let length: Int
    let max: Int
    var mono = false
    var clamp = false

    private var over: Bool { length > max }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.dm(12.5, .medium)).foregroundStyle(Color.slInk)
                Spacer()
                Text("\(length) / \(max)").font(.dm(12)).monospacedDigit().foregroundStyle(over ? Color.slBad : Color.slInkMuted)
            }
            Group {
                if clamp {
                    ScrollView { textView }.frame(maxHeight: 160)
                } else {
                    textView
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.slTint50, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.slLine, lineWidth: 1))
            AsoMeterBar(fraction: Double(length) / Double(Swift.max(max, 1)), over: over)
        }
    }

    private var textView: some View {
        Text((text ?? "").isEmpty ? "—" : text!)
            .font(mono ? .system(size: 12.5, design: .monospaced) : .dm(clamp ? 13 : 14))
            .foregroundStyle(clamp ? Color.slInkSoft : Color.slInk)
            .lineSpacing(clamp ? 3 : 1)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The thin progress bar under a field.
struct AsoMeterBar: View {
    let fraction: Double
    var over = false
    var tint: Color = .slAccent500

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.slTint100)
                Capsule().fill(over ? Color.slBad.opacity(0.7) : tint).frame(width: geo.size.width * min(1, Swift.max(0, fraction)))
            }
        }
        .frame(height: 6)
    }
}

/// The "you" tag next to the own app's name.
struct AsoYouTag: View {
    var body: some View {
        Text(t("aso.you")).font(.dm(10, .semibold)).foregroundStyle(.white)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Color.slAccent800, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

/// A small uppercase label above a group inside a card (the web's `text-[11px] uppercase tracking-wide`).
struct AsoSectionLabel: View {
    let text: String
    var color: Color = .slInkFaint
    var body: some View {
        Text(text.uppercased()).font(.dm(11, .semibold)).tracking(0.6).foregroundStyle(color)
    }
}

/// A numbered line (quick wins, recommendations).
struct AsoNumbered: View {
    let index: Int
    let text: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(index)").font(.dm(11, .semibold)).monospacedDigit().foregroundStyle(Color.slAccent800)
                .frame(width: 20, height: 20)
                .background(Color.slTint100, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text(text).font(.dm(14)).foregroundStyle(Color.slInk).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A bullet line.
struct AsoBullet: View {
    let text: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle().fill(Color.slInkFaint).frame(width: 4, height: 4).alignmentGuide(.firstTextBaseline) { d in d[.bottom] + 4 }
            Text(text).font(.dm(13.5)).foregroundStyle(Color.slInkSoft).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Word chips that wrap to the next line.
struct AsoFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            maxX = Swift.max(maxX, x - spacing)
            rowH = Swift.max(rowH, s.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = Swift.max(rowH, s.height)
        }
    }
}

/// A small word chip.
struct AsoWordChip: View {
    let text: String
    var fg: Color = .slAccent800
    var bg: Color = .slTint100
    var mono = false
    var strike = false

    var body: some View {
        Text(text)
            .font(mono ? .system(size: 11.5, design: .monospaced) : .dm(11.5, .medium))
            .strikethrough(strike)
            .foregroundStyle(fg)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(bg, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// A quiet grey box with a label and a value (the web's `rounded-2xl bg-sl-tint-50 p-3` stat).
struct AsoStatBox: View {
    let label: String
    let value: String
    var sub: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.dm(11)).foregroundStyle(Color.slInkMuted).lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.dm(15, .semibold)).foregroundStyle(Color.slInk).monospacedDigit().lineLimit(1)
                if let sub { Text(sub).font(.dm(11)).foregroundStyle(Color.slInkMuted) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.slTint50, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// The note at the bottom of a tab: changes happen on the web.
struct AsoWebOnlyNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "desktopcomputer").font(.system(size: 13)).foregroundStyle(Color.slInkMuted)
            Text(t("ios.webOnly")).font(.dm(12.5)).foregroundStyle(Color.slInkMuted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4).padding(.top, 4)
    }
}

/// A small empty line inside a card.
struct AsoInlineEmpty: View {
    let title: String
    var hint: String? = nil
    var icon: String = "chart.line.uptrend.xyaxis"

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 22, weight: .light)).foregroundStyle(Color.slAccent600)
            Text(title).font(.dm(14, .semibold)).foregroundStyle(Color.slInk).multilineTextAlignment(.center)
            if let hint { Text(hint).font(.dm(12.5)).foregroundStyle(Color.slInkMuted).multilineTextAlignment(.center) }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}
