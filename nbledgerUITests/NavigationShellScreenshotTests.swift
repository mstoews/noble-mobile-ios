//
//  NavigationShellScreenshotTests.swift
//  nbledgerUITests
//
//  Drives the Phase-1 navigation shell (Home · Activity · Capture · More)
//  end to end: every tab, the Capture full-screen cover, and each More-hub
//  destination. Attaches screenshots for visual verification.
//  Requires a logged-in session in the simulator.
//

import XCTest

final class NavigationShellScreenshotTests: XCTestCase {

    @MainActor
    func testShellNavigation() throws {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15),
                      "Tab bar should appear — is the simulator session logged in?")

        // The four tab slots of the new shell.
        XCTAssertTrue(tabBar.buttons["Home"].exists, "Home tab should exist")
        XCTAssertTrue(tabBar.buttons["Activity"].exists, "Activity tab should exist")
        XCTAssertTrue(tabBar.buttons["Capture"].exists, "Capture tab should exist")
        XCTAssertTrue(tabBar.buttons["More"].exists, "More tab should exist")
        sleep(2)
        attach(app, name: "01_home")

        // Activity tab + needs-sign-off segment.
        tabBar.buttons["Activity"].tap()
        XCTAssertTrue(app.navigationBars["Activity"].waitForExistence(timeout: 10))
        sleep(3)
        attach(app, name: "02_activity_all")

        let signOffSegment = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Needs sign-off'")
        ).firstMatch
        XCTAssertTrue(signOffSegment.waitForExistence(timeout: 5),
                      "Activity should have a Needs sign-off segment")
        signOffSegment.tap()
        sleep(1)
        attach(app, name: "03_activity_signoff")

        // Capture presents as a full-screen cover and dismisses via Close.
        tabBar.buttons["Capture"].tap()
        let closeButton = app.buttons["Close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 10),
                      "Capture flow should present full-screen with a Close button")
        sleep(1)
        attach(app, name: "04_capture_cover")
        closeButton.tap()
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5),
                      "Closing Capture should return to the tab shell")

        // More hub with profile card and badge rows.
        tabBar.buttons["More"].tap()
        XCTAssertTrue(app.navigationBars["More"].waitForExistence(timeout: 10))
        sleep(2)
        attach(app, name: "05_more_hub")

        // Push each hub destination and pop back.
        pushAndPop(app, row: "Payment Sign-Off", navTitle: "Payment Sign-Off", shot: "06_sign_off")
        pushAndPop(app, row: "Journal Booking", navTitle: "Journal Booking", shot: "07_journal_booking")
        pushAndPop(app, row: "Payables", navTitle: "Payables", shot: "08_payables")
        pushAndPop(app, row: "Receivables", navTitle: "Receivables", shot: "09_receivables")
        pushAndPop(app, row: "Banking", navTitle: "Banking", shot: "10_banking")
        pushAndPop(app, row: "Journals", navTitle: "Journals", shot: "11_journals")
        pushAndPop(app, row: "Chart of Accounts", navTitle: "Accounts", shot: "12_accounts")
        pushAndPop(app, row: "Settings", navTitle: "Settings", shot: "13_settings")

        // Assistant opens as a sheet from the More hub.
        let assistantRow = app.staticTexts["AI Assistant"]
        if !assistantRow.isHittable { app.swipeUp() }
        XCTAssertTrue(assistantRow.waitForExistence(timeout: 5), "AI Assistant row should exist")
        assistantRow.tap()
        sleep(2)
        attach(app, name: "14_assistant_sheet")
    }

    @MainActor
    private func pushAndPop(_ app: XCUIApplication, row: String, navTitle: String, shot: String) {
        let rowText = app.staticTexts[row]
        if !rowText.isHittable { app.swipeUp() }
        XCTAssertTrue(rowText.waitForExistence(timeout: 5), "\(row) row should exist in More")
        rowText.tap()
        XCTAssertTrue(app.navigationBars[navTitle].waitForExistence(timeout: 10),
                      "\(row) should push a screen titled \(navTitle)")
        sleep(2)
        attach(app, name: shot)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["More"].waitForExistence(timeout: 5),
                      "Back should return to the More hub")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
