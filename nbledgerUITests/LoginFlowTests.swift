//
//  LoginFlowTests.swift
//  nbledgerUITests
//
//  Drives the email/password login form end-to-end against the live
//  server and records the outcome (error message vs. navigation).
//

import XCTest

final class LoginFlowTests: XCTestCase {

    @MainActor
    func testEmailPasswordLoginFlow() throws {
        let app = XCUIApplication()
        app.launch()

        let emailField = app.textFields["Email"]
        guard emailField.waitForExistence(timeout: 10) else {
            // Already logged in from a previous session — nothing to drive.
            attach(app, name: "00_already_logged_in")
            print("LOGIN_FLOW_STATE=already_logged_in")
            return
        }

        emailField.tap()
        emailField.typeText("probe@example.com")

        let passwordField = app.secureTextFields["Password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.tap()
        passwordField.typeText("wrongpassword")

        let companyField = app.textFields["Company ID"]
        XCTAssertTrue(companyField.waitForExistence(timeout: 5))
        companyField.tap()
        companyField.typeText("public")

        attach(app, name: "01_form_filled")

        let signIn = app.buttons["Sign In"]
        XCTAssertTrue(signIn.isEnabled, "Sign In should be enabled once the form is complete")
        signIn.tap()

        // Wait for a terminal state: an error message on the login screen,
        // or the tab bar (meaning the app treated the login as successful).
        let tabBar = app.tabBars.firstMatch
        var state = "timeout"
        var errorText = ""
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            if tabBar.exists { state = "navigated_to_main"; break }
            let errors = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] 'failed' OR label CONTAINS[c] 'error' OR label CONTAINS[c] 'invalid' OR label CONTAINS[c] 'HTTP'")
            )
            if errors.count > 0 {
                state = "error_shown"
                errorText = errors.firstMatch.label
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        sleep(2)
        attach(app, name: "02_after_sign_in")

        print("LOGIN_FLOW_STATE=\(state) ERROR_TEXT=\(errorText)")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
