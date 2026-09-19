# API Realignment — Review Findings

Date: 2026-09-19. Reviewer: this session. Status: complete.
Client: noble-mobile-ios @ main (dffb681). Server: noble-go-server @ master
(d229968, 2026-09-14), `docs/openapi.json` v0.0.4.53.
Last client/server alignment: 2026-07-07 (`8758e03`, "Align API client with
authoritative server contract"), against spec v0.0.4.52 — 67 commits have
touched `docs/openapi.json` since.

## Method

1. Extracted every endpoint the client calls from `request("…")` call sites
   across `nbledger/*.swift` (base = `{host}/{tenant}/v1`, so each literal
   maps to a `/{company}/v1/…` spec path). 78 distinct calls.
2. Dumped `paths` from the spec at the alignment commit and at HEAD, resolved
   `$ref`s, and diffed request bodies / response schemas / parameters /
   status codes for only those 78.
3. Cross-checked the survivors against `api/routes.go` and, where the spec
   looked suspect, against the Go handlers and `db/sqlc/models.go`.
4. Probed live prod (`https://api.nobleledger.com`, version 0.6.0) read-only
   to confirm what is actually deployed. No credentials were sent.

Spec trust level: `api/openapi_drift_test.go` fails on any route missing from
the spec AND any documented path with no route (two shrink-only debt lists
carry the known exceptions: the `qbo/*` family, `get_access_token`,
`api/transactions`, `plaid_link_token`, `provision_user`, `void_journal_entry`,
`account_parent_list`, `read_recent_ar_receipts`, `roles_catalog`). It passes
as of this review, so **paths are trustworthy**. It does **not** compare
schemas, and the payments family has drifted (F9).

## Tally

71 of 78 client calls still resolve. 7 are broken: 6 deleted/renamed routes,
1 wrong method with changed semantics.

## P0

**F1 — Both login routes are gone; Firebase tokens are rejected everywhere.**
`POST /api/login` and `POST /api/login/apple` were removed 2026-08-19 along
with Firebase ID-token acceptance in the auth middleware
(`noble-go-server/api/server.go:378`, `middleware/auth.go:3`). Recorded reason:
they took no tenant, issued no session row, and returned a raw Firebase token
that the old `AuthJWT` branch honoured without setting `SessionTenantKey`, so
`TenantMiddleware` skipped its cross-check entirely.

Client call sites: `nbledger/LoginView.swift:261` (email/password),
`nbledger/LoginView.swift:314` (Apple). `APIService.performTokenRefresh`
(`APIService.swift:1656`) still refreshes against
`securetoken.googleapis.com`, which now yields a token no route accepts.

Live prod evidence (2026-09-19):

| Request | Result |
|---|---|
| `POST /api/login` | 404 |
| `POST /api/login/apple` | 404 |
| `POST /v1/auth/login` | 400 (live, rejects empty body) |
| `POST /v1/auth/refresh` | 401 (live) |
| `GET /public/v1/account_list` | 401 (route exists, needs auth) |
| `GET /public/v1/read_ap_transactions` | 404 (route gone) |

Replacement contract: `POST /v1/auth/login {tenant, email, password}` →
`{session_token, expires_at, refresh_expires_at}`, or an MFA challenge
(`mfa_required`, `challenge_id`, `factors[]` of `{id, type: totp|email|sms,
hint}` → `/v1/auth/mfa/select` then `/v1/auth/mfa/verify`). The refresh token
is **never in the body** — it is delivered as an HttpOnly cookie and read back
from the cookie by `/v1/auth/refresh` (`api/auth_login.go:260`). A
`scope: "platform"` session (an SU holding no grant in the named tenant)
authenticates `/admin/v1` and is refused by every `/{company}/v1` route. 403
with `code: "NO_TENANT_ACCESS"` is the no-membership answer.

There is **no Apple sign-in route on the server anymore** — the app's Sign in
with Apple button has no server path to call.

## P1 — deleted routes still called

**F2 — The `ap_transactions` surface was dropped** (2026-08-16,
`7a943d3` "fix(provisioning): drop ap_transactions and its API surface").
All four calls the client makes are gone; `read_ap_transactions` 404s on prod.

| Client call | APIService | Live callers |
|---|---|---|
| `read_ap_transactions` | `:1893` | `APPayablesView.swift:192`, `ActivityView.swift:157`, `InvoicesView.swift:696`, `MainView.swift:416` |
| `create_ap_transaction` | `:1998` | `APPayablesView.swift:951` |
| `update_ap_transaction_amount_paid` | `:2012` | `APPayablesView.swift:766` |
| `delete_ap_transaction/{id}` | `:2016` | `APPayablesView.swift:521` |

Also removed in the same family (unused by the client): `get_ap_transaction/{id}`,
`update_ap_transaction`, `update_ap_transaction_status`,
`list_ap_transactions_by_status/{status}`, `list_ap_transactions_by_vendor/{vendor_id}`,
`list_ap_transactions_by_date_range`, `list_ap_transactions_overdue`,
`read_transactions_by_date`.

Replacement surface (all present and documented): `read_aging_bills_by_period`
(required `period_year`, `period_from`, `period_to`; optional `vendor_id`,
`status`), `read_open_bills_by_vendor/{vendor_id}`,
`read_payments_for_bill/{bill_journal_id}`,
`read_scheduled_payments_for_bill/{bill_journal_id}`, `schedule_bill_payment`,
`update_bill`, `update_bill_approval`. `AgingBill` fields: `journal_id`,
`journal_status`, `status`, `vendor_id`, `invoice_number`, `description`,
`amount`, `amount_paid`, `remainder`, `funds`, `transaction_date`, `due_date`,
`update_date`.

**F3 — `booked` is no longer returned; read `journal_status`.**
`d229968` / `2ef235f` removed `booked` from `AgingBill` and added
`journal_status` (enum OPEN = draft, CLOSED = posted, CANCELLED = voided),
documented as "the field to read for 'is this bill posted?'". `create_bill`
still **accepts** `booked` in the request (`api/create_bill.go:58`), so
`CreateBillRequest.booked` (`BillService.swift:122`) stays valid;
`CreateBillHeader.booked` (`:148`) is already optional, so its disappearance
from responses is decode-safe. `AgentChatView.swift:214` filters on
`$0.booked != true` over journal headers — verify that field still ships on
the journal-header reads before trusting it.

**F4 — Banking tab: three of four Plaid calls are wrong.**
- `POST /api/create_link_token` (`APIService.swift:2066`) → route is now
  `POST plaid_link_token` (`api/routes.go:934`).
- `GET /api/accounts` (`:2081`) → no such route; the read is
  `GET list_bank_accounts` (`api/routes.go:893`). Only
  `PUT api/accounts/{bank_account_id}` survives, for GL mapping.
- `GET /api/transactions` (`:2090`) → the route is **POST**, and its meaning
  changed: it is the manual "sync now" trigger that writes `cash_movements`
  (`api/routes.go:936`, `api/plaid_sync.go:99`), not a list returning
  `{latest_transactions: […]}`. Transaction reads are
  `GET cash_movements/by_account/{bank_account_id}` (`api/routes.go:894`).
- `POST /get_access_token` (`:2077`) still exists and is correct — but it is
  deliberately **absent from the spec** (drift-test debt list), so a
  spec-generated client will not produce it.

New Plaid surface the client does not use: `GET plaid_items`,
`DELETE plaid_items/{item_id}`, `plaid_items/{item_id}/deactivate`,
`plaid_items/{item_id}/activate`.

## P2 — contract changes on surviving endpoints

**F5 — OCC token now mandatory on four writes the client makes.**
`94a6188` ("make every OCC token required, closing the silent lost-update
path") and `5a5cedc` added `expected_updated_at` as a **required** body field
to: `update_ap_vendor`, `update_ar_customer`,
`update_ar_transaction_amount_received`, `update_ar_transaction_status`.
It is `binding:"required"` server-side, so a request without it is a 400.
The client sends it nowhere — zero grep hits for `expected_updated_at` /
`expectedUpdatedAt` across `nbledger/*.swift`. Affected screens:
`VendorMaintenanceView`, `CustomerMaintenanceView`, `ARReceivablesView`
(record-payment and status changes).

Same field was added to sibling endpoints the client does not yet call:
`update_ap_vendor_status`, `update_ar_customer_status`,
`update_ar_transaction`, `update_ar_transaction_detail`, and
`update_vendor_payment_method` (there it went optional → required).

**F6 — `read_payments_by_date` changed on both sides.**
Body: `transaction_date` / `transaction_date_2` → **`from_date` / `to_date`**
(`api/payments.go:53`). Response: the whole `Payment` object was repurposed
(see F9). The client's wrappers `fetchPaymentsByDate` (`APIService.swift:2019`)
and `fetchPaymentById` (`:2001`) are currently **dead code** — no call sites —
so this is latent, not live.

**F7 — `book_journal_entry` tightened.** `journal_id` went optional →
required, and the documented error contract is now 401/403/404/**409/500**
(`b25b775` "document book_journal_entry lifecycle error contract"); 409 is the
lifecycle conflict. The client already sends `journal_id` and surfaces the
server message, so this is a UX refinement, not a break.

**F8 — `funds_list` grew fields.** Added `id`, `restriction`, `create_date`,
`create_user`; `fund` and `description` went optional → required. Purely
additive for a decoder with optional fields.

## P3 — silent wrong-data, no error

**F9 — The spec is stale for the payments family (server-side bug).**
`public.payments` is now a *receipts* table — `db/sqlc/models.go:3241`:
`id`, `kind` (AP/AR/OWNER), `party_id`, `party_name`, `unit`, `receipt_no`,
`reference`, `receipt_date`, `amount`, `currency`, `method`,
`deposit_account`, `deposit_account_desc`, `memo`, `approval_state`,
`posted_journal_id`, `reversed`, `reversal_reason`, `reversal_kind`,
`created_at`, `updated_at`. The handlers `ctx.JSON` the sqlc structs straight
out (`api/payments.go` — `GetPaymentByID`, `ListPaymentsByDateRange`,
`ListPaymentEventsByTxn`, `ListPaymentDetailsByTxn`,
`ListPaymentTxnDetailsByTxn` all return the `db` models).

But `docs/openapi.json` still documents the retired `ap_transactions` shape:
`PaymentFull` = `{transaction_id, vendor_id, status, amount, description,
transaction_date, details, events, txn_details}`; `PaymentEvent` =
`{transaction_id, transaction_event_id, transaction_type, create_date,
create_user, update_date, update_user}` vs the real `{id, transaction_id,
kind, approval_from, approval_to, actor_id, actor_name, notes, occurred_at}`;
`PaymentsDetail` likewise. `PaymentTransactionDetail` is a valid `allOf`
alias of `PaymentsDetail` — not a defect in itself, but it inherits the wrong
shape, and the two detail endpoints actually return *different* structs:
`read_payment_details` → `db.PaymentDetail` (`charge_id`, `charge_no`,
`aging_bucket`, `outstanding_amount`) and `read_payment_txn_details` →
`db.PaymentTxnDetail` (`account_code`, `account_name`), neither of which
matches the one schema documenting both. The drift test cannot catch any of
this because it compares paths only.

Consequence for this repo: `Payment` (`APIService.swift:918`), `PaymentEvent`
(`:982`), `PaymentDetail` (`:1004`) and `PaymentTxnDetail` (`:1029`) all mirror
the stale spec. `Payment.transactionId` is a non-optional `String` used as
`id`, and the real payload has no `transaction_id` at all, so any revived call
decodes to `APIError.decodingFailed`. `amount` is also now a numeric string
and `Payment` has no `decodeFlexibleDouble` decoder — only `JournalDetail`
(`:239`) and `JournalEntry` (`:306`) have one.

Live uses of the payment *detail* endpoints — `read_payment_details/{id}`,
`read_payment_txn_details/{id}`, `read_payment_events/{id}` at
`APPayablesView.swift:503/508/513` — are reached only from the AP detail view,
which is already unreachable because its list 404s (F2).

**F10 — Account header rows were retired; group names are now wrong.**
`38619d2` ("feat(accounts)!: retire the account header row", migration 000136)
deletes every `child = 0 / parent_account = true` row and normalises
`parent_account` to uniformly false. `LedgerView.swift:47` names each group
with `sorted.first(where: { $0.parentAccount == true })?.description`, which
can no longer match, so it falls through to `sorted.first?.description` — the
heading reads e.g. "Hydro" where it used to read "Utilities". No error; just
wrong labels. `GET account_parent_list` is also gone (client never used it).

**F11 — `/account_balances` returns no `sub_type`.**
Verified against `ListAccountBalancesAllFundsRow` (`db/sqlc/gl_account_amts.sql.go:336`):
the row carries `id, account, child, parent_account, acct_type, description,
comments, status, create_date, create_user, update_date, update_user,
opening_balance, balance, period_1..12, budget_1..12` — no `sub_type`, no
`previous_*`. The spec's `AccountBalanceRow` agrees, so this is accurate, not
drift. But `fetchAccountList` (`APIService.swift:1705`) reads
`/account_balances` while `LedgerView.swift:56` groups by `$0.subType ?? "General"`,
so the sub-type tier collapses to a single "General" bucket for every account.
Combined with F10, both grouping levels in the Accounts tab are degraded.

**F12 — RBAC is enforced by default.** `RBAC_ENFORCE` defaults to **true** and
fails closed (`util/config.go:121-128`); `api/server.go:330` mounts
`RequirePermission` on the whole `/:company/v1` group with per-request
effective-role lookup scoped to the tenant. Every route the app calls now has
a permission (`account.read`, `journal.read`, `journal.book`, `journal.create`,
`ap.create`, `ap.approve`, `ar.create`, `payment.read`, `vendor.read`,
`budget.read`, `budget.update`, `plaid.create`, `plaid.update`, …). A
correctly authenticated user can therefore get a 403 per feature; the client
collapses that into a generic error string.

**F13 — The spec's production server URL is wrong.**
`servers[0]` is `https://nbl.nobleledger.com/`, which serves the Astro
marketing site and 404s on API paths (verified). The API host is
`https://api.nobleledger.com` (what `APIService.swift:1523` uses). Any client
generated from the spec inherits the wrong base.

**F14 — `public` is refused as a tenant on every path.**
Found while verifying A1 against prod: `POST /v1/auth/login` with
`tenant: "public"` returns 400 `Tenant: "public": Tenant is reserved and
cannot be used as a tenant`. `middleware/tenant_resolver.go:88`
(`isReservedSchema`) refuses `public`, `information_schema` and any `pg_*`
schema in `Acquire`, so this covers **every** tenant-scoped request, not just
login. `public` is the template schema each tenant is cloned FROM; the
in-code note records that reads served the seed ledger and that a write would
have contaminated every tenant provisioned afterwards (three live API keys
were scoped that way in production before the check existed).

The client had `let slug = tenant.isEmpty ? "public" : tenant` in
`APIService.baseURL`, so any request made with no tenant set addressed the
template. Fixed in A1: no fallback, tenant-scoped requests refuse an empty
tenant, and login rejects a reserved name client-side. Note the unit-test
fixtures still pin `tenant = "public"` to keep their URL assertions
deterministic — harmless against a stub, but those URLs are ones prod would
refuse.

**F15 — The spec's read schemas omit the `updated_at` the writes require.**
Found while implementing A4. `update_ap_vendor` and friends require
`expected_updated_at` = "the row's `updated_at` from the read that produced
this edit", but the spec's `APVendor`, `ARCustomer` and `ARTransaction`
schemas expose only `update_date` (a date) — no `updated_at`. The db models
carry both (`db/sqlc/models.go:1823`, `:1893`, `:2014`: `UpdatedAt time.Time`
alongside `UpdateDate pgtype.Date`), and the reads return the full sqlc row
(`ReadAllVendors`/`GetVendorById` → `[]ApVendor`/`ApVendor`), so the field IS
on the wire. Same class of defect as F9: the drift test compares paths, not
schemas. Consequence: **a client generated from the spec cannot satisfy the
OCC requirement at all** — it would have no field to read the token from.
Worth filing with F9 under A7.

**F16 — `read_aging_bills_by_period` was already broken, and the original
review missed it.** The client's `AgingBill` declared `let booked: Bool`
(non-optional). The server removed `booked` from that response in 2026-09
(`d229968`, recorded here as F3) and replaced it with `journal_status`, so the
decode threw `keyNotFound` and **every** aging-bills read failed — taking
`PaymentSignOffView` with it, since that screen's only data source is
`fetchAgingBills`.

Why the original review missed it: the endpoint inventory was built by grepping
`request("…")` call sites, and `fetchAgingBills` assembles its path into a
local (`let path = "/read_aging_bills_by_period?…"`) before calling
`request(path)`. That call therefore never appeared in the 78-endpoint list, so
F3's `AgingBill` schema change was recorded as "not used by the app". Re-running
the extraction for variable-built paths found exactly four such call sites —
`/assets`, `/api/transactions`, `/cash_movements/by_account/…` and this one —
of which this was the only unreviewed endpoint. Lesson for the next review:
grep the `request(` call sites *and* any path built into a variable.

Fixed in A2. `journalStatus` replaces `booked`, with `isPosted`/`isDraft`/
`isPaid` helpers, pinned by `agingBillsDecodeJournalStatusAndNotBooked`.

**F17 — no account read exposes a sub-type, and the spec says otherwise.**
Found while implementing A6. `docs/openapi.json` gives `GlAccount` a `sub_type`
property, but the real row (`db/sqlc/models.go:2446`) has no such field, and
`gl_accounts` has no such column: `sub_type` exists only on `gl_budget_amt` and
on the standalone `gl_sub_type` lookup table, which has no link back to an
account (`db/query/subtype.sql`). So the Accounts tab's sub-type tier could
never be populated from any endpoint, and restoring it needs a server-side
schema change rather than an API change. The same schema also types
`GlAccount.id` as `integer` when the row carries a `uuid.UUID` — the client's
`String` was right and the spec wrong. Both belong with
[issue 217](https://github.com/mstoews/noble-go-server/issues/217); the
`AgingBill` schema separately omits `approval_status`, which the handler does
send.

**F18 — a scheduled bill payment never settles anything.**
`schedule_bill_payment` inserts a PLANNED row in `bill_payment_schedule`
(`api/routes.go:543`) and **nothing in the API posts a due schedule** — there
is no scheduler endpoint, and no handler reads the table to turn a due row into
a payment. So scheduling records intent only: the bill stays OPEN forever, and
`read_payments_for_bill` never sees it. A-D18 assumed scheduling was at least
adjacent to paying; it is not. Recording (F19) is the only way to settle a bill
from the app.

**F19 — recording a payment is a FOUR-call flow, and this plan's A10 named the
wrong middle step.** A10 was written as `create_payment` →
`create_payment_detail` → `post_payment`. The real sequence, from
`api/post_payment.go`:

1. `create_payment` — the header (kind AP, party, amount, method,
   `deposit_account`, `approval_state`).
2. `create_payment_txn_detail` × N — the **GL lines**. `post_payment` refuses
   with 422 if there are none, and again if `sum(debit) != sum(credit)` within
   0.001. A10 omitted this step entirely.
3. `create_payment_detail` × N — the **apply lines**, which drive the
   bill-closure pass.
4. `post_payment` — writes the AP_PAYMENT journal, back-refs
   `bill_journal_id` on the DR rows, and closes fully-paid bills.

Two traps inside it:

- **`charge_id` is the bill's `journal_id` as a string.** The closure pass does
  `strconv.ParseInt(apply.ChargeID, 10, 64)` and `continue`s on a non-numeric
  value as "not a GL bill". Send anything else and the payment posts while the
  bill silently stays open. (The OpenAPI `PaymentsDetailRequest` advertises a
  `bill_journal_id` field instead, which the handler does not accept —
  another instance for issue 217. The real bill back-reference is written by
  `CreateAPPaymentDetail` into `gl_journal_detail`, not by any detail endpoint.)
- **`deposit_account` on the header is never read by `post_payment`**, which
  takes the whole GL effect from the txn-detail lines. Header and lines must be
  derived from the same account or the record contradicts its own journal.

## New server surface worth adopting (61 paths added since alignment)

Relevant to this app:
- `create_ar_invoice` — posts a balanced Dr AR / Cr Revenue journal
  (`51114af`), unlike `create_ar_transaction`, which writes a bare row.
- `board_dashboard`, `treasurer_note/{year}/{period}` + `upsert_treasurer_note`.
- `read_ar_customer_open_balances`, `read_draft_ar_invoices`,
  `read_ar_aging_snapshot`, `read_ar_aging_history`, `read_ap_aging_history`.
- `read_unbooked_or_open_journals_in_period`,
  `accounts_posted_in_period/{period}/{period_year}`, `period_activate`,
  `bootstrap_periods`.
- `read_trial_balance_by_date_range`, `read_posted_trial_balance_by_period`,
  `posted_account_balances`, `account_amts_by_date`, `account_amts_from_date`,
  `rebuild_account_amts`.
- `user_report` / `shared_report` / `report_designer_template` CRUD plus
  `agent/generate-report`.
- `reconciliations/*` (bank reconciliation), `project_*` / `event_*`
  (projects, Gantt, accounting events).
- `GET /version` — cheap client/server build-compat check.
- Onboarding: `/v1/auth/accept_invite`, `/v1/auth/invite/redeem`,
  `create_password_invite`, `/admin/v1/invite_user`.

Removed, unused by this app: `account_parent_list`, `read_accounts_uuid`,
`team_create` / `team_update` / `team_delete` (roster now derives from
users + `kb_team_roles`).
