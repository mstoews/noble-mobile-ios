//
//  ApprovalScreensScreenshotTests.swift
//  nbledgerUITests
//
//  Drives the More tab to the Payment Sign-Off and Journal Booking screens
//  and attaches screenshots for visual verification.
//

import XCTest

final class ApprovalScreensScreenshotTests: XCTestCase {

    @MainActor
    func testCaptureApprovalScreens() throws {
        let app = XCUIApplication()
        app.launch()

        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10), "More tab should exist")
        moreTab.tap()
        attach(app, name: "01_more_tab")

        let signOffCard = app.staticTexts["Payment Sign-Off"]
        XCTAssertTrue(signOffCard.waitForExistence(timeout: 5), "Payment Sign-Off card should exist")
        signOffCard.tap()
        XCTAssertTrue(app.navigationBars["Payment Sign-Off"].waitForExistence(timeout: 10))
        sleep(2)
        attach(app, name: "02_payment_sign_off")

        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)

        let bookingCard = app.staticTexts["Journal Booking"]
        XCTAssertTrue(bookingCard.waitForExistence(timeout: 5), "Journal Booking card should exist")
        bookingCard.tap()
        XCTAssertTrue(app.navigationBars["Journal Booking"].waitForExistence(timeout: 10))
        sleep(2)
        attach(app, name: "03_journal_booking")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
