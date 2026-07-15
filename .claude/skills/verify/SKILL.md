---
name: verify
description: Verify nbledger changes by driving the app in the iOS Simulator — build/launch/screenshot via run-nbledger-ios, tap-driving via XCUITest screenshot tests.
---

# Verifying nbledger changes

## Build / launch / screenshot

Use the existing driver (run with `bash`, it is not executable):

```bash
bash .claude/skills/run-nbledger-ios/run.sh build     # builds into build/dd
bash .claude/skills/run-nbledger-ios/run.sh launch    # boot sim + install + launch
bash .claude/skills/run-nbledger-ios/run.sh shot out.png
```

## Getting a logged-in session

The app needs a live session against api.nobleledger.com; a fresh install
lands on the login screen and there are no CLI credentials. Transplant a
session from another simulator that has one:

```bash
# 1. Find logged-in sessions (isLoggedIn=true)
find ~/Library/Developer/CoreSimulator/Devices -name "com.nobleledger.nbl.plist" -path "*Preferences*"
/usr/libexec/PlistBuddy -c 'Print :isLoggedIn' <plist>   # and :userEmail

# 2. Copy into the booted sim's app container and relaunch
xcrun simctl terminate booted com.nobleledger.nbl
DEST=$(xcrun simctl get_app_container booted com.nobleledger.nbl data)
cp <src-plist> "$DEST/Library/Preferences/com.nobleledger.nbl.plist"
xcrun simctl launch booted com.nobleledger.nbl
```

Expired JWTs are fine — APIService refreshes via securetoken.googleapis.com
using the stored refresh token. If `biometricEnabled` is true in the source
plist the app will demand Face ID; prefer a source session without it.

## Tap-driving

`simctl` cannot tap. The repo convention is XCUITest screenshot tests
(`nbledgerUITests/*ScreenshotTests.swift`) — add/aim one at the flow, run it
on the booted (logged-in) simulator, then export its screenshots:

```bash
xcodebuild -project nbledger.xcodeproj -scheme nbledger \
  -destination "platform=iOS Simulator,id=<booted-id>" \
  -derivedDataPath build/dd -resultBundlePath build/uitest.xcresult \
  -only-testing:nbledgerUITests/<TestClass> test
xcrun xcresulttool export attachments --path build/uitest.xcresult --output-path <dir>
# manifest.json in <dir> maps exportedFileName -> suggestedHumanReadableName
```

`NavigationShellScreenshotTests` drives the whole tab shell + every More
destination — a good template.

## Gotchas

- List rows are reached with `app.staticTexts["<row title>"]`, tabs with
  `app.tabBars.buttons["<tab>"]`.
- SourceKit diagnostics in this VS Code session routinely fail to resolve
  module-internal types (e.g. "Cannot find 'APIService' in scope") — trust
  `xcodebuild`, not the live diagnostics.
