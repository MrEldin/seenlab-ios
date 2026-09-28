//
//  Font+Seenlab.swift
//  seenlab
//
//  DM Sans for everything, Caveat for the small handwritten notes (the web's eyebrows). Both are the
//  Google Fonts variable files in Resources/Fonts, registered at launch.
//

import SwiftUI
import CoreText

extension Font {
    static func dm(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .custom("DM Sans", size: size).weight(weight) }
    static func hand(_ size: CGFloat) -> Font { .custom("Caveat", size: size).weight(.bold) }
}

enum FontRegistrar {
    static func register() {
        for name in ["DMSans", "Caveat"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}
