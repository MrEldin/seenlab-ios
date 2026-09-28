//
//  Color+Seenlab.swift
//  seenlab
//
//  The brand tokens from seenlab-client/src/assets/app.css (:root). Petrol is the accent; status colours
//  (good / warn / bad) are separate and petrol is never used for success.
//

import SwiftUI

extension Color {
    init(rgb r: Double, _ g: Double, _ b: Double) { self.init(red: r / 255, green: g / 255, blue: b / 255) }

    static let slAccent400 = Color(rgb: 87, 154, 154)
    static let slAccent500 = Color(rgb: 44, 127, 127)
    static let slAccent600 = Color(rgb: 15, 110, 110)
    static let slAccent700 = Color(rgb: 13, 94, 94)
    static let slAccent800 = Color(rgb: 10, 75, 75)
    static let slAccent900 = Color(rgb: 8, 55, 55)

    static let slTint50 = Color(rgb: 243, 248, 248)
    static let slTint100 = Color(rgb: 231, 240, 240)
    static let slTint200 = Color(rgb: 207, 226, 226)
    static let slTint300 = Color(rgb: 171, 204, 204)

    static let slGood = Color(rgb: 27, 138, 75)
    static let slGoodSoft = Color(rgb: 226, 244, 232)
    static let slWarn = Color(rgb: 166, 106, 10)
    static let slWarnSoft = Color(rgb: 252, 241, 218)
    static let slBad = Color(rgb: 198, 61, 47)
    static let slBadSoft = Color(rgb: 251, 229, 225)

    static let slInk = Color(rgb: 31, 29, 26)
    static let slInkSoft = Color(rgb: 74, 70, 63)
    static let slInkMuted = Color(rgb: 122, 115, 104)
    static let slInkFaint = Color(rgb: 175, 168, 156)

    static let slBg = Color(rgb: 247, 245, 240)
    static let slPaper = Color(rgb: 255, 253, 248)
    static let slLine = Color(rgb: 233, 228, 218)
    static let slLineStrong = Color(rgb: 217, 210, 196)
    static let slMarker = Color(rgb: 255, 224, 102)
}

/// Tones shared by chips, deltas and status dots.
enum Tone {
    case neutral, accent, good, warn, bad

    var fg: Color {
        switch self { case .neutral: .slInkMuted; case .accent: .slAccent800; case .good: .slGood; case .warn: .slWarn; case .bad: .slBad }
    }
    var bg: Color {
        switch self { case .neutral: Color.slInk.opacity(0.05); case .accent: .slTint100; case .good: .slGoodSoft; case .warn: .slWarnSoft; case .bad: .slBadSoft }
    }
}
