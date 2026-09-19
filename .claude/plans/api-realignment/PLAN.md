# API Realignment (iOS ← noble-go-server) — Plan

Owner: unassigned. Status: pending.
Goal: bring nbledger back onto the server contract as it stands at
noble-go-server master (d229968, spec v0.0.4.53). The app currently **cannot
log in at all** against prod — this is a restore-service plan, not a polish
pass.

## Binding references

- Review findings F1–F13 (evidence, file:line, live prod probes):
  ./FINDINGS.md
- Rulings A-D1…A-D9 (settled) and A-O1…A-O4 (open, block the tasks named):
  ./DECISIONS.md
- Server contract: /Users/murraytoews/projects/noble/noble-go-server/docs/openapi.json
  (paths authoritative — `api/openapi_drift_test.go` enforces them; payments
  schemas are NOT, per A-D7)
- Server routes: noble-go-server/api/routes.go, api/server.go (auth),
  api/routes_permissions.go (RBAC)

## Repo facts (recon-verified 2026-09-19)

- 78 distinct endpoint calls in `nbledger/*.swift`; 71 resolve, 7 broken
  (6 deleted/renamed, 1 wrong method + changed semantics).
- Auth: `LoginView.swift:261` and `:314` POST to the two removed `/api/login*`
  URLs; `APIService.swift:1656` refreshes via `securetoken.googleapis.com`.
  Prod returns 404 for both login routes (F1).
- `APIService.swift` (2364 LOC) holds every model and all networking;
  `request`/`decoder` are internal, `session` is injectable, `baseURL` is
  `{host}/{tenant}/v1` with host `https://api.nobleledger.com` (`:1523`).
- Last alignment 2026-07-07 (`8758e03`) against spec v0.0.4.52; 67 spec
  commits since.
- Prod is at or past master: `GET /version` → `0.6.0`, and `/version` itself
  only exists from 2026-08-31. So prod is NOT lagging behind the breaking
  changes — the usual "prod lags master" escape hatch does not apply here.

## Tasks

### A1 — Port authentication to the session contract — done
Blocks everything else: nothing downstream is testable against a live server
until login works. Replace both `/api/login*` calls with
`POST /v1/auth/login {tenant, email, password}`; store `session_token` in the
existing `authToken` slot; re-point `performTokenRefresh` at
`POST /v1/auth/refresh` with no body, relying on the HttpOnly cookie
(A-D1, A-D2). Delete the Firebase API key, the `refreshToken` persistence, and
the Apple login path per A-O1. Keep the biometric lock → refresh flow (A-D3).
Handle the MFA answer per A-O2, and map 403 `code: "NO_TENANT_ACCESS"` to a
distinct "no access to this company" message rather than the generic string.
- Acceptance: build green; a real login against
  `https://api.nobleledger.com` yields a session token and at least one
  authenticated tenant read (`account_list` or `profile`) returns 200; token
  expiry → biometric unlock → refresh → retry works without password re-entry;
  no Firebase key or `securetoken.googleapis.com` reference remains in the
  target.
- Touched: `nbledger/APIService.swift` (session auth layer, single-flight
  refresh, tenant guards), `nbledger/LoginView.swift` (−130 lines: Apple flow
  and the raw-URLSession login gone), `nbledger/ContentView.swift`
  (expiry/lock wiring, server-side logout), `nbledger/nbledger.entitlements`
  (Apple capability removed), new `nbledgerTests/APIServiceAuthTests.swift`
  (14 tests), `.claude/skills/verify/SKILL.md` (its session-transplant recipe
  described the retired Firebase refresh).
- Depends on: A-D13, A-D14 (both settled).

**Status 2026-09-19.** Done and verified except the one item that needs a
credential:
- Build green; 49/49 unit tests pass (35 pre-existing + 14 new).
- No Firebase key or `securetoken.googleapis.com` reference remains.
- Login screen verified in the simulator: workspace + email + password + Log
  In, no "or" divider and no Apple button. (A Springboard iCloud alert for the
  simulator's own Apple account overlaps the middle of the screenshot — it is
  not from the app.)
- Request shape verified against live prod without credentials: the body the
  client sends is accepted as well-formed (it fails on the password, not on
  binding), and omitting `tenant` returns "Tenant is required".
- Live login and authenticated reads confirmed by the owner against a real
  workspace ("working as advertised", 2026-09-19) — the one acceptance item
  this session could not close itself, since it needs a real password.
- Found en route: F14 (`public` refused as a tenant on every path) and a
  latent test-harness hazard — Swift Testing runs suites in parallel and
  `StubURLProtocol`'s responder is process-global, so a third suite sharing it
  made all three read each other's traffic. Followed the existing convention
  (`BillStubURLProtocol`, `EvidenceStubURLProtocol`) and gave the auth suite
  its own `AuthStubURLProtocol`. The duplication across four near-identical
  stub classes is now the obvious next cleanup if a fifth suite appears.

### A2 — Rebuild Payables on the bills surface — pending
The four `ap_transactions` calls the tab is built on are deleted (F2). Per
A-O3(a): list from `read_aging_bills_by_period` (required `period_year`,
`period_from`, `period_to`), detail from `read_payments_for_bill/{bill_journal_id}`
and `read_scheduled_payments_for_bill/{bill_journal_id}`, "record payment" →
`schedule_bill_payment`, edits → `update_bill`, approval →
`update_bill_approval` (already wired). New `AgingBill` model reading
`journal_status`, not `booked` (A-D6, F3). Retire `Payment`, `PaymentEvent`,
`PaymentDetail`, `PaymentTxnDetail`, `CreateApTransactionRequest`,
`UpdateApTransactionAmountPaidRequest` and their wrappers, including the two
dead ones per A-D9.
- Acceptance: build green; Payables list, detail, create and payment paths
  all hit live routes with no 404; the four retired client wrappers and their
  models are gone from `APIService.swift`; `ActivityView`, `InvoicesView` and
  `MainView` (the dashboard "needs sign-off" count) compile against the new
  source and show the same counts the server reports.
- Touches: `nbledger/APPayablesView.swift`, `nbledger/APIService.swift`,
  `nbledger/ActivityView.swift:157`, `nbledger/InvoicesView.swift:696`,
  `nbledger/MainView.swift:416`, `nbledger/PaymentSignOffView.swift` (verify).
- Depends on: A1, A-O3.

### A3 — Fix the Banking tab routes — pending
Per F4: `/api/create_link_token` → `plaid_link_token`; `GET /api/accounts` →
`GET list_bank_accounts`; the transaction list → `GET
cash_movements/by_account/{bank_account_id}`, with `POST api/transactions` kept
(if wanted) only as an explicit "sync now" action rather than the list read.
`POST get_access_token` stays as-is — and must not be regenerated away from a
spec stub, since it is deliberately undocumented. Response models change with
the routes (`BankAccountsResponse` / `{latest_transactions:[…]}` no longer
apply).
- Acceptance: build green; accounts list and per-account transactions render
  from live data; link → exchange → accounts-refresh round-trips against prod;
  no `/api/accounts` or `GET /api/transactions` call remains.
- Touches: `nbledger/BankingView.swift`, `nbledger/APIService.swift:2066-2095`,
  `nbledger/MainView.swift:612` (connect-bank entry), `nbledger/PlaidLinkFlow.swift`
  (verify only).
- Depends on: A1.

### A4 — Thread OCC tokens through the guarded writes — pending
Add `expected_updated_at` to the four request models the server now requires
it on (F5): `UpdateApVendorRequest`, `UpdateArCustomerRequest`, and the AR
transaction amount-received / status requests. Carry the `updated_at` from the
row the screen last read; re-read if absent (A-D4). Surface 409 as a reload
prompt, not a generic error (A-D5).
- Acceptance: build green; a vendor edit, a customer edit, an AR receipt and
  an AR status change each succeed against prod; a deliberately stale token
  produces the reload prompt rather than a silent overwrite or a generic
  failure; no synthesised timestamps anywhere in the diff.
- Touches: `nbledger/APIService.swift` (4 request models + wrappers),
  `nbledger/VendorMaintenanceView.swift`,
  `nbledger/CustomerMaintenanceView.swift`,
  `nbledger/ARReceivablesView.swift`.
- Depends on: A1.

### A5 — Journal + bill contract touch-ups — pending
Small, independent items: special-case 409 from `book_journal_entry` as a
lifecycle conflict in the booking confirmation (F7); confirm the journal-header
reads still ship `booked` before `AgentChatView.swift:214` keeps filtering on
it, and switch to `status`/`journal_status` if not (F3); leave
`create_bill`'s `booked: false` request field alone — the server still accepts
it (A-D6).
- Acceptance: build green; booking an already-booked journal shows the
  conflict message, not "Server error (409)"; the open-journal count in
  `AgentChatView` matches the server's unbooked set.
- Touches: `nbledger/JournalBookingView.swift`, `nbledger/GLJournalView.swift`,
  `nbledger/AgentChatView.swift`.
- Depends on: A1.

### A6 — Repair the Accounts tab grouping — pending
Remove the `parentAccount == true` header-row lookup at `LedgerView.swift:47`
— it can never match now (F10) — and restore the sub-type tier per A-O4(a) by
joining `account_list` for `sub_type`, or collapse the tier per A-O4(b).
- Acceptance: build green; group headings name the account group, not the
  first child; sub-type sections are populated (or deliberately absent per
  A-O4(b)), and section totals still sum to the type totals.
- Touches: `nbledger/LedgerView.swift`, `nbledger/APIService.swift`
  (`fetchAccountList` at `:1704` if a second read is added).
- Depends on: A1, A-O4.

### A7 — File the server-side defects — pending
Per A-D8, against noble-go-server, not worked around here:
(a) the payments family's OpenAPI schemas describe the retired
`ap_transactions` shape while the handlers return the receipts sqlc structs,
and `PaymentTransactionDetail` is an empty schema (F9) — worth considering a
schema-level drift check, since the existing test is path-only;
(b) `servers[0]` is `https://nbl.nobleledger.com/`, the marketing site; the
API is `api.nobleledger.com` (F13).
- Acceptance: both filed with the F9/F13 evidence; no client-side compensation
  merged for either.
- Touches: nothing in this repo.
- Depends on: none — can go first.

### A8 — Independent verification pass — pending
Verify-only, written by someone who wrote none of A1–A6, in the
`document-capture` M3 style: re-derive the client call list and re-run the
spec diff to confirm zero remaining broken paths; build + full test suite;
a live read-only walk of every touched surface; a security sweep (no Firebase
key left, no session or refresh token logged, tenant never hardcoded, no
signed URL in logs). Record the result as ./VERIFICATION.md.
- Acceptance: VERIFICATION.md with a verdict and per-task findings; any
  finding either fixed or explicitly accepted with a reason.
- Depends on: A1–A6.

## Deferred — new server surface worth adopting

Not part of restoring service; sequence after A8. Highest value first:
`create_ar_invoice` (posts a real balanced journal, unlike the
`create_ar_transaction` the app uses today), `board_dashboard` +
`treasurer_note`, `read_ar_customer_open_balances` / `read_draft_ar_invoices`,
`read_unbooked_or_open_journals_in_period`, the trial-balance-by-date-range
reads, `GET /version` as a client/server compat check, and the
`user_report` / `agent/generate-report` reporting surface. Full list in
FINDINGS.md § "New server surface worth adopting".

## Status log
- 2026-09-19: review completed (FINDINGS.md), plan created. A7 is unblocked;
  A1 waits on A-O1 and A-O2; nothing else is testable until A1 lands.
- 2026-09-19: A-O1 resolved by the owner (remove the Apple button) → A-D13;
  A-O2 taken as detect-only → A-D14. A1 implemented: 49/49 unit tests green,
  login screen verified in the simulator. New rulings A-D10–A-D12; new finding
  F14. A2–A6 are now unblocked in principle, though A2 still waits on A-O3 and
  A6 on A-O4.
- 2026-09-19: owner confirmed live login and authenticated reads against a real
  workspace; A1 acceptance fully met. Shipped on feat/session-auth-port.
