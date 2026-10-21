//
//  FrameShot.swift
//  seenlabUITests
//
//  One screenshot of the whole board (the campaign frames, the lanes), against the local API, saved where the host
//  can read it: SL_SHOT=/path/to.png. A check, not a test of behaviour.
//

import XCTest

final class FrameShot: XCTestCase {
    func testShot() throws {
        let app = XCUIApplication()
        let env = ProcessInfo.processInfo.environment
        app.launchArguments = ["-apiBase", "http://localhost:86", "-debugToken", env["SL_TOKEN"] ?? "", "-resetSession", "YES", "-startTab", "growth", "-locale", "sr"]
        addUIInterruptionMonitor(withDescription: "notifications") { alert in
            if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }
            if alert.buttons["Don’t Allow"].exists { alert.buttons["Don’t Allow"].tap(); return true }
            return false
        }
        app.launch()
        let card = app.descendants(matching: .any)["card-ph"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20), "the board did not open")
        app.tap()   // lets the interruption monitor handle the alert
        Thread.sleep(forTimeInterval: 1)
        app.buttons["Uklopi tablu"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 1.5)
        if let path = env["SL_SHOT"] { try app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: path)) }
        if let path = env["SL_SHOT2"] {
            app.descendants(matching: .any)["growth-canvas"].firstMatch.pinch(withScale: 2.2, velocity: 2)
            Thread.sleep(forTimeInterval: 1.2)
            try app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: path))
        }
    }
}
