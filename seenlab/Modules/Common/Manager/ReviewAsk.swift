//
//  ReviewAsk.swift
//  seenlab
//
//  Asking for an App Store rating, the way that works: first our own sheet (RateSheet) at a moment
//  that is actually good news — a keyword climbed, an assistant mentions the app, a growth step got
//  done — and only when the person says yes, Apple's rating prompt. Apple shows that prompt at most
//  three times a year and may skip it; a "something's off" answer goes to us by email instead, and
//  Settings has a direct link to the store's review page that nothing throttles.
//

import Combine
import StoreKit
import SwiftUI
import UIKit

@MainActor
final class ReviewAsk: ObservableObject {
    static let shared = ReviewAsk()

    enum Kind: String { case asoUp, aioMention, growthDone }
    struct Moment: Identifiable {
        let id = UUID()
        let kind: Kind
        let params: [String: Any]
        /// "“daily planner” climbed 36 places this morning."
        var line: String { t("ios.rate.moment." + kind.rawValue, params) }
    }

    /// The sheet to show, if any (MainView draws it).
    @Published var pending: Moment?

    private let d = UserDefaults.standard
    private var now: Double { Date().timeIntervalSince1970 }
    private static let day: Double = 86400

    static let feedbackEmail = "hello@seenlab.io"
    /// The App Store page's "write a review" link, once the app has its Apple ID (Info.plist SLAppStoreID).
    static var writeReviewURL: URL? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "SLAppStoreID") as? String, !id.isEmpty else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(id)?action=write-review")
    }

    /// Every launch: counts sessions and remembers the first one.
    func launched() {
        d.set(d.integer(forKey: "review.launches") + 1, forKey: "review.launches")
        if d.double(forKey: "review.firstLaunch") == 0 { d.set(now, forKey: "review.firstLaunch") }
    }

    /// Good news just arrived: offer the sheet if the rules allow. Harmless to call often.
    func offer(_ kind: Kind, _ params: [String: Any] = [:]) {
        guard pending == nil, ready else { return }
        d.set(now, forKey: "review.lastAsk")
        withAnimation(.spring(duration: 0.5, bounce: 0.2)) { pending = Moment(kind: kind, params: params) }
    }

    /// The rules: not the first session, a day with the app, ten days between sheets, four months
    /// after a rating, six weeks after a complaint.
    private var ready: Bool {
        #if DEBUG
        if d.string(forKey: "debugToken") != nil { return false }   // screenshots and checks
        #endif
        guard d.integer(forKey: "review.launches") >= 2 else { return false }
        let first = d.double(forKey: "review.firstLaunch")
        guard first > 0, now - first >= Self.day else { return false }
        let last = d.double(forKey: "review.lastAsk"), rated = d.double(forKey: "review.rated"), fed = d.double(forKey: "review.feedback")
        return (last == 0 || now - last >= 10 * Self.day) && (rated == 0 || now - rated >= 120 * Self.day) && (fed == 0 || now - fed >= 45 * Self.day)
    }

    /// "Yes": Apple's prompt, once the sheet is gone.
    func rate() {
        close()
        d.set(now, forKey: "review.rated")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.45))
            if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }) {
                AppStore.requestReview(in: scene)
            }
        }
    }

    /// "Something's off": a mail to us, with the app version and the moment that opened the sheet.
    func feedback() {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let subject = "Seenlab iOS \(v)".addingPercentEncoding(withUrlQueryAllowed: true) ?? ""
        close()
        d.set(now, forKey: "review.feedback")
        if let url = URL(string: "mailto:\(Self.feedbackEmail)?subject=\(subject)") { UIApplication.shared.open(url) }
    }

    func later() { close() }

    private func close() { withAnimation(.spring(duration: 0.4, bounce: 0.1)) { pending = nil } }

    #if DEBUG
    /// `-showRateAsk asoUp|aioMention|growthDone` opens the sheet right away (screenshots, checks).
    func debugShow() {
        guard let raw = d.string(forKey: "showRateAsk"), let kind = Kind(rawValue: raw) else { return }
        let params: [String: Any] = kind == .asoUp ? ["kw": "daily planner", "n": 36] : kind == .aioMention ? ["n": 15] : [:]
        pending = Moment(kind: kind, params: params)
    }
    #endif
}

private extension String {
    func addingPercentEncoding(withUrlQueryAllowed: Bool) -> String? { addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) }
}
