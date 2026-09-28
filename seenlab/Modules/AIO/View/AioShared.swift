//
//  AioShared.swift
//  seenlab
//
//  Pieces the AIO tabs share: the engine mark (web: EngineMark.vue), names highlighted in text,
//  a card footer tip, and the answer text rendered from markdown (web: AnswerText.vue).
//

import SwiftUI

/// A small neutral mark per assistant — a letter and a tint, no vendor logos.
struct AioEngineMark: View {
    let engine: String
    var label: String? = nil
    var size: CGFloat = 20

    private static let looks: [String: (bg: Color, fg: Color)] = [
        "deepseek": (Color(rgb: 230, 236, 243), Color(rgb: 63, 95, 134)),
        "chatgpt": (Color(rgb: 227, 239, 232), Color(rgb: 47, 107, 79)),
        "perplexity": (Color(rgb: 228, 238, 238), Color(rgb: 45, 106, 106)),
        "gemini": (Color(rgb: 236, 231, 242), Color(rgb: 94, 79, 122)),
        "claude": (Color(rgb: 244, 230, 220), Color(rgb: 138, 82, 48)),
        "google_aio": (Color(rgb: 230, 235, 246), Color(rgb: 59, 85, 150)),
    ]

    private var letter: String {
        if engine == "google_aio" { return "AO" }
        return String((label ?? engine).prefix(1)).uppercased()
    }

    var body: some View {
        let look = Self.looks[engine] ?? (Color.slBg, Color.slInkSoft)
        Text(letter)
            .font(.dm(size * (letter.count > 1 ? 0.42 : 0.5), .bold))
            .foregroundStyle(look.fg)
            .frame(width: size, height: size)
            .background(look.bg, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityLabel(label ?? engine)
    }

    /// Line colours of the trend chart (web: RivalsPanel COLORS).
    static func chartColor(_ engine: String) -> Color {
        switch engine {
        case "deepseek": Color(rgb: 91, 127, 168)
        case "chatgpt": Color(rgb: 63, 138, 99)
        case "perplexity": Color(rgb: 45, 127, 127)
        case "gemini": Color(rgb: 122, 105, 160)
        case "claude": Color(rgb: 176, 112, 63)
        case "google_aio": Color(rgb: 59, 85, 150)
        default: Color(rgb: 153, 153, 153)
        }
    }
}

/// A row of engine marks.
struct AioEngineMarks: View {
    let engines: [String]
    let label: (String) -> String
    var size: CGFloat = 20

    var body: some View {
        HStack(spacing: 4) { ForEach(engines, id: \.self) { AioEngineMark(engine: $0, label: label($0), size: size) } }
    }
}

enum AioFmt {
    /// "#2", or "#•" when mentioned without a place.
    static func place(_ v: Double?) -> String {
        guard let v, v > 0 else { return "#•" }
        return "#" + Fmt.num(v, digits: 1)
    }

    /// A whole number in the current locale.
    static func n(_ v: Int?) -> String { Fmt.int(v.map(Double.init)) }

    /// "hydratetap.com/blog/best-apps" — host and path without the trailing slash.
    static func hostPath(_ url: String) -> String {
        guard let u = URL(string: url), let host = u.host else { return url }
        let h = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        var p = u.path
        if p.hasSuffix("/") { p.removeLast() }
        return h + p
    }

    /// A vue-i18n template with some of its `{params}` drawn with the yellow marker (the web headlines).
    static func marked(_ template: String, _ values: [String: String], marked: Set<String>) -> AttributedString {
        var out = AttributedString()
        var rest = Substring(template)
        while let open = rest.firstIndex(of: "{"), let close = rest[open...].firstIndex(of: "}") {
            out += AttributedString(String(rest[..<open]))
            let key = String(rest[rest.index(after: open)..<close])
            if let value = values[key] {
                var piece = AttributedString(value)
                if marked.contains(key) { piece.backgroundColor = Color.slMarker.opacity(0.85) }
                out += piece
            } else {
                out += AttributedString(String(rest[open...close]))
            }
            rest = rest[rest.index(after: close)...]
        }
        out += AttributedString(String(rest))
        return out
    }
}

/// The paper strip at the bottom of a card (the web's tips).
struct AioCardTip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.dm(12))
            .foregroundStyle(Color.slInkMuted)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.slPaper)
            .overlay(alignment: .top) { RowDivider() }
    }
}

/// A card's heading with the standard padding, for cards that hold an edge-to-edge list.
struct AioCardHead: View {
    var eyebrow: String? = nil
    let title: String
    var subtitle: String? = nil
    var kb: (() -> Void)? = nil

    var body: some View {
        CardTitle(eyebrow: eyebrow, title: title, subtitle: subtitle, kb: kb)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "Running and changes happen on the web" — shown where the web has buttons.
struct AioWebNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "desktopcomputer").font(.system(size: 12)).foregroundStyle(Color.slAccent700).padding(.top, 2)
            Text(t("ios.webOnly")).font(.dm(12)).foregroundStyle(Color.slInkMuted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Answer text

/// An assistant's answer as markdown, with the product's names on the yellow marker and rivals underlined.
/// Model output is untrusted: only http(s) links stay tappable.
struct AioAnswerText: View {
    let text: String
    var own: [String] = []
    var rivals: [String] = []
    var size: CGFloat = 13.5

    private enum Block: Hashable {
        case heading(String)
        case bullet(String)
        case numbered(String, String)
        case paragraph(String)
        case table([String])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let s):
                    Text(inline(s, weight: .bold)).font(.dm(size + 0.5, .bold)).foregroundStyle(Color.slInk).padding(.top, 4)
                case .bullet(let s):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").font(.dm(size, .bold)).foregroundStyle(Color.slInkMuted)
                        paragraph(s)
                    }
                    .padding(.leading, 4)
                case .numbered(let n, let s):
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(n).font(.dm(size, .semibold)).foregroundStyle(Color.slInkMuted).monospacedDigit()
                        paragraph(s)
                    }
                    .padding(.leading, 4)
                case .paragraph(let s):
                    paragraph(s)
                case .table(let rows):
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                                Text(inline(r, weight: i == 0 ? .semibold : .regular)).font(.dm(size - 1.5, i == 0 ? .semibold : .regular)).foregroundStyle(Color.slInkSoft)
                            }
                        }
                        .padding(10)
                    }
                    .background(Color.slPaper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    private func paragraph(_ s: String) -> some View {
        Text(inline(s))
            .font(.dm(size))
            .foregroundStyle(Color.slInkSoft)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .tint(Color.slAccent700)
    }

    private static let numbered = try? Regex(#"(\d{1,3})[.)]\s+(.*)"#)

    private var blocks: [Block] {
        var out: [Block] = []
        var para: [String] = []
        var table: [String] = []
        func flush() {
            if !para.isEmpty { out.append(.paragraph(para.joined(separator: "\n"))); para = [] }
            if !table.isEmpty { out.append(.table(table)); table = [] }
        }
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { flush(); continue }
            if line.hasPrefix("|") {
                if !para.isEmpty { out.append(.paragraph(para.joined(separator: "\n"))); para = [] }
                let cells = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                if cells.allSatisfy({ $0.allSatisfy { "-: ".contains($0) } }) { continue }
                table.append(cells.joined(separator: "  ·  "))
                continue
            }
            if !table.isEmpty { out.append(.table(table)); table = [] }
            if line.hasPrefix("#") {
                flush()
                out.append(.heading(line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                flush()
                out.append(.bullet(String(line.dropFirst(2))))
            } else if let m = Self.numbered.flatMap({ try? $0.wholeMatch(in: line) }), m.count > 2, let n = m[1].substring, let rest = m[2].substring {
                flush()
                out.append(.numbered(String(n) + ".", String(rest)))
            } else if line == "---" || line == "***" {
                flush()
            } else {
                para.append(line)
            }
        }
        flush()
        return out
    }

    private func inline(_ s: String, weight: Font.Weight? = nil) -> AttributedString {
        var attr = (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s)
        // Links: only http(s) stay.
        for run in attr.runs {
            guard let url = run.link else { continue }
            if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                attr[run.range].foregroundColor = Color.slAccent700
                attr[run.range].underlineStyle = .single
            } else {
                attr[run.range].link = nil
            }
        }
        AioHighlight.apply(to: &attr, own: own, rivals: rivals, size: size)
        return attr
    }
}

enum AioHighlight {
    /// Marks every whole-word occurrence of the product's names (marker) and the rivals' (underline).
    static func apply(to attr: inout AttributedString, own: [String], rivals: [String], size: CGFloat) {
        let names = (own.map { ($0, true) } + rivals.map { ($0, false) })
            .filter { $0.0.count >= 3 }
            .sorted { $0.0.count > $1.0.count }
        guard !names.isEmpty else { return }
        let plain = String(attr.characters)
        let lower = plain.lowercased()
        guard lower.count == plain.count else { return }
        let chars = Array(plain)
        var taken = [Bool](repeating: false, count: chars.count)

        for (name, isOwn) in names {
            let needle = name.lowercased()
            var from = lower.startIndex
            while let r = lower.range(of: needle, range: from..<lower.endIndex) {
                from = r.upperBound
                let start = lower.distance(from: lower.startIndex, to: r.lowerBound)
                let end = lower.distance(from: lower.startIndex, to: r.upperBound)
                let before = start > 0 ? chars[start - 1] : " "
                let after = end < chars.count ? chars[end] : " "
                if before.isLetter || before.isNumber || after.isLetter || after.isNumber { continue }
                if taken[start..<end].contains(true) { continue }
                for i in start..<end { taken[i] = true }
                let lo = attr.characters.index(attr.startIndex, offsetBy: start)
                let hi = attr.characters.index(attr.startIndex, offsetBy: end)
                if isOwn {
                    attr[lo..<hi].backgroundColor = Color.slMarker.opacity(0.75)
                    attr[lo..<hi].foregroundColor = Color.slInk
                    attr[lo..<hi].font = .dm(size, .bold)
                } else {
                    attr[lo..<hi].underlineStyle = Text.LineStyle(pattern: .solid, color: Color.slInkFaint)
                    attr[lo..<hi].foregroundColor = Color.slInk
                }
            }
        }
    }
}
