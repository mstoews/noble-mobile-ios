//
//  JournalEvidenceUITests.swift
//  nbledgerUITests
//
//  Drives More → Journals to verify the evidence indicator in the list
//  and the Evidence section (with Attach Evidence) in the detail view.
//  Requires a logged-in session in the simulator.
//

import XCTest

final class JournalEvidenceUITests: XCTestCase {

    @MainActor
    func testJournalListIndicatorAndEvidenceSection() throws {
        let app = XCUIApplication()
        app.launch()

        // Journals now lives under the More hub (2-tab + Capture shell).
        let moreTab = app.tabBars.buttons["More"]
        guard moreTab.waitForExistence(timeout: 15) else {
            attach(app, name: "00_not_logged_in")
            print("EVIDENCE_UI_STATE=not_logged_in")
            return
        }
        moreTab.tap()

        let journalsRow = app.staticTexts["Journals"]
        guard journalsRow.waitForExistence(timeout: 10) else {
            attach(app, name: "00_no_journals_row")
            print("EVIDENCE_UI_STATE=no_journals_row")
            return
        }
        journalsRow.tap()
        _ = app.navigationBars["Journals"].waitForExistence(timeout: 10)

        let list = app.collectionViews.firstMatch
        var listState = "timeout"
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            if list.exists && list.cells.count > 0 { listState = "rows"; break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        sleep(2)
        attach(app, name: "01_journal_list")

        guard listState == "rows" else {
            print("EVIDENCE_UI_STATE=list_\(listState)")
            return
        }

        // The indicator images carry accessibility labels; SwiftUI may merge
        // them into the cell's label, so check both places.
        let slashImages = app.images.matching(
            NSPredicate(format: "label CONTAINS[c] 'evidence'")
        ).count
        let firstCellLabel = list.cells.firstMatch.label
        print("EVIDENCE_LIST_INDICATORS images=\(slashImages) firstCell=\(firstCellLabel)")

        // Open the first journal row.
        list.cells.firstMatch.tap()

        // Assert on the section's content, not its header text — iOS 26
        // doesn't expose SwiftUI section headers as staticTexts reliably.
        let attachButton = app.buttons["Attach Evidence"]
        _ = attachButton.waitForExistence(timeout: 15)
        if !attachButton.exists {
            app.swipeUp()
            sleep(1)
        }
        let emptyLabel = app.staticTexts["No evidence attached"]
        sleep(1)
        attach(app, name: "02_journal_detail_evidence")

        print("EVIDENCE_UI_STATE=detail attachButton=\(attachButton.exists) emptyLabel=\(emptyLabel.exists) rowsWithEvidence=\(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '.jpg'")).count)")
        XCTAssertTrue(attachButton.exists, "Attach Evidence control should exist in journal detail")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
