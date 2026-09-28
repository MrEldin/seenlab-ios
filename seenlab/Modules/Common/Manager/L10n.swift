//
//  L10n.swift
//  seenlab
//
//  The app's strings are the web client's own (exported by seenlab-client/scripts/export-ios.mjs into
//  Resources/Locales), so the wording is identical in all five languages. This reads the vue-i18n format:
//  `{name}` parameters, plural forms split by `|`, `{'@'}` literals, and the store tokens (%store% …)
//  that name the App Store or Google Play depending on the project.
//

import Foundation
import Combine

final class L10n: ObservableObject {
    static let shared = L10n()
    static let languages = ["sr", "en", "de", "es", "fr"]

    @Published private(set) var locale: String
    /// ios or android — the store the ASO strings talk about.
    var platform = "ios"

    private var tables: [String: [String: Any]] = [:]

    private init() {
        let saved = UserDefaults.standard.string(forKey: "locale")
        let device = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "en"
        let guess = ["sr", "hr", "bs", "me"].contains(device) ? "sr" : device
        locale = saved ?? (L10n.languages.contains(guess) ? guess : "en")
    }

    func set(_ code: String) {
        guard L10n.languages.contains(code), code != locale else { return }
        UserDefaults.standard.set(code, forKey: "locale")
        locale = code
    }

    /// Adopts the language saved on the account, unless the person picked one on this device.
    func adoptAccountLocale(_ code: String?) {
        guard let code, UserDefaults.standard.string(forKey: "locale") == nil, L10n.languages.contains(code) else { return }
        locale = code
    }

    func t(_ key: String, _ params: [String: Any] = [:], count: Int? = nil) -> String {
        guard var text = lookup(key, in: locale) ?? lookup(key, in: "en") else { return key }
        let n = count ?? (params["n"] as? Int) ?? (params["count"] as? Int)
        if text.contains("|"), let n {
            let forms = text.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            text = forms.count >= 3 ? forms[min(n, 2)] : (n == 1 ? forms[0] : forms[min(1, forms.count - 1)])
        }
        text = text.replacingOccurrences(of: "{'@'}", with: "@")
        for (k, v) in params { text = text.replacingOccurrences(of: "{\(k)}", with: "\(v)") }
        if let n, params["n"] == nil { text = text.replacingOccurrences(of: "{n}", with: "\(n)") }
        return storeWords(text)
    }

    /// Whether the key exists (in the current language or English).
    func has(_ key: String) -> Bool { lookup(key, in: locale) != nil || lookup(key, in: "en") != nil }

    private func table(_ lang: String) -> [String: Any] {
        if let t = tables[lang] { return t }
        guard let url = Bundle.main.url(forResource: lang, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        tables[lang] = obj
        return obj
    }

    private func lookup(_ key: String, in lang: String) -> String? {
        var node: Any? = table(lang)
        for part in key.split(separator: ".") { node = (node as? [String: Any])?[String(part)] }
        return node as? String
    }

    private func storeWords(_ text: String) -> String {
        guard text.contains("%") else { return text }
        let p = platform == "android" ? "android" : "ios"
        let store = p == "android" ? "Google Play" : "App Store"
        let inStore: [String: [String: String]] = [
            "sr": ["ios": "u App Store-u", "android": "na Google Play-u"], "en": ["ios": "in the App Store", "android": "on Google Play"],
            "de": ["ios": "im App Store", "android": "bei Google Play"], "es": ["ios": "en la App Store", "android": "en Google Play"],
            "fr": ["ios": "sur l'App Store", "android": "sur Google Play"],
        ]
        let ofStore = locale == "sr" ? (p == "android" ? "Google Play-a" : "App Store-a") : store
        return text
            .replacingOccurrences(of: "%inStore%", with: (inStore[locale] ?? inStore["en"]!)[p]!)
            .replacingOccurrences(of: "%ofStore%", with: ofStore)
            .replacingOccurrences(of: "%store%", with: store)
            .replacingOccurrences(of: "%depth%", with: p == "android" ? "30" : "200")
    }
}

/// Shorthand used by every view: t("aso.tabs.keywords"), t("seo.lab.gain", ["n": 40]).
func t(_ key: String, _ params: [String: Any] = [:], count: Int? = nil) -> String {
    L10n.shared.t(key, params, count: count)
}
