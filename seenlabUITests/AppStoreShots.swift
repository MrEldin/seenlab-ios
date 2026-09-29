//
//  AppStoreShots.swift
//  seenlabUITests
//
//  Walks the app to the ten screens used for the App Store screenshots (English, demo API). At each screen it
//  prints `SHOT <name>` and holds still; seenlab-client/tools/app-video/shots.sh takes the simulator screenshot.
//

import XCTest

final class AppStoreShots: XCTestCase {
    private let app = XCUIApplication()
    private func wait(_ s: Double) { Thread.sleep(forTimeInterval: s) }
    private func id(_ identifier: String) -> XCUIElement {
        let e = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(e.waitForExistence(timeout: 6), "missing \(identifier)")
        return e
    }
    private func touch(_ identifier: String) {
        let e = id(identifier)
        let deadline = Date().addingTimeInterval(4)
        while !e.isHittable && Date() < deadline { wait(0.1) }
        e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
    /// A channel tab: swipes the tab strip until the tab is on screen, then taps it.
    private func tab(_ key: String, strip: String) {
        let e = app.descendants(matching: .any)["tab-" + key].firstMatch
        XCTAssertTrue(e.waitForExistence(timeout: 6))
        var tries = 0
        let onScreen = { e.frame.minX >= 0 && e.frame.maxX <= self.app.frame.width && e.frame.width > 0 }
        while !onScreen() && tries < 4 {
            let row = id("tab-" + strip).frame.midY
            let y = row / app.frame.height
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: y)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: y)))
            wait(0.6); tries += 1
        }
        e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        wait(0.6)
    }
    private func shot(_ name: String) { wait(1.4); print("SHOT \(name)"); wait(2.2) }
    private func scroll(_ dy: CGFloat) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -dy)), withVelocity: 600, thenHoldForDuration: 0.4)
        wait(0.8)
    }
    private func dismissSheet() {
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        top.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)), withVelocity: 1400, thenHoldForDuration: 0)
        wait(1.0)
    }

    func testShots() throws {
        app.launchArguments = ["-apiBase", "http://localhost:8787", "-debugToken", "demo", "-resetSession", "YES", "-demoProject", "1", "-locale", "en"]
        app.launch()
        _ = id("project-button")

        shot("01-aso")
        touch("tab-keywords"); scroll(190); shot("02-keywords")
        touch("kw-daily planner"); wait(0.6); shot("03-history"); dismissSheet()
        scroll(-900); scroll(-900)
        tab("ai", strip: "keywords"); scroll(240); shot("04-ai")

        app.tabBars.buttons["SEO"].tap(); wait(1.5)
        touch("action-a1"); shot("05-plan")

        app.tabBars.buttons["AIO"].tap(); shot("06-aio")
        scroll(420); touch("prompt-1"); wait(0.8); shot("07-answer"); dismissSheet()
        scroll(-900); scroll(-900)
        tab("sources", strip: "prompts"); scroll(160); shot("08-sources")

        touch("project-button"); shot("09-projects")
        touch("project-1"); wait(1.2)
        touch("kb-button"); shot("10-kb")
    }
}
