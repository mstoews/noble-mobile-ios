//
//  OperatingStatementScreenshotTests.swift
//  nbledgerUITests
//
//  Walks the operating statement against the live tenant, read-only, so the
//  numbers can be checked against something a treasurer already trusts.
//

import XCTest

final class OperatingStatementScreenshotTests: XCTestCase {

    @MainActor
    func testOperatingStatement() throws {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "needs a logged-in session")
        tabBar.buttons["More"].tap()

        let row = app.staticTexts["Operating Statement"]
        if !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.navigationBars["Operating Statement"].waitForExistence(timeout: 10))
        sleep(6)
        attach(app, name: "OS1_month")

        // Year-to-date is where this tenant actually has activity.
        let ytd = app.buttons["YTD"]
        if ytd.waitForExistence(timeout: 5) {
            ytd.tap()
            sleep(4)
            attach(app, name: "OS2_ytd")
        }
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
