# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Noble Ledger Mobile (nbledger) — a SwiftUI iOS app for the Noble Ledger accounting platform. Provides journal entries, ledger views, invoice capture (camera + Claude Vision AI), Plaid bank connections, and an AI chat agent.

## Build & Run

This is an Xcode project (not SPM-based for the app target). Open `nbledger.xcodeproj` in Xcode to build and run.

```bash
# Build from CLI
xcodebuild -project nbledger.xcodeproj -scheme nbledger -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests
xcodebuild -project nbledger.xcodeproj -scheme nbledger -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Swift 6 language mode is enabled (`Package.swift` declares `.v6`). The Plaid Link SDK is pulled via SPM (`plaid-link-ios-spm` v6+).

## Architecture

**App entry**: `nbledgerApp.swift` — creates a single `APIService` instance and injects it via SwiftUI `@Environment`.

**Navigation flow**: `ContentView` is the root. It gates on login state and optional biometric unlock, then shows `MainView` which is a `TabView` with 5 tabs: Dashboard, Ledger, Invoices, Banking, Settings. A floating button opens `AgentChatView` as a sheet.

**API layer**: `APIService.swift` contains all models and networking in a single file:
- `@Observable` class using `async/await` with `URLSession`
- Base URL: `https://api.nobleledger.com/public/v1` (authenticated endpoints) 
- Login endpoint: `https://api.nobleledger.com/api/login` (in `LoginView`)
- Token refresh: `https://api.nobleledger.com/api/token/refresh`
- Automatic 401 → token refresh → retry flow
- All JSON keys use `snake_case`; Swift models use `camelCase` with `CodingKeys`

**Auth**: Firebase-style auth (email/password → `idToken` + `refreshToken`). Tokens stored in `UserDefaults`/`@AppStorage`. Biometric (Face ID/Touch ID) optional lock screen via `LocalAuthentication`.

**Key features by view**:
- `InvoicesView` — camera/photo capture → sends image to `/analyze_invoice` (Claude Vision) → pre-fills payment form
- `BankingView` — Plaid Link integration for bank account/transaction viewing
- `PlaidLinkFlow` — `UIViewControllerRepresentable` wrapper for Plaid Link SDK
- `AgentChatView` — conversational AI via `/agent/chat` endpoint
- `LedgerView` — account list and journal headers

## Conventions

- All API models are `Codable` with explicit `CodingKeys` mapping `snake_case` ↔ `camelCase`
- Views access `APIService` via `@Environment(APIService.self)`
- State management uses `@State`, `@AppStorage`, and `@Observable` (no Combine/ObservableObject)
- iOS-only target (uses `UIImage`, `UIViewControllerRepresentable`)
