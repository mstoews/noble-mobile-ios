//
//  FundPositionScreenshotTests.swift
//  nbledgerUITests
//
//  Walks the fund position report against the live tenant, read-only. The
//  point of running it live is the targeted/untargeted split: fixtures can
//  show it, but only the real `fund_targets_list` proves the two funds that
//  have no target actually land in the second section.
//

import XCTest

final class FundPositionScreenshotTests: XCTestCase {

    @MainActor
    func testFundPosition() throws {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "needs a logged-in session")
        tabBar.buttons["More"].tap()

        let row = app.staticTexts["Fund Position"]
        if !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.navigationBars["Fund Position"].waitForExistence(timeout: 10))

        // One trial balance per fund, sequentially — slower to settle than a
        // single-call screen.
        sleep(12)
        attach(app, name: "FP1_top")

        app.swipeUp()
        sleep(2)
        attach(app, name: "FP2_untargeted")
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
