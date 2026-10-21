//
//  Cadence.swift
//  seenlab
//
//  When the plan measures what, in words (web: billing/useCadence.js): the store every morning or every
//  second day, Google and the AI assistants every morning or on fixed weekdays. Read from the signed-in
//  account's `subscription.cadence` / `engine_days` (ISO weekday numbers, null = daily); without a
//  subscription everything reads as daily. Weekday names come from the UI language.
//

import Foundation

struct Cadence {
    private let sub: Subscription?
    init(_ sub: Subscription?) { self.sub = sub }

    private var loc: Locale { Locale(identifier: L10n.shared.locale == "sr" ? "sr-Latn" : L10n.shared.locale) }

    /// A date with the given ISO weekday (1 = Monday), today or the next one.
    private func date(on iso: Int) -> Date {
        let gregorian = Calendar.current.component(.weekday, from: Date())   // 1 = Sunday
        let today = gregorian == 1 ? 7 : gregorian - 1
        return Calendar.current.date(byAdding: .day, value: (iso - today + 7) % 7, to: Date()) ?? Date()
    }

    private func weekday(_ iso: Int, wide: Bool = false) -> String {
        date(on: iso).formatted(Date.FormatStyle(locale: loc).weekday(wide ? .wide : .abbreviated))
    }

    private func dayList(_ days: [Int]) -> String { days.map { weekday($0) }.joined(separator: " · ") }

    /// "every morning" | "on Mondays" | "Mon · Thu"
    func onDays(_ days: [Int]?) -> String {
        guard let days, !days.isEmpty else { return t("sl.cadence.everyMorning") }
        if days == [1] { return t("sl.cadence.onMondays") }
        return t("sl.cadence.onDays", ["days": dayList(days)])
    }

    var storeEvery: String {
        let n = sub?.cadence?.asoEveryDays ?? 1
        if n <= 1 { return t("sl.cadence.everyMorning") }
        if n == 2 { return t("sl.cadence.everySecondDay") }
        return t("sl.cadence.everyNthDay", ["n": n])
    }
    var googleEvery: String { onDays(sub?.cadence?.seoDays) }
    var assistantsEvery: String { onDays(sub?.cadence?.aioDays) }
    var actionsEvery: String { onDays(sub?.cadence?.actionsDays) }

    /// "daily" | "Mon · Thu" for one assistant; the overview payload may carry the days itself.
    func engineDays(_ key: String, _ days: [Int]? = nil) -> String {
        let d = days ?? sub?.engineDays?[key]
        guard let d, !d.isEmpty else { return t("sl.cadence.daily") }
        return dayList(d)
    }

    /// The next scheduled run of a channel: "tomorrow morning" on a daily plan, else the weekday name.
    func nextRun(_ days: [Int]?) -> String {
        guard let days, !days.isEmpty else { return t("sl.cadence.tomorrowMorning") }
        let gregorian = Calendar.current.component(.weekday, from: Date())
        let today = gregorian == 1 ? 7 : gregorian - 1
        let sorted = days.sorted()
        return weekday(sorted.first { $0 > today } ?? sorted[0], wide: true)
    }
}
