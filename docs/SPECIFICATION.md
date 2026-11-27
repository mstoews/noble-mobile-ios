# Noble Ledger Mobile (nbledger) — Application Specification

**Version:** 1.0
**Date:** 2026-06-10
**Platform:** iOS (SwiftUI, Swift 6 language mode)
**Status:** Reverse-engineered from source as of `main` (commit `aa918bc`)

---

## 1. Overview

Noble Ledger Mobile is a SwiftUI iOS client for the Noble Ledger accounting platform. It provides a full mobile accounting experience against the Noble Go API backend:

- Dashboard with live financial KPIs and aging analysis
- Chart of accounts (hierarchical, with balances)
- General ledger journal management (create, book, close, clone, delete)
- Accounts payable: invoices, vendor maintenance, payment recording
- Accounts receivable: transactions, customer maintenance, payment recording
- AP invoice capture via camera with Claude Vision AI extraction
- Bank account connections and transactions via Plaid
- Conversational AI assistant (server-side agent, SSE streaming)
- Firebase-style email/password auth with biometric (Face ID / Touch ID) lock

### 1.1 Technology Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI, iOS-only (`UIImage`, `UIViewControllerRepresentable`) |
| Concurrency | `async/await`, `URLSession`; `@Observable` (no Combine) |
| State | `@State`, `@AppStorage`, `@Environment` injection |
| Language | Swift 6 language mode (tools 6.3) |
| Dependencies | Plaid Link iOS SDK ≥ 6.0.0 (SPM: `plaid-link-ios-spm`) |
| Document capture | VisionKit (`VNDocumentCameraViewController`), PhotosPicker |
| Biometrics | LocalAuthentication (`LAContext`) |
| Build | `nbledger.xcodeproj` (app target is Xcode-managed, not SPM) |

### 1.2 Repository Layout

```
noble-mobile-ios/
├── nbledger/               # App source (16 Swift files, ~8,900 lines)
├── nbledger.xcodeproj/     # Xcode project (app target)
├── nbledgerTests/          # Unit test scaffolding (Swift Testing)
├── nbledgerUITests/        # UI test scaffolding (XCTest)
├── Package.swift           # SPM manifest (NBLMobile library + Plaid dep)
├── Sources/NBLMobile/      # SPM library target (placeholder)
└── docs/                   # Session notes, this spec
```

---

## 2. Architecture

### 2.1 App Entry & Composition

- `nbledgerApp.swift` (`@main`): creates a single `APIService` as `@State` and injects it into the view tree via `.environment(apiService)`. Single `WindowGroup`.
- Views access the service with `@Environment(APIService.self)`.

### 2.2 Navigation Flow

```
nbledgerApp
└── ContentView (root: login gate + biometric lock)
    ├── LoginView                  (if not logged in)
    ├── Biometric lock screen      (if locked / session expired)
    └── MainView (TabView, 5 tabs)
        ├── 1. Dashboard   (house)                → DashboardView
        ├── 2. Accounts    (list.bullet.rectangle)→ LedgerView
        ├── 3. Journals    (doc.text)             → GLJournalView
        ├── 4. Invoices    (doc.text.viewfinder)  → InvoicesView
        └── 5. More        (ellipsis.circle)      → MoreView
            ├── Payables    → APPayablesView  (→ VendorMaintenanceView)
            ├── Banking     → BankingView
            ├── Receivables → ARReceivablesView (→ CustomerMaintenanceView)
            └── Settings    → SettingsView
        └── Floating AI chat button (all tabs) → AgentChatView (sheet)
```

The floating chat button is a 56×56 gradient circle pinned bottom-right (20pt trailing, 70pt bottom) in a `ZStack` over the `TabView`; it presents `AgentChatView` as a sheet from any tab.

### 2.3 Conventions

- All API models are `Codable` with explicit `CodingKeys` mapping JSON `snake_case` ↔ Swift `camelCase`.
- Go `pgtype.Numeric` fields may arrive as JSON strings or numbers; a `FlexibleDouble` decoding helper on `KeyedDecodingContainer` handles both (used for `debit`, `credit`, `amount` fields).
- Sequential `await` calls preferred over `async let` with mixed error handling (avoids concurrency crashes).
- All destructive actions go through `confirmationDialog` with `.destructive` role.
- Consistent loading / error-with-retry / empty states on every list screen; pull-to-refresh throughout.

---

## 3. Authentication & Session Management

### 3.1 Login

`LoginView` form: **Email** (required, email keyboard), **Password** (SecureField), **Company ID** (required, becomes the tenant).

- Endpoint: `POST https://api.nobleledger.com/api/login`
- Body: `{ Email, Password, returnSecureToken: true }`
- Response: `{ idToken, refreshToken, user: { name, email }, company: { name } }`

### 3.2 Token Persistence (`@AppStorage` / `UserDefaults`)

| Key | Purpose |
|---|---|
| `isLoggedIn` | Primary login flag |
| `authToken` | JWT access token (`idToken`) |
| `refreshToken` | Refresh token |
| `tenant` | Company/tenant ID (used as URL slug) |
| `userName`, `userEmail`, `companyName` | Display info |
| `biometricEnabled` | Face ID / Touch ID lock toggle |

### 3.3 Token Refresh & 401 Handling

All authenticated requests send `Authorization: Bearer <token>`. On a 401:

1. `POST https://api.nobleledger.com/api/token/refresh` with `{ refreshToken }` → `{ idToken, refreshToken? }`.
2. Retry the original request with the new token.
3. If refresh fails and a refresh token exists → `onSessionExpired()` (biometric re-lock).
4. If no refresh token → `onUnauthorized()` (full logout).

### 3.4 Biometric Lock

- Lock screen shows when `isLoggedIn && (biometricEnabled || sessionExpired) && !isUnlocked`.
- Unlock via `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)`.
- On success: if the session expired (or token is empty), the app silently calls `refreshAccessToken()` — **no password re-entry** — then unlocks; on refresh failure it forces logout.
- On biometric failure: "Try Again" plus "Sign in with password" fallback.

### 3.5 Logout

Clears all tokens and user info from `APIService` and `@AppStorage`, resets `isLoggedIn` / `isUnlocked` / `sessionExpired`, and returns to `LoginView`. Requires confirmation in Settings.

---

## 4. API Layer (`APIService.swift`)

A single `@Observable` class containing all models and networking (~2,100 lines).

- **Base URL:** `https://api.nobleledger.com/{tenant}/v1` (falls back to slug `public` when tenant is empty). Dev variant `http://localhost:8080/{tenant}/v1` is toggled by editing the constant.
- **Auth endpoints** (login/refresh) live at the apex `/api/...` path, outside the tenant slug.
- **Error model:** `APIError` — `.unauthorized`, `.serverError(statusCode, message)`, `.decodingFailed`, `.networkError(Error)`.
- **Callbacks:** `onUnauthorized()` and `onSessionExpired()` wired up by `ContentView`.

### 4.1 Endpoint Inventory (~50 endpoints)

#### Accounts
| Method | Path | Returns |
|---|---|---|
| GET | `/account_list` | `[Account]` |

#### GL Journals — read
| Method | Path | Returns |
|---|---|---|
| GET | `/read_journal_header` | `[JournalHeader]` |
| GET | `/read_journal_header_by_id/{id}` | `JournalHeader` |
| POST | `/read_journal_header_by_period` | `[JournalHeader]` |
| POST | `/read_journal_list` (date range) | `[JournalHeader]` |
| GET | `/get_journal_detail/{journalId}` | `[JournalDetail]` |
| GET | `/read_open_journal_details` | `[JournalDetail]` |
| POST | `/read_transaction_by_account` | `[JournalDetail]` |
| POST | `/read_jrn_by_id` | `[JournalEntry]` |
| GET | `/get_latest_journal` | `JournalEntry` |
| GET | `/read_last_journal_no` | `{ journal_id }` |

#### GL Journals — write
| Method | Path | Body |
|---|---|---|
| POST | `/create_journal_header` | `CreateJournalHeaderRequest` → `{ journal_id }` |
| POST | `/create_journal` | `CreateFullJournalRequest` (header + lines) |
| POST | `/update_journal` | `CreateFullJournalRequest` |
| POST | `/create_journal_detail` | `CreateJournalDetailRequest` |
| POST | `/book_journal_entry` | `{ journalId, userName, period, year }` |
| POST | `/close_journal_entry` | `{ journalId, bookedUser }` |
| POST | `/delete_journal_entry` | `{ journalId }` |
| POST | `/clone_journal_entry` | `{ journalId, templateDescription }` |

#### Templates & Evidence
| Method | Path | Returns / Body |
|---|---|---|
| GET | `/read_templates` | `[JournalTemplate]` |
| GET | `/read_template/{reference}` | `JournalTemplate` |
| GET | `/read_evidence_by_journal/{journalId}` | `[GlEvidence]` |
| POST | `/create_evidence` | `CreateEvidenceRequest` |

#### Accounts Payable
| Method | Path | Returns / Body |
|---|---|---|
| GET | `/read_ap_transactions` | `[Payment]` |
| GET | `/read_vendors` | `[Vendor]` |
| GET | `/list_ap_vendors` | `[ApVendor]` |
| GET | `/get_ap_vendor/{id}` | `ApVendor` |
| GET | `/list_ap_vendors_by_status/{status}` | `[ApVendor]` |
| POST | `/create_ap_vendor` | `CreateApVendorRequest` |
| POST | `/update_ap_vendor` | `UpdateApVendorRequest` |
| DELETE | `/delete_ap_vendor/{id}` | — |

#### Payments
| Method | Path | Returns / Body |
|---|---|---|
| POST | `/create_payment` | `CreatePaymentRequest` |
| GET | `/read_payment/{id}` | `Payment` |
| POST | `/update_payment` | `UpdatePaymentRequest` |
| DELETE | `/delete_payment/{id}` | — |
| POST | `/read_payments_by_date` | `[Payment]` |
| GET | `/read_payment_events/{transactionId}` | `[PaymentEvent]` |
| GET | `/read_payment_details/{transactionId}` | `[PaymentDetail]` |
| GET | `/read_payment_txn_details/{transactionId}` | `[PaymentTxnDetail]` |

#### Accounts Receivable
| Method | Path | Returns / Body |
|---|---|---|
| GET | `/list_ar_customers` | `[ArCustomer]` |
| GET | `/get_ar_customer/{id}` | `ArCustomer` |
| GET | `/list_ar_customers_by_status/{status}` | `[ArCustomer]` |
| POST | `/create_ar_customer` | `CreateArCustomerRequest` |
| POST | `/update_ar_customer` | `UpdateArCustomerRequest` |
| DELETE | `/delete_ar_customer/{id}` | — |
| GET | `/list_ar_transactions` | `[ArTransaction]` |
| GET | `/get_ar_transaction/{id}` | `ArTransaction` |
| GET | `/list_ar_transactions_by_status/{status}` | `[ArTransaction]` |
| GET | `/list_overdue_ar_transactions` | `[ArTransaction]` (server-side date comparison) |
| POST | `/create_ar_transaction` | `CreateArTransactionRequest` |
| POST | `/update_ar_transaction_amount_received` | `{ id, amountReceived, datePaid, updateUser }` |
| POST | `/update_ar_transaction_status` | `{ id, status, updateUser }` |
| DELETE | `/delete_ar_transaction/{id}` | — |
| GET | `/list_ar_transaction_details_by_txn/{transactionId}` | `[ArTransactionDetail]` |

#### Banking / Plaid
| Method | Path | Returns / Body |
|---|---|---|
| POST | `/api/create_link_token` | `{ link_token }` |
| POST | `/api/exchange_public_token` | `{ public_token }` |
| GET | `/api/accounts` | `[BankAccount]` |
| GET | `/api/bank_transactions` | `[BankTransaction]` |

#### AI
| Method | Path | Behavior |
|---|---|---|
| POST | `/agent/chat` | SSE stream of `{ type: "text" \| "error" \| "done", content }` |
| POST | `/agent/analyze-invoice` | `{ image: <base64>, media_type: "image/jpeg" }` → `InvoiceExtraction` |

### 4.2 Core Data Models

| Domain | Models |
|---|---|
| GL | `Account` (balances, `period1–12`, `previous1–12`, `budget1–12`, `openingBalance`), `JournalHeader`, `JournalDetail`, `JournalEntry` (header + `details`), `JournalTemplate`, `JournalTemplateDetail`, `GlEvidence` |
| AP | `Payment` (amounts incl. GST/PST/adjustment/rebate; computed `remainingBalance = amount − amountPaid`), `PaymentEvent`, `PaymentDetail`, `PaymentTxnDetail`, `Vendor`, `ApVendor` |
| AR | `ArCustomer`, `ArTransaction` (`amountReceived`, `remainderAmt`, `adjustmentAmt`), `ArTransactionDetail` |
| Banking | `BankAccount` (current/available balances, mask, institution), `BankTransaction` (category array, pending flag) |
| AI | `ChatMessage` (role/content), `AgentRequest`, `InvoiceExtraction` (vendorName, invoiceNumber, amount, date, dueDate, description) |

Plus request structs for every write operation (create/update/book/close/clone/delete), all `snake_case`-mapped.

---

## 5. Functional Specification by Screen

### 5.1 Dashboard (`MainView.swift` → `DashboardView`)

Greets the user by name/company. Loads accounts, journal headers, AP payments, and AR transactions on appear; pull-to-refresh reloads everything. Seven widgets:

1. **Financial Summary** — 2×2 cards: Total Assets, Liabilities, Net Equity, Net Position, computed from `Account.balance` grouped by `acctType`; negatives shown red.
2. **AR Aging** — Outstanding (sum of open/partial remaining balances), overdue count/amount, due-within-7-days, received this month; expandable color-coded aging buckets: Current, 1–30, 31–60, 61–90, 90+ days past due (missing due dates fall into Current).
3. **AP Aging** — same structure for payables.
4. **Cash Flow** — last-6-months bar chart of revenue minus expenses from account period columns; green/red bars; trend arrow vs. previous month.
5. **Budget vs Actual (YTD)** — revenue and expense rows with progress bars (capped at 150%) and variance %: `(actual − budget) / |budget| × 100`. Over-budget is good for revenue, bad for expenses.
6. **Open Journals** — count badge and total of unbooked journals; "All booked" empty state.
7. **Recent Entries** — last 5 journal headers by ID descending.

### 5.2 Accounts (`LedgerView.swift`)

Hierarchical chart of accounts, single screen:

- Grouping: `acctType` (ordered Asset → Liability → Equity → Revenue/Income → Expense) → `subType` (collapsible `DisclosureGroup`, default expanded) → parent account → indented child accounts sorted by child number.
- Subtotals computed at each level; section totals bold; color-coded type headers; negative balances red.
- Loading / error-with-retry / empty states; pull-to-refresh.

### 5.3 Journals (`GLJournalView.swift`)

- **List:** segmented filter All / Open (`status == "OPEN"`) / Booked (`booked == true`) / Closed (`status == "CLOSED"`). Rows show description, `J-#`, status badge (OPEN orange, BOOKED blue, CLOSED gray), type badge, date, amount.
- **Detail (`GLJournalDetailView`):** header fields (journal #, type, status, booked info, period/year, party, invoice #, due date, template); amounts section with total debits/credits and a red **out-of-balance** line when `|debits − credits| > 0.005`; journal lines; evidence attachments (with confirmed checkmarks).
- **Actions:** Book (hidden when already booked; sends period/year/`userName: "MOBILE"`), Close (hidden when closed), Clone as Template, Delete — each behind a confirmation dialog.
- **Create (`CreateJournalSheet`):** optional template picker; header fields (description required, amount, type defaulting to `JE`, party ID, transaction date); editable detail lines (account, child, description, debit, credit, fund) with add/remove (minimum 2 lines) and a live balance check showing "Out of balance by X". Submits via `create_journal` (full header + lines).
- **Clone (`CloneJournalSheet`):** template description required; calls `clone_journal_entry`.

### 5.4 Invoices (`InvoicesView.swift`)

Four sub-tabs (segmented):

1. **Capture** — scan via VisionKit document camera (first page used) or PhotosPicker. "Process with AI" sends the JPEG (base64) to `/agent/analyze-invoice`; extracted vendor/invoice #/amount/date shown as a preview card.
2. **Confirm** — review AI-extracted fields (read-only) over the captured image; vendor auto-matched by name against the vendor list, with manual picker fallback; "Create Invoice" submits an OPEN `Payment`.
3. **Manual** — invoice number, amount, description, vendor picker, invoice/due dates; same submit path.
4. **Payments** — read-only list of AP payments with status badges.

Submit requires a selected vendor and a parseable amount; success clears the form and shows a confirmation message.

### 5.5 Payables (`APPayablesView.swift`)

- **List:** segmented filter All / Open / Paid / Closed; rows show description, vendor ID, status badge (OPEN orange, PAID green, CLOSED gray), date, amount, and "Paid: X" when partially paid. Toolbar links to **Vendor Maintenance** and **Create**.
- **Detail (`APPaymentDetailView`):** payment info; amounts (total, paid, remaining — red when outstanding; GST/PST/adjustment/rebate when non-zero); line items; transaction details; event history. Sections load sequentially.
- **Record Payment (`RecordAPPaymentSheet`):** shows total / previously paid / remaining; amount + date paid; disabled when remaining ≤ 0; updates the payment with cumulative `amountPaid`.
- **Create (`CreateAPPaymentSheet`):** searchable vendor picker, invoice #, description, reference, order #, amount (required), transaction/due dates; creates with status `OPEN`.
- **Delete** behind destructive confirmation.

### 5.6 Receivables (`ARReceivablesView.swift`)

- **List:** segmented filter All / Open (OPEN or PARTIAL) / Overdue / Closed. The Overdue filter calls the dedicated server endpoint (server-side date logic). Rows show description, customer ID, status badge (OPEN orange, PARTIAL yellow, CLOSED green, OVERDUE red), date, amount, "Rcvd: X" when partially received. Toolbar links to **Customer Maintenance** and **Create**.
- **Detail (`ARTransactionDetailView`):** transaction info (customer, receipt #, reference, dates); amounts (total, received, remaining, adjustment); debit/credit line items.
- **Record Payment (`RecordPaymentSheet`):** total / previously received / remaining; amount + date paid; cumulative `amountReceived` update; disabled when remaining ≤ 0.
- **Create (`CreateARTransactionSheet`):** customer ID (required), description, reference, receipt no, amount (required), transaction/due dates; creates with status `OPEN`.
- **Delete** behind destructive confirmation.

### 5.7 Banking (`BankingView.swift` + `PlaidLinkFlow.swift`)

- **Accounts:** linked bank accounts with name, institution, type/subtype, masked number (`••XXXX`), current and available balances. Tap to select.
- **Transactions:** filtered to the selected account; merchant, date, primary category, pending status; credits green.
- **Linking:** Settings → Connect Bank Account → backend `create_link_token` → `PlaidLinkFlow` (a `UIViewControllerRepresentable` wrapping Plaid LinkKit) → on success the public token is exchanged server-side via `exchange_public_token`.

### 5.8 Vendor & Customer Maintenance

Mirror-image master-data screens reached from Payables / Receivables toolbars:

- **List:** segmented All / Active / Inactive; case-insensitive search over name, short name, contact (and customer ID for AR); pull-to-refresh; "+" to create.
- **Detail:** read-only sections — Contact (name, short name, contact, phone, fax), Address (3 lines + postal code), Account Links (GL account/child, VAT, AP or AR account), Info (type, status badge, terms in days, description); Edit and Delete (confirmed) actions.
- **Form (create/edit):** same sections; name required (customer ID also required on AR create); status defaults to `ACTIVE`; audit fields stamped `createUser`/`updateUser` = `"MOBILE"` with the current date.

### 5.9 AI Chat (`AgentChatView.swift`)

- Sheet presented from the floating button on any tab.
- Chat bubbles (user right/blue, assistant left/gray); multi-line input (1–5 lines); "Thinking…" indicator.
- Streams from `/agent/chat` (SSE); chunks are appended in place to a placeholder assistant message.
- Empty-state **quick actions** that orchestrate client-side bulk operations: *Close all open journals* and *Book all open journals* (fetch open journals, then call close/book per journal with progress status).
- Clear-history and close controls.

### 5.10 Settings (`MainView.swift` → `SettingsView`)

- Account info display (name, email, company).
- Face ID / Touch ID toggle (`biometricEnabled`).
- Connect Bank Account (launches Plaid Link flow).
- Logout with confirmation.

---

## 6. Business Rules & Validation

| Rule | Definition |
|---|---|
| Journal balance | A journal is in balance when `|Σdebits − Σcredits| ≤ 0.005`; create form shows live imbalance, detail view flags it red |
| Journal bookable | `booked != true` (Book action hidden otherwise) |
| Journal closeable | `status != "CLOSED"` |
| Journal create | Description required; minimum 2 detail lines |
| Record payment (AP/AR) | Enabled only while remaining balance > 0; payments accumulate (`amountPaid` / `amountReceived` are cumulative) |
| Remaining balance | `amount − amountPaid` (AP) / `amount − amountReceived` (AR); red when > 0, green at 0 |
| AR "Open" filter | Includes both `OPEN` and `PARTIAL` statuses |
| Overdue (AR list) | Determined server-side via `list_overdue_ar_transactions` |
| Aging buckets | Days past due: Current (≤ 0), 1–30, 31–60, 61–90, 90+; missing due date → Current |
| Budget variance | `(actual − budget) / |budget| × 100`; progress capped at 150%; over is good for revenue, bad for expense |
| Audit stamping | Mobile writes stamp `createUser` / `updateUser` / `userName` as `"MOBILE"` |
| Destructive actions | Always behind a confirmation dialog |

---

## 7. Non-Functional Characteristics

- **Security:** Bearer JWT on every tenant request; automatic silent refresh; biometric lock on session expiry without password re-entry; tokens stored in `UserDefaults` (⚠️ not Keychain — see §9).
- **Multi-tenancy:** tenant (Company ID) is a URL path slug; all business endpoints are tenant-scoped.
- **Resilience:** every list view implements loading, retryable error, and empty states; 401s recover transparently when possible.
- **Currency:** amounts formatted as USD with monospaced digits.
- **AI boundary:** all AI calls (vision extraction, agent chat) run server-side in the Go agent; the app never holds an Anthropic API key.

---

## 8. Testing Status

Test targets exist but contain **scaffolding only** — no functional coverage:

- `nbledgerTests` (Swift Testing): empty example test.
- `nbledgerUITests` (XCTest): launch + launch-performance placeholders, launch screenshot.
- `Tests/NBLMobileTests`: empty placeholder.

Build/test commands:

```bash
xcodebuild -project nbledger.xcodeproj -scheme nbledger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build   # or `test`
```

---

## 9. Known Gaps & Observations

1. **Token storage** uses `UserDefaults`/`@AppStorage` rather than the Keychain — an accepted risk to revisit.
2. **No test coverage** beyond scaffolding (§8).
3. **`Config.plist` and `Info.plist` are empty** — no camera usage description (`NSCameraUsageDescription`) or Face ID usage description (`NSFaceIDUsageDescription`) found in the source plists; these are presumably injected via build settings, otherwise camera/Face ID prompts would crash on device.
4. **CLAUDE.md drift:** the in-repo CLAUDE.md describes an 8-tab layout; the code implements 5 tabs with Payables/Banking/Receivables/Settings under a custom More tab (`MoreView` grid), and 7 dashboard widgets rather than 6.
5. **Monolithic API layer:** `APIService.swift` (~2,100 lines) holds all models and networking in one file.
6. **Base URL switching** between dev and prod is a manual code edit, not a build configuration.
7. **SPM library target (`NBLMobile`)** is an empty placeholder; all real code lives in the Xcode app target.
