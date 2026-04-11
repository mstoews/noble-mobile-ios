# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Noble Ledger Mobile (nbledger) — a SwiftUI iOS app for the Noble Ledger accounting platform. Provides a full-featured mobile accounting experience: chart of accounts, general ledger journals, accounts payable/receivable, invoice capture with AI, bank connections via Plaid, and an AI chat assistant.

## Build & Run

This is an Xcode project (not SPM-based for the app target). Open `nbledger.xcodeproj` in Xcode to build and run.

```bash
# Build from CLI
xcodebuild -project nbledger.xcodeproj -scheme nbledger -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run tests
xcodebuild -project nbledger.xcodeproj -scheme nbledger -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Swift 6 language mode is enabled (`Package.swift` declares `.v6`). The Plaid Link SDK is pulled via SPM (`plaid-link-ios-spm` v6+).

## Architecture

**App entry**: `nbledgerApp.swift` — creates a single `APIService` instance and injects it via SwiftUI `@Environment`.

**Navigation flow**: `ContentView` is the root. It gates on login state and optional biometric unlock, then shows `MainView` which is a `TabView` with 8 tabs. A floating button opens `AgentChatView` as a sheet from any tab.

**API layer**: `APIService.swift` contains all models and networking in a single file:
- `@Observable` class using `async/await` with `URLSession`
- Base URL configurable between `localhost:8080` (dev) and `api.nobleledger.com` (prod)
- Login endpoint: `https://api.nobleledger.com/api/login` (in `LoginView`)
- Token refresh: `https://api.nobleledger.com/api/token/refresh`
- Automatic 401 → token refresh → retry flow; session expiry triggers biometric re-auth
- All JSON keys use `snake_case`; Swift models use `camelCase` with `CodingKeys`
- `FlexibleDouble` decoding handles Go `pgtype.Numeric` (JSON string or number)

**Auth**: Firebase-style auth (email/password → `idToken` + `refreshToken`). Tokens stored in `UserDefaults`/`@AppStorage`. Biometric (Face ID/Touch ID) optional lock screen via `LocalAuthentication`. On JWT expiry, the app locks to the biometric screen and refreshes the token after Face ID — no password re-entry needed.

## Views by Tab

### 1. Dashboard (`MainView.swift` → `DashboardView`)
Live data-driven dashboard with 6 widgets computed from API data:
- **Financial Summary** — 2x2 grid: Total Assets, Liabilities, Equity, Net Position (from account balances by `acctType`)
- **AR Aging** — Collapsible: Outstanding/Overdue/Due-in-7-days KPIs, received this month, aging bucket progress bars (Current, 1-30, 31-60, 61-90, 90+)
- **AP Aging** — Same pattern for payables
- **Cash Flow** — Current month net with trend arrow, sparkline bars for last 6 months (revenue minus expenses from period columns)
- **Budget vs Actual (YTD)** — Revenue/Expenses actual vs budget with progress bars and variance %
- **Open Journals** — Count and total of unbooked journal entries
- **Recent Entries** — Last 5 journal headers

### 2. Accounts (`LedgerView.swift`)
Hierarchical chart of accounts grouped by:
- `acctType` (Asset → Liability → Equity → Revenue → Expense) with section totals
- `subType` as collapsible `DisclosureGroup` sorted by account number, with subtotals
- Parent `account` with aggregate balance
- Child accounts indented underneath
- Pull-to-refresh, loading/error/empty states

### 3. Journals (`GLJournalView.swift`)
Full general ledger journal management:
- **List view** with segmented filter (All/Open/Booked/Closed)
- **Detail view** (`GLJournalDetailView`) — header info, amounts with debit/credit balance check, journal lines, evidence attachments
- **Actions** — Book journal, Close journal, Clone as template, Delete
- **Create** (`CreateJournalSheet`) — template picker, header fields, editable detail lines with add/remove rows and live balance validation
- **Clone** (`CloneJournalSheet`) — clone a journal as a reusable template
- API: 17+ endpoints for CRUD, booking, cloning, templates, evidence

### 4. Invoices (`InvoicesView.swift`)
AP invoice capture with AI processing:
- **Capture** — camera scan (VisionKit `VNDocumentCameraViewController`) or photo picker
- **AI Processing** — sends image to `/analyze_invoice` (Claude Vision) → extracts vendor, amount, dates, invoice #
- **Confirm** — review AI-extracted data, select vendor, submit
- **Manual** — manual invoice entry form with vendor picker
- **Payments** — list of existing payments with status badges
- Shared `FormField` component, `DocumentScannerView` (UIViewControllerRepresentable)

### 5. Payables (`APPayablesView.swift`)
Accounts Payable transaction management:
- **List** with segmented filter (All/Open/Paid/Closed)
- **Detail** (`APPaymentDetailView`) — payment info, amounts (GST/PST/adjustment/rebate), line items, transaction details, events history; loads all sections sequentially
- **Record Payment** (`RecordAPPaymentSheet`) — running total with amount/date
- **Create** (`CreateAPPaymentSheet`) — vendor picker, invoice #, amounts, dates
- Models: `Payment`, `PaymentEvent`, `PaymentDetail`, `PaymentTxnDetail`

### 6. Banking (`BankingView.swift`)
Plaid bank integration:
- Bank accounts list with balances (current/available)
- Transaction list filtered by selected account
- Account linking via `PlaidLinkFlow.swift` (`UIViewControllerRepresentable` wrapper for Plaid Link SDK)
- Connect flow initiated from Settings tab

### 7. Receivables (`ARReceivablesView.swift`)
Accounts Receivable transaction management:
- **List** with segmented filter (All/Open/Overdue/Closed)
- **Detail** (`ARTransactionDetailView`) — transaction info, amounts with remaining balance, line items (debit/credit)
- **Record Payment** (`RecordPaymentSheet`) — payment received with running total
- **Create** (`CreateARTransactionSheet`) — customer ID, amounts, dates
- Overdue filter calls dedicated server endpoint for date comparison
- Models: `ArTransaction`, `ArTransactionDetail`

### 8. Settings (`MainView.swift` → `SettingsView`)
- Account info display (name, email, company)
- Face ID / Touch ID toggle
- Connect Bank Account (triggers Plaid Link flow)
- Logout with confirmation

### Floating AI Chat (`AgentChatView.swift`)
- Accessible from any tab via floating button
- Conversational AI assistant via `/agent/chat` endpoint
- Message history with user/assistant roles
- Presented as a sheet over the current tab

### Auth & Login (`ContentView.swift`, `LoginView.swift`)
- `ContentView` — root view: manages login state, biometric lock screen, session expiry
- `LoginView` — email/password/company ID form → Firebase-style auth
- Biometric re-auth on session expiry without password re-entry
- Token persistence via `@AppStorage`

## Conventions

- All API models are `Codable` with explicit `CodingKeys` mapping `snake_case` ↔ `camelCase`
- Views access `APIService` via `@Environment(APIService.self)`
- State management uses `@State`, `@AppStorage`, and `@Observable` (no Combine/ObservableObject)
- iOS-only target (uses `UIImage`, `UIViewControllerRepresentable`)
- Avoid `async let` with mixed error handling — use sequential calls to prevent pthread/concurrency crashes
- Go `pgtype.Numeric` fields may serialize as JSON strings; use `decodeFlexibleDouble` for affected models
- All destructive actions use confirmation dialogs
