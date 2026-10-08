//
//  GrowthBoardTests.swift
//  seenlabUITests
//
//  The growth board used like a person would, against the local API (debug build): open a card, move a card by
//  holding it, pin a note, zoom with two fingers, switch lenses. Needs a token: TEST_RUNNER_SL_TOKEN=<jwt>.
//

import XCTest

final class GrowthBoardTests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        let token = ProcessInfo.processInfo.environment["SL_TOKEN"] ?? ""
        app.launchArguments = ["-apiBase", "http://localhost:86", "-debugToken", token, "-startTab", "growth", "-locale", "sr"]
        app.launch()
    }

    private func el(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
    private func shot(_ name: String) { let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a); print("SHOT \(name)") }

    func testBoardLikeAPerson() {
        let site = el("card-site")
        XCTAssertTrue(site.waitForExistence(timeout: 15), "the board did not open")
        shot("board")

        // a tap opens the step
        site.tap()
        XCTAssertTrue(el("sheet-close").waitForExistence(timeout: 5), "the card did not open")
        shot("card")
        el("sheet-close").tap()
        Thread.sleep(forTimeInterval: 1)

        // hold the first card and move it to the bottom of its column
        let first = el("card-site")
        let target = first.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: 0, dy: 520))
        first.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.6, thenDragTo: target)
        Thread.sleep(forTimeInterval: 1.5)
        shot("moved")

        // pin a note
        el("add-note").tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'belešku' OR label CONTAINS[c] 'note'")).firstMatch.tap()
        let text = el("note-text")
        XCTAssertTrue(text.waitForExistence(timeout: 5), "the note did not open")
        text.tap()
        text.typeText("Pitati Milana za intro")
        el("note-close").tap()
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertTrue(app.staticTexts["Pitati Milana za intro"].firstMatch.exists || app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Pitati Milana'")).count > 0, "the note is not on the board")
        shot("note")

        // two fingers zoom out
        el("growth-canvas").pinch(withScale: 0.5, velocity: -1)
        Thread.sleep(forTimeInterval: 1)
        shot("zoomed")

        // lenses
        el("lens-status").tap(); Thread.sleep(forTimeInterval: 0.8); shot("status")
        el("lens-time").tap(); Thread.sleep(forTimeInterval: 0.8); shot("weeks")
        el("lens-map").tap()
        Thread.sleep(forTimeInterval: 2.5)   // the save runs a moment after the last edit
    }
}
