//
//  Formatters.swift
//  seenlab
//
//  Dates and numbers as the web shows them (relative time, grouped thousands, percentages).
//

import Foundation

enum Fmt {
    private static let iso: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f }()
    private static let isoFrac: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }()
    private static let day: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = TimeZone(identifier: "UTC"); return f }()

    static func date(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        return iso.date(from: s) ?? isoFrac.date(from: s) ?? day.date(from: String(s.prefix(10)))
    }

    private static var loc: Locale { Locale(identifier: L10n.shared.locale == "sr" ? "sr-Latn" : L10n.shared.locale) }

    /// "pre 3 sata", "2 hours ago".
    static func relative(_ s: String?) -> String {
        guard let d = date(s) else { return "—" }
        let f = RelativeDateTimeFormatter()
        f.locale = loc
        f.unitsStyle = .full
        return f.localizedString(for: d, relativeTo: Date())
    }

    /// "28. sep", "Sep 28".
    static func short(_ s: String?) -> String {
        guard let d = date(s) else { return "—" }
        return d.formatted(Date.FormatStyle(locale: loc).day().month(.abbreviated))
    }

    /// "ponedeljak, 28. septembar" — the header date on every channel.
    static func today() -> String {
        Date().formatted(Date.FormatStyle(locale: loc).weekday(.wide).day().month(.wide))
    }

    static func int(_ v: Double?) -> String {
        guard let v else { return "—" }
        return Int(v.rounded()).formatted(.number.locale(loc))
    }

    static func num(_ v: Double?, digits: Int = 1) -> String {
        guard let v else { return "—" }
        return v.formatted(.number.precision(.fractionLength(0...digits)).locale(loc))
    }

    static func pct(_ v: Double?, digits: Int = 1) -> String {
        guard let v else { return "—" }
        return num(v, digits: digits) + "%"
    }

    /// Position the web way: "#12", or "—" when not ranked.
    static func pos(_ v: Double?) -> String {
        guard let v else { return "—" }
        return "#" + num(v, digits: 1)
    }

    /// Quotes in the reader's language: „…“ in Serbian and German, «…» in French and Spanish, “…” otherwise.
    static func quote(_ s: String) -> String {
        switch L10n.shared.locale {
        case "sr", "de": return "„" + s + "“"
        case "fr": return "« " + s + " »"
        case "es": return "«" + s + "»"
        default: return "“" + s + "”"
        }
    }

    static func host(_ url: String?) -> String {
        guard let url, let u = URL(string: url), let h = u.host else { return url ?? "" }
        return h.hasPrefix("www.") ? String(h.dropFirst(4)) : h
    }

    static func path(_ url: String?) -> String {
        guard let url, let u = URL(string: url) else { return url ?? "" }
        let p = u.path.isEmpty ? "/" : u.path
        return p + (u.query.map { "?" + $0 } ?? "")
    }
}
