//
//  PreviewTours.swift
//  seenlabUITests
//
//  The three App Store preview tours (ASO, SEO, AIO), in English against the demo API. Each prints
//  `TOUR <step> <unix time>`; seenlab-client/tools/app-video/record.sh records the simulator meanwhile, and the
//  preview film (src/tools/preview) cuts and paces the recording to 30 seconds.
//

import XCTest

class TourCase: XCTestCase {
    let app = XCUIApplication()

    func mark(_ name: String) { print("TOUR \(name) \(Date().timeIntervalSince1970)") }
    func wait(_ s: Double) { Thread.sleep(forTimeInterval: s) }

    func launch(tab: String) {
        app.launchArguments = ["-apiBase", "http://localhost:8787", "-debugToken", "demo", "-resetSession", "YES", "-demoProject", "1",
                               "-locale", "en", "-showTouches", "YES", "-startTab", tab]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["project-button"].waitForExistence(timeout: 12))
        wait(2.0)
        mark("start")
    }

    func id(_ identifier: String) -> XCUIElement {
        let e = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(e.waitForExistence(timeout: 6), "missing \(identifier)")
        return e
    }

    func touch(_ identifier: String) {
        let e = id(identifier)
        let deadline = Date().addingTimeInterval(4)
        while !e.isHittable && Date() < deadline { wait(0.1) }
        e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// A channel tab; swipes the tab strip (from the `strip` tab's row) until it's on screen.
    func tab(_ key: String, strip: String) {
        let e = app.descendants(matching: .any)["tab-" + key].firstMatch
        XCTAssertTrue(e.waitForExistence(timeout: 6))
        let onScreen = { e.frame.minX >= 8 && e.frame.maxX <= self.app.frame.width - 8 && e.frame.width > 0 }
        var tries = 0
        while !onScreen() && tries < 4 {
            let y = id("tab-" + strip).frame.midY / app.frame.height
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: y)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: y)), withVelocity: 900, thenHoldForDuration: 0.2)
            wait(0.5); tries += 1
        }
        e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    func scroll(_ dy: CGFloat, duration: Double = 0.7) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: dy > 0 ? 0.74 : 0.3))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -dy)), withVelocity: XCUIGestureVelocity(abs(dy) / duration), thenHoldForDuration: 0.25)
    }

    /// Back to the top by tapping the status bar (iOS scrolls to the top; a pull past the top would refresh).
    func toTop() { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.012)).tap(); wait(0.9) }

    func dismissSheet() {
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        top.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)), withVelocity: 1400, thenHoldForDuration: 0)
        wait(0.9)
    }
}

final class PreviewTours: TourCase {
    func testASO() throws {
        launch(tab: "aso")
        mark("overview"); wait(2.6)
        scroll(330); wait(2.2)
        toTop()
        touch("tab-keywords"); wait(0.5); mark("keywords"); wait(1.8)
        scroll(240); wait(1.6)
        touch("kw-daily planner"); wait(0.5); mark("history"); wait(3.6)
        dismissSheet()
        toTop()
        touch("tab-competitors"); wait(0.5); mark("competitors"); wait(2.2)
        scroll(300); wait(1.8)
        toTop()
        tab("ai", strip: "keywords"); wait(0.5); mark("ai"); wait(2.0)
        scroll(300); wait(2.4)
        scroll(320); wait(2.2)
        mark("end"); wait(0.4)
    }

    func testSEO() throws {
        launch(tab: "seo")
        mark("plan"); wait(1.6)
        touch("action-a1"); wait(1.8)
        scroll(360); wait(2.4)
        toTop()
        touch("tab-audit"); wait(0.5); mark("audit"); wait(2.6)
        scroll(320); wait(1.8)
        toTop()
        tab("lab", strip: "plan"); wait(0.5); mark("lab"); wait(2.6)
        scroll(340); wait(2.0)
        toTop()
        tab("ai", strip: "plan"); wait(0.5); mark("ai"); wait(2.6)
        toTop()
        tab("console", strip: "plan"); wait(0.5); mark("console"); wait(2.6)
        scroll(340); wait(2.4)
        mark("end"); wait(0.4)
    }

    func testAIO() throws {
        launch(tab: "aio")
        mark("header"); wait(2.8)
        scroll(430); wait(2.0)
        touch("prompt-1"); wait(0.5); mark("answer"); wait(2.6)
        scroll(280); wait(2.2)
        dismissSheet()
        toTop()
        touch("tab-rivals"); wait(0.5); mark("rivals"); wait(2.4)
        scroll(360); wait(1.8)
        toTop()
        tab("sources", strip: "prompts"); wait(0.5); mark("sources"); wait(1.6)
        scroll(220); wait(2.6)
        toTop()
        tab("accuracy", strip: "prompts"); wait(0.5); mark("accuracy"); wait(1.8)
        scroll(300); wait(2.4)
        toTop()
        tab("pages", strip: "prompts"); wait(0.5); mark("pages"); wait(1.8)
        scroll(300); wait(2.0)
        mark("end"); wait(0.4)
    }
}
