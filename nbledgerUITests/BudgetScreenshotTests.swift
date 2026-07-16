//
//  BudgetScreenshotTests.swift
//  nbledgerUITests
//
//  Drives the new Budget screen (More → Planning → Budget) and captures each
//  segment — Overview (KPIs + charts), Analysis (variance), Forecast — for
//  visual verification. Requires a logged-in session in the simulator.
//

import XCTest

final class BudgetScreenshotTests: XCTestCase {

    @MainActor
    func testBudgetScreens() throws {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15),
                      "Tab bar should appear — is the simulator session logged in?")

        tabBar.buttons["More"].tap()
        XCTAssertTrue(app.navigationBars["More"].waitForExistence(timeout: 10))

        let budgetRow = app.staticTexts["Budget"]
        if !budgetRow.isHittable { app.swipeUp() }
        XCTAssertTrue(budgetRow.waitForExistence(timeout: 5), "Budget row should exist in More")
        budgetRow.tap()

        XCTAssertTrue(app.navigationBars["Budget"].waitForExistence(timeout: 10),
                      "Budget row should push a screen titled Budget")
        // Allow the account fetch + report derivation to settle.
        sleep(4)
        attach(app, name: "01_budget_overview")

        let segments = app.segmentedControls.firstMatch
        XCTAssertTrue(segments.waitForExistence(timeout: 5), "Budget should have a segmented control")

        segments.buttons["Analysis"].tap()
        sleep(2)
        attach(app, name: "02_budget_analysis")

        segments.buttons["Forecast"].tap()
        sleep(2)
        attach(app, name: "03_budget_forecast")

        // Drill into a forecast line for the 12-month breakdown.
        let firstLine = app.staticTexts["Status Certificate Fees"].firstMatch
        if firstLine.waitForExistence(timeout: 3) {
            firstLine.tap()
            _ = app.navigationBars["Status Certificate Fees"].waitForExistence(timeout: 6)
            sleep(2)
            attach(app, name: "04_budget_line_detail")
        }
    }

    @MainActor
    func testBudgetEditor() throws {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15),
                      "Tab bar should appear — is the simulator session logged in?")

        tabBar.buttons["More"].tap()
        XCTAssertTrue(app.navigationBars["More"].waitForExistence(timeout: 10))

        let budgetRow = app.staticTexts["Budget"]
        if !budgetRow.isHittable { app.swipeUp() }
        XCTAssertTrue(budgetRow.waitForExistence(timeout: 5))
        budgetRow.tap()
        XCTAssertTrue(app.navigationBars["Budget"].waitForExistence(timeout: 10))

        // Open the Maintenance editor via the toolbar button.
        app.buttons["Edit Budget"].tap()
        XCTAssertTrue(app.navigationBars["Edit Budget"].waitForExistence(timeout: 10),
                      "Edit Budget button should push the editor")
        sleep(5)   // funds + per-fund budget + prior actuals
        attach(app, name: "05_budget_editor")

        // Drill into an account by tapping its name (the NavigationLink label).
        let firstAccount = app.staticTexts["Condo Fees - Operating"].firstMatch
        if firstAccount.waitForExistence(timeout: 5) {
            firstAccount.tap()
            XCTAssertTrue(app.buttons["Generate from prior year"].waitForExistence(timeout: 8),
                          "Account editor should show the Generate action")
            sleep(1)
            attach(app, name: "06_account_editor")

            // Type an annual and Spread it (local only — does NOT save) so the
            // month grid visibly fills via the seasonal curve.
            let annualField = app.textFields.firstMatch
            if annualField.waitForExistence(timeout: 3) {
                annualField.tap()
                annualField.typeText("12000")
                app.buttons["Spread across 12 months"].tap()
                sleep(1)
                attach(app, name: "07_account_editor_spread")
            }
        }
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
