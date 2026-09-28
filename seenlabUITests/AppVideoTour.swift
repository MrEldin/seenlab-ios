//
//  AppVideoTour.swift
//  seenlabUITests
//
//  Drives the app through the tour recorded for the app video (seenlab-client/tools/app-video), against the
//  demo API with the fictional Habitly data. Every step prints `TOUR <name> <unix time>` so the film can cut
//  the recording at the right moments. Not a regular test — run it with tools/app-video/record.sh.
//

import XCTest

final class AppVideoTour: XCTestCase {
    private let app = XCUIApplication()

    private func mark(_ name: String) { print("TOUR \(name) \(Date().timeIntervalSince1970)") }
    private func wait(_ s: Double) { Thread.sleep(forTimeInterval: s) }
    /// Any element with this accessibility identifier, once it exists.
    private func id(_ identifier: String) -> XCUIElement {
        let e = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(e.waitForExistence(timeout: 6), "missing \(identifier)")
        return e
    }
    /// A real touch in the middle of the element (shows the touch dot, and works in scroll views).
    private func touch(_ identifier: String) {
        let e = id(identifier)
        let deadline = Date().addingTimeInterval(4)
        while !e.isHittable && Date() < deadline { wait(0.1) }
        e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
    private func button(_ prefix: String) -> XCUIElement { app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch }
    /// A button whose label contains the text, else the text itself (rows that are tappable text).
    private func containing(_ text: String) -> XCUIElement {
        let b = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        if b.waitForExistence(timeout: 2) { return b }
        return app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Types in a few bursts (one keystroke per call is slow in XCUITest).
    private func type(_ text: String, into field: XCUIElement) {
        field.tap()
        wait(0.3)
        var rest = Substring(text)
        while !rest.isEmpty { let n = min(4, rest.count); field.typeText(String(rest.prefix(n))); rest = rest.dropFirst(n) }
    }

    /// Pulls a sheet down from its top edge until it closes.
    private func dismissSheet() {
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        top.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)), withVelocity: 1400, thenHoldForDuration: 0)
        wait(0.8)
    }

    /// A slow, readable scroll (a fast swipe flings the content).
    private func scroll(_ dy: CGFloat, duration: Double = 0.6) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -dy)), withVelocity: XCUIGestureVelocity(abs(dy) / duration), thenHoldForDuration: 0.1)
    }

    func testTour() throws {
        app.launchArguments = ["-apiBase", "http://localhost:8787", "-showTouches", "YES", "-resetSession", "YES", "-locale", "sr",
                               "-demoProject", "20"]
        app.launch()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 10))
        mark("start"); wait(1.2)

        // 1 · sign in
        mark("login")
        type("ana@habitly.app", into: app.textFields.firstMatch)
        wait(0.3)
        type("habitly-demo", into: app.textFields.element(boundBy: 1))
        wait(0.4)
        button("Prijavi se").tap()
        XCTAssertTrue(button("Izaberi projekat").waitForExistence(timeout: 10) || app.tabBars.firstMatch.waitForExistence(timeout: 5))
        mark("signedIn"); wait(2.2)

        // 2 · the project picker: from Focusly to Habitly
        mark("picker")
        touch("project-button")
        wait(1.8)
        touch("project-1")
        mark("picked"); wait(2.6)

        // 3 · ASO: the morning report, a keyword and its history
        mark("aso")
        scroll(260); wait(1.6)
        scroll(-260, duration: 0.5); wait(0.8)
        touch("tab-keywords")
        mark("keywords"); wait(2.0)
        touch("kw-daily planner")
        mark("history"); wait(3.2)
        dismissSheet()
        wait(1.0)

        // 4 · SEO: the action plan
        mark("seo")
        app.tabBars.buttons["SEO"].tap()
        wait(2.0)
        touch("action-a1")
        mark("action"); wait(1.4)
        scroll(300, duration: 0.8); wait(2.6)

        // 5 · AIO: what the assistants say, and one answer
        mark("aio")
        app.tabBars.buttons["AIO"].tap()
        wait(2.8)
        scroll(420, duration: 0.8); wait(1.2)
        touch("prompt-1")
        mark("answer"); wait(2.0)
        scroll(260, duration: 0.8); wait(2.4)
        dismissSheet()
        wait(1.0)

        // 6 · the knowledge base
        mark("kb")
        wait(0.6)
        touch("kb-button")
        wait(1.6)
        touch("kb-what-is-aio")
        mark("chapter"); wait(1.6)
        scroll(300, duration: 0.9); wait(2.0)
        mark("end"); wait(0.5)
    }
}
