//
//  CaptureLoopUITests.swift
//  nbledgerUITests
//
//  Drives the Phase-3 capture loop end to end: Capture cover → manual bill
//  form → Create Bill → "View in Payment Sign-Off" → lands in the sign-off
//  queue with the success banner and the new PENDING draft. Cleans up by
//  deleting the created journal. Requires a logged-in session.
//

import XCTest

final class CaptureLoopUITests: XCTestCase {

    private let testDescription = "Capture loop verification"

    @MainActor
    func testCaptureLoopLandsInSignOffQueue() throws {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15),
                      "Tab bar should appear — is the simulator session logged in?")

        // Open the capture cover and switch to the manual form.
        tabBar.buttons["Capture"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 10),
                      "Capture flow should present full-screen")
        app.buttons["Manual"].tap()

        // Fill the bill form.
        let invoiceField = app.textFields["Invoice Number"]
        XCTAssertTrue(invoiceField.waitForExistence(timeout: 10))
        invoiceField.tap()
        invoiceField.typeText("CAP-LOOP-TEST-1")

        let amountField = app.textFields["Amount"]
        amountField.tap()
        amountField.typeText("1.23")

        let descriptionField = app.textFields["Description"]
        descriptionField.tap()
        descriptionField.typeText(testDescription + "\n") // return dismisses the keyboard

        app.swipeUp()

        let vendorButton = app.buttons["Select a vendor"]
        XCTAssertTrue(vendorButton.waitForExistence(timeout: 15),
                      "Vendor reference data should load")
        if !vendorButton.isHittable { app.swipeUp() }
        vendorButton.tap()
        // Rows are Buttons inside cells — tap the row's text, not the cell.
        pickSheetRow(app, preferred: "BC Hydro")
        XCTAssertTrue(app.buttons["Select a vendor"].waitForNonExistence(timeout: 5),
                      "Vendor sheet should dismiss after selection")

        // Vendor defaults may prefill the account; pick whatever is still empty.
        if app.buttons["Select a fund"].waitForExistence(timeout: 2) {
            let fundButton = app.buttons["Select a fund"]
            if !fundButton.isHittable { app.swipeUp() }
            fundButton.tap()
            pickSheetRow(app, preferred: "OPER")
            sleep(1)
        }
        if app.buttons["Select an account"].exists {
            let accountButton = app.buttons["Select an account"]
            if !accountButton.isHittable { app.swipeUp() }
            accountButton.tap()
            pickSheetRow(app, preferred: "Hydro / Electricity")
            sleep(1)
        }

        app.swipeUp()
        let createButton = app.buttons["Create Bill"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        attach(app, name: "01_filled_form")
        createButton.tap()

        // Saved state offers the loop-closing action.
        let viewInQueue = app.buttons["View in Journal Booking"]
        XCTAssertTrue(viewInQueue.waitForExistence(timeout: 25),
                      "Bill should save and show the View in Journal Booking action")
        attach(app, name: "02_bill_saved")
        viewInQueue.tap()

        // Lands in Journal Booking: banner + the new draft as a bookable entry.
        XCTAssertTrue(app.navigationBars["Journal Booking"].waitForExistence(timeout: 10),
                      "The capture loop should land in the booking queue")
        XCTAssertTrue(app.staticTexts["Draft bill created — review and book it."].waitForExistence(timeout: 5),
                      "Success banner should show")
        XCTAssertTrue(app.staticTexts[testDescription].waitForExistence(timeout: 10),
                      "The new draft should appear as an open entry")
        attach(app, name: "03_booking_landing")

        cleanUpCreatedJournal(app)
    }

    /// Taps a row in a presented picker sheet: the preferred row when
    /// present, else the first button row in the sheet's list.
    @MainActor
    private func pickSheetRow(_ app: XCUIApplication, preferred: String?) {
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10), "Picker sheet should present")
        if let preferred {
            let row = list.staticTexts[preferred]
            if row.waitForExistence(timeout: 3) {
                row.tap()
                return
            }
        }
        let firstRowButton = list.buttons.firstMatch
        XCTAssertTrue(firstRowButton.waitForExistence(timeout: 5))
        firstRowButton.tap()
    }

    /// Deletes the journal the test created (newest row in Journals),
    /// guarded on its description so nothing else can be deleted.
    @MainActor
    private func cleanUpCreatedJournal(_ app: XCUIApplication) {
        app.navigationBars.buttons.firstMatch.tap()

        let journalsRow = app.staticTexts["Journals"]
        guard journalsRow.waitForExistence(timeout: 5) else { return }
        journalsRow.tap()
        guard app.navigationBars["Journals"].waitForExistence(timeout: 10) else { return }

        // Best-effort: delete every leftover test journal (earlier failed
        // runs included). Leftovers can also be removed in Journals by hand.
        for _ in 0..<3 {
            let firstCell = app.collectionViews.firstMatch.cells.firstMatch
            guard firstCell.waitForExistence(timeout: 10),
                  firstCell.label.contains(testDescription) else {
                print("CAPTURE_LOOP_CLEANUP=done_or_not_first (first cell: \(firstCell.exists ? firstCell.label : "none"))")
                break
            }
            firstCell.tap()

            let deleteButton = app.buttons["Delete Journal"]
            if !deleteButton.waitForExistence(timeout: 10) {
                app.swipeUp()
            }
            guard deleteButton.exists else {
                print("CAPTURE_LOOP_CLEANUP=skipped (no delete button)")
                return
            }
            deleteButton.tap()
            let confirmDelete = app.buttons["Delete"]
            guard confirmDelete.waitForExistence(timeout: 5) else { return }
            confirmDelete.tap()
            sleep(2)
            print("CAPTURE_LOOP_CLEANUP=deleted")
        }
        attach(app, name: "04_cleanup_done")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
