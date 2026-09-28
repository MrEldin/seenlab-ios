//
//  SeoParts.swift
//  seenlab
//
//  Small pieces the SEO tabs share: the section card (title, subtitle, "Kako ovo radi?", then rows
//  separated by hairlines like the web's divide-y lists), the rank sparkline and a few formatters.
//

import SwiftUI

/// A white card with a head and full-width rows under a hairline (the web's `section` + `ul.divide-y`).
struct SeoSection<Content: View, Accessory: View>: View {
    var eyebrow: String? = nil
    let title: String
    var subtitle: String? = nil
    var kb: String? = nil
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content
    @Environment(\.channel) private var channel

    var body: some View {
        SLCard(padding: 0) {
            HStack(alignment: .top, spacing: 10) {
                CardTitle(eyebrow: eyebrow, title: title, subtitle: subtitle, kb: kb.map { k in { channel.kb(k) } })
                Spacer(minLength: 0)
                accessory
            }
            .padding(18)
            content
        }
    }
}

extension SeoSection where Accessory == EmptyView {
    init(eyebrow: String? = nil, title: String, subtitle: String? = nil, kb: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle, kb: kb, accessory: { EmptyView() }, content: content)
    }
}

/// Rows under a section head: a hairline on top, one between rows.
struct SeoRows<Item, Row: View>: View {
    let items: [Item]
    var paper = false
    @ViewBuilder var row: (Item) -> Row

    var body: some View {
        VStack(spacing: 0) {
            RowDivider()
            RowList(items: items) { item in
                row(item).padding(.horizontal, 18).padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(paper ? Color.slPaper : Color.clear)
    }
}

/// A quiet line of text under a hairline (an empty list, a footnote).
struct SeoNote: View {
    let text: String
    var tone: Color = .slInkMuted
    var paper = false

    var body: some View {
        VStack(spacing: 0) {
            RowDivider()
            Text(text).font(.dm(13)).foregroundStyle(tone).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18).padding(.vertical, 14)
        }
        .background(paper ? Color.slPaper : Color.clear)
    }
}

/// Loading, failed or loaded, for one piece of the page.
struct SeoSlotView<Value, Content: View>: View {
    let slot: SeoSlot<Value>
    let retry: () -> Void
    @ViewBuilder var content: (Value?) -> Content

    var body: some View {
        if slot.loaded { content(slot.value) }
        else if let error = slot.error, !slot.loading { ErrorCard(message: error, retry: retry) }
        else { LoadingCard() }
    }
}

/// "Changes happen on the web" under a read-only tab.
struct SeoWebOnly: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "desktopcomputer").font(.system(size: 12)).foregroundStyle(Color.slInkFaint).padding(.top, 2)
            Text(t("ios.webOnly")).font(.dm(12)).foregroundStyle(Color.slInkMuted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }
}

/// A small label + value pair used in before/after and metric grids.
struct SeoMini: View {
    let label: String
    let value: Text
    var alignment: HorizontalAlignment = .trailing

    var body: some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(label).font(.dm(10.5)).foregroundStyle(Color.slInkFaint).lineLimit(1)
            value.font(.dm(12.5)).monospacedDigit().lineLimit(1)
        }
    }
}

/// The 30-day rank line: rank 1 on top, flat dashed line until there are two points.
struct SeoSpark: View {
    let series: [SeoKeyword.Point]
    var width: CGFloat = 80
    var height: CGFloat = 22
    var maxRank: Double = 30

    var body: some View {
        Canvas { ctx, size in
            let s = series
            if s.filter({ $0.p != nil }).count < 2 {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: size.height - 1))
                line.addLine(to: CGPoint(x: size.width, y: size.height - 1))
                ctx.stroke(line, with: .color(.slLine), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                return
            }
            var path = Path()
            for (i, x) in s.enumerated() {
                let px = CGFloat(i) / CGFloat(max(1, s.count - 1)) * size.width
                let rank = min(x.p ?? maxRank, maxRank)
                let py = CGFloat((rank - 1) / (maxRank - 1)) * (size.height - 2) + 1
                i == 0 ? path.move(to: CGPoint(x: px, y: py)) : path.addLine(to: CGPoint(x: px, y: py))
            }
            ctx.stroke(path, with: .color(.slAccent600), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
        .frame(width: width, height: height)
    }
}

enum SeoFmt {
    private static var loc: Locale { Locale(identifier: L10n.shared.locale == "sr" ? "sr-Latn" : L10n.shared.locale) }

    /// Numbers like the web's Search Console panel: compact from 10 000 up.
    static func num(_ v: Double?) -> String {
        let v = v ?? 0
        if v >= 10_000 { return v.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)).locale(loc)) }
        return v.formatted(.number.precision(.fractionLength(0...1)).locale(loc))
    }

    /// The path of a page, or its host for the home page (the web's `path()` in the lab and links).
    static func path(_ url: String?) -> String {
        guard let url, let u = URL(string: url) else { return url ?? "" }
        if u.path.isEmpty || u.path == "/" { return u.host ?? url }
        return u.path
    }

    /// Path plus query (the audit's page list).
    static func fullPath(_ url: String?) -> String { Fmt.path(url) }

    static func issueTitle(_ code: String) -> String {
        L10n.shared.has("seo.issues.\(code).title") ? t("seo.issues.\(code).title") : code
    }

    static func issueFix(_ code: String) -> String? {
        L10n.shared.has("seo.issues.\(code).fix") ? t("seo.issues.\(code).fix") : nil
    }

    static func severityTone(_ s: String?) -> Tone {
        switch s { case "error": .bad; case "warning": .warn; default: .neutral }
    }

    static func severityColor(_ s: String?) -> Color {
        switch s { case "error": .slBad; case "warning": .slWarn; default: .slInkFaint }
    }

    /// Milliseconds as the web shows them: "850 ms", "2.1 s".
    static func ms(_ v: Double?) -> String {
        guard let v else { return "—" }
        return v >= 1000 ? Fmt.num(v / 1000, digits: 1) + " s" : Fmt.int(v) + " ms"
    }
}

extension URL {
    /// Opens only real web addresses.
    static func seoWeb(_ s: String?) -> URL? {
        guard let s, let u = URL(string: s), u.scheme == "https" || u.scheme == "http" else { return nil }
        return u
    }
}
