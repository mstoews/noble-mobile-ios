# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Noble Ledger Mobile (nbledger) — a SwiftUI iOS app for the Noble Ledger accounting platform. Provides a full-featured mobile accounting experience: chart of accounts, general ledger journals, accounts payable/receivable, vendor/customer maintenance, invoice capture with AI, bank connections via Plaid, and an AI chat assistant.

A full reverse-engineered specification lives at `docs/SPECIFICATION.md`.

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

**Navigation flow**: `ContentView` is the root. It gates on login state and optional biometric unlock, then shows `MainView` which is a `TabView` with **5 tabs**: Dashboard, Accounts, Journals, Invoices, and More. The More tab (`MoreView.swift`) is a custom 2-column grid of cards navigating to Payables, Banking, Receivables, and Settings. A floating button (bottom-right, all tabs) opens `AgentChatView` as a sheet.

**API layer**: `APIService.swift` contains all models and networking in a single file (~2,100 lines):
- `@Observable` class using `async/await` with `URLSession`
- Host is hardcoded to `https://api.nobleledger.com` with a commented-out `http://localhost:8080` line for local dev (manual edit to switch)
- Business endpoints are tenant-scoped: `{host}/{tenant}/v1/...` (slug `public` when tenant is empty)
- Login endpoint: `https://api.nobleledger.com/api/login` (in `LoginView`)
- Token refresh: `https://api.nobleledger.com/api/token/refresh`
- Automatic 401 → token refresh → retry flow; session expiry triggers biometric re-auth
- All JSON keys use `snake_case`; Swift models use `camelCase` with `CodingKeys`
- `FlexibleDouble` decoding handles Go `pgtype.Numeric` (JSON string or number)

**Auth**: Firebase-style auth (email/password + company ID → `idToken` + `refreshToken`). Tokens stored in `UserDefaults`/`@AppStorage`. Biometric (Face ID/Touch ID) optional lock screen via `LocalAuthentication`. On JWT expiry, the app locks to the biometric screen and refreshes the token after Face ID — no password re-entry needed.

## Views by Tab

### 1. Dashboard (`MainView.swift` → `DashboardView`)
Live data-driven dashboard with 7 widgets computed from API data:
- **Financial Summary** — 2x2 grid: Total Assets, Liabilities, Net Equity, Net Position (from account balances by `acctType`)
- **AR Aging** (`AgingWidget`) — Collapsible: Outstanding/Overdue/Due-in-7-days KPIs, received this month, aging bucket progress bars (Current, 1-30, 31-60, 61-90, 90+)
- **AP Aging** — Same shared `AgingWidget` for payables
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
- **Detail view** (`GLJournalDetailView`) — header info, amounts with debit/credit balance check (±0.005 tolerance), journal lines, evidence attachments
- **Actions** — Book journal, Close journal, Clone as template, Delete
- **Create** (`CreateJournalSheet`) — template picker, header fields, editable detail lines (minimum 2) with add/remove rows and live balance validation
- **Clone** (`CloneJournalSheet`) — clone a journal as a reusable template
- API: 17+ endpoints for CRUD, booking, cloning, templates, evidence

### 4. Invoices (`InvoicesView.swift`)
AP invoice capture with AI processing, four sub-tabs (Capture/Confirm/Manual/Payments):
- **Capture** — camera scan (VisionKit `VNDocumentCameraViewController`) or photo picker
- **AI Processing** — sends image to `/agent/analyze-invoice` (Claude Vision, server-side) → extracts vendor, amount, dates, invoice #
- **Confirm** — review AI-extracted data, vendor auto-matched by name with manual picker fallback, submit as OPEN payment
- **Manual** — manual invoice entry form with vendor picker
- **Payments** — read-only list of existing payments with status badges
- Shared `FormField` component, `DocumentScannerView` (UIViewControllerRepresentable)

### 5. More (`MoreView.swift`)
Custom grid screen housing the remaining features:

#### Payables (`APPayablesView.swift`)
- **List** with segmented filter (All/Open/Paid/Closed); toolbar links to Vendor Maintenance and Create
- **Detail** (`APPaymentDetailView`) — payment info, amounts (GST/PST/adjustment/rebate), line items, transaction details, events history; loads all sections sequentially
- **Record Payment** (`RecordAPPaymentSheet`) — cumulative `amountPaid` update; disabled when remaining ≤ 0
- **Create** (`CreateAPPaymentSheet`) — searchable vendor picker, invoice #, amounts, dates
- Models: `Payment`, `PaymentEvent`, `PaymentDetail`, `PaymentTxnDetail`

#### Banking (`BankingView.swift`)
- Bank accounts list with balances (current/available)
- Transaction list filtered by selected account
- Account linking via `PlaidLinkFlow.swift` (`UIViewControllerRepresentable` wrapper for Plaid Link SDK)
- Connect flow initiated from Settings

#### Receivables (`ARReceivablesView.swift`)
- **List** with segmented filter (All/Open/Overdue/Closed); "Open" includes both OPEN and PARTIAL; toolbar links to Customer Maintenance and Create
- **Detail** (`ARTransactionDetailView`) — transaction info, amounts with remaining balance, line items (debit/credit)
- **Record Payment** (`RecordPaymentSheet`) — cumulative `amountReceived` update; disabled when remaining ≤ 0
- **Create** (`CreateARTransactionSheet`) — customer ID, amounts, dates
- Overdue filter calls dedicated server endpoint for date comparison
- Models: `ArTransaction`, `ArTransactionDetail`

#### Settings (`MainView.swift` → `SettingsView`)
- Account info display (name, email, company)
- Face ID / Touch ID toggle
- Connect Bank Account (triggers Plaid Link flow)
- Logout with confirmation

### Vendor & Customer Maintenance (`VendorMaintenanceView.swift`, `CustomerMaintenanceView.swift`)
Master-data screens reached from the Payables/Receivables toolbars (not tabs):
- **List** with segmented filter (All/Active/Inactive), case-insensitive search, pull-to-refresh
- **Detail** — read-only sections: Contact, Address, Account Links (GL/VAT/AP-or-AR accounts), Info (type, status, terms)
- **Form sheet** (create/edit) — same sections; name required; status defaults to ACTIVE; audit fields stamped `createUser`/`updateUser` = "MOBILE"
- Models: `ApVendor`, `ArCustomer` (+ create/update request structs)

### Floating AI Chat (`AgentChatView.swift`)
- Accessible from any tab via floating button
- Conversational AI assistant via `/agent/chat` endpoint (SSE streaming; chunks appended to a placeholder assistant message)
- Message history with user/assistant roles; clear-history control
- Empty-state quick actions run client-side bulk operations: "Close all open journals" and "Book all open journals"
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
- Mobile writes stamp audit fields (`createUser`/`updateUser`/`userName`) as "MOBILE"
