//
//  AccountsPageScreenshotTests.swift
//  nbledgerUITests
//
//  Drives More → Chart of Accounts and attaches a screenshot to verify
//  GL accounts are visible.
//

import XCTest

final class AccountsPageScreenshotTests: XCTestCase {

    @MainActor
    func testAccountsPageShowsGLAccounts() throws {
        let app = XCUIApplication()
        app.launch()

        // Chart of Accounts now lives under the More hub (2-tab + Capture shell).
        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 15),
                      "More tab should exist — if not, the app is stuck on login")
        moreTab.tap()

        let accountsRow = app.staticTexts["Chart of Accounts"]
        XCTAssertTrue(accountsRow.waitForExistence(timeout: 10),
                      "Chart of Accounts row should exist in the More hub")
        accountsRow.tap()
        _ = app.navigationBars["Accounts"].waitForExistence(timeout: 10)

        // Wait for one of the terminal states: account list, empty state, or error.
        let list = app.collectionViews.firstMatch
        let empty = app.staticTexts["No accounts found."]
        let retry = app.buttons["Retry"]

        var state = "timeout"
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            if empty.exists { state = "empty"; break }
            if retry.exists { state = "error"; break }
            if list.exists && list.cells.count > 0 { state = "accounts"; break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        sleep(2)

        attach(app, name: "01_accounts_page")

        if state == "accounts" {
            // Scroll once to capture more of the chart of accounts.
            app.swipeUp()
            sleep(1)
            attach(app, name: "02_accounts_page_scrolled")
        }

        print("ACCOUNTS_PAGE_STATE=\(state) VISIBLE_CELLS=\(list.exists ? list.cells.count : 0)")
        XCTAssertEqual(state, "accounts", "Accounts page did not show GL accounts (state: \(state))")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
