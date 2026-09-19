# API Realignment — A8 Verification

Date: 2026-09-20. Repo: noble-mobile-ios @ main (`e6c8faa`) plus the A8 fixes
below. Reference server: noble-go-server @ master (read-only).

## Overall verdict: SHIP-WITH-FIXES

Everything in A1–A7 and A9 holds up, with **two exceptions found here and fixed
in this pass** — one crash-class decode bug and one decision that was simply
wrong. Both were in A3, both came from trusting the OpenAPI schema over the Go
row, and neither would have been caught by any check that existed before this
pass.

### ⚠️ Independence caveat, stated up front

The plan specified a verifier "who wrote none of A1–A6". That was not available:
this pass was run by the same session that wrote all of it, so it is self-review
and carries the blind spots of self-review. The compensation was to make the
checks **mechanical** rather than judgment-based — a re-derived inventory, a
scripted nullability audit, greps, and a live UI walk — so that the findings
came from the tooling rather than from re-reading my own reasoning. That is why
the two real findings were found by the scripted audit and the live walk, and
not by inspection.

---

## 1. Endpoint inventory re-derived — PASS

Rebuilt from scratch using the **corrected** method (F16's lesson): inline
`request("…")` call sites **plus** paths assembled into a local first, plus the
host-level `/v1/auth/*` paths. 78 endpoints.

Diffed against `api/routes.go` directly — the registered routes, not the spec —
covering 483 tenant routes and 18 auth routes.

**Result: 0 of 78 client endpoints lack a registered route.**

## 2. Required-field (decode) audit — 1 BUG FOUND, FIXED

The F16 class of failure: a client model declaring a field non-optional that the
server may omit or null. Only non-optional fields can throw, so those are the
whole risk surface. Scripted extraction of every non-optional stored property in
every `Codable` model (62 models), then compared against the Go struct actually
serialized by the handler, flagging any `pgtype.*` / `Null*` / pointer field.

| Client model | Go struct | Result |
|---|---|---|
| `Account`, `GLAccountRef` | `GlAccount` | OK (and `id` is a `uuid.UUID`, so the client's `String` is right — the **spec's `integer` is wrong**) |
| `ApVendor`, `ArCustomer`, `ArTransaction`, `ArTransactionDetail` | matching models | OK |
| `AgingBill`, `AgingBillFund` | `agingBill` | OK (post-F16 fix) |
| `JournalHeader`, `JournalTemplate`, `GlEvidence` | matching models | OK |
| `CurrentPeriod` | `GetCurrentActivePeriodRow` | OK |
| `Vendor` | `GlParty` | OK |
| `FundRef` | `GlFund` | OK |
| `CashMovement` | `api.CashMovement` (wire struct) | OK — all six required fields non-nullable |
| `ApprovalEvent`/`ApprovalHistory` | `ListJournalApprovalHistoryRow` / `approvalHistoryResp` | OK |
| `BulkJournalResult`/`Response` | `bulkResultRow` / `bulkJournalResp` | OK |
| `BillPaymentSchedule` | `billPaymentSchedule` | OK |
| **`BankAccount`** | **`ListBankAccountsRow`** | **FAIL → fixed** |

### Finding A8-1 (crash-class, introduced in A3): `gl_child` is nullable

`BankAccount.glChild` was a non-optional `Int`. The row is
`GlChild pgtype.Int4` (`db/sqlc/bank_accounts.sql.go:225`), and `ListBankAccounts`
returns raw rows, so an unmapped account serializes `"gl_child": null` and the
decode throws — **blanking the entire Banking tab**, not just that row.

An unmapped account is a *normal* state, not an edge case: the sibling handler's
own doc says the mapping is set later via `PUT api/accounts/{id}` and that
"without these, the reconciliation page can't render the ledger side". Every
freshly linked account starts unmapped.

Root cause: the OpenAPI `BankAccount` schema lists `gl_child` in `required`, and
A3 trusted it.

Fixed: `glChild: Int?` plus `isMapped`; the card shows "No GL mapping" and the
schedule-payment sheet refuses an unmapped account as a source. Pinned by
`unmappedBankAccountDecodesWithBalances`.

### Finding A8-2 (wrong decision, A-D15): bank balances do exist

A-D15 concluded, at length, that "no balance exists anywhere in the API" and
removed the balance figures from the Banking cards. **That was wrong.**
`ListBankAccountsRow` carries `balance_current`, `balance_available` and
`balance_as_of`, and `api/plaid_store.go:250-268` upserts all three from Plaid's
own balance payload on every account sync. They are live data.

Root cause: the same schema omits those three fields, and A-D15 reasoned from
the spec plus `read_bank_rec_snapshot` (which genuinely has no balance) to a
conclusion about the whole API. The Path B / Option II note it cited is about
*statement* balances for reconciliation — a different thing from the synced
account balance.

Fixed: the three fields are restored to the model and to the card. They decode
via `decodeFlexibleDouble`, because `pgtype.Numeric` can arrive as a JSON string
or a number. A-D15 is corrected in DECISIONS.md rather than deleted.

## 3. Build + tests — PASS

Build clean. **75 unit tests in 12 suites green** (73 before this pass; +2 for
the `BankAccount` regressions). Harness isolation still holds with 12 suites
sharing one stub class.

## 4. Live read-only walk — PASS (partial coverage)

The standing gap since A3 — nothing had been seen against real data — is now
mostly closed. Two simulators held sessions from the owner's A1 login, with
**opaque session tokens** and `refreshExpiresAt` still in the future. The app
container was backed up first, the current build installed **over** it
(preserving the HttpOnly refresh cookie, which lives in the container and not in
the plist), and the shell walked read-only via `NavigationShellScreenshotTests`.
No writes were performed.

| Surface | Result |
|---|---|
| **Session refresh (A1)** | **PASS** — the app refreshed a ~1-day-old cookie on launch and loaded real data. The cookie-based rotation works end to end. |
| Dashboard | PASS — real figures; "Open Payments $5,000.00 / **1 bill**" is A2's aging-bills migration, and "Needs sign-off: 1 pending" is the F16 fix. That tile was blank before F16. |
| **Payables (A2)** | **PASS** — Outstanding/Overdue tiles, Open/Drafts/Paid/All tabs, and a row rendering vendor, invoice #, the `1d overdue` pill (due 2026-09-19, walked on 2026-09-20) and the REVIEW approval badge. |
| **Accounts (A6)** | **PASS** — two-tier grouping reads cleanly across Asset/Liability/Equity; a single-child account (1200 Prepaid Insurance) correctly collapses to a plain row. No visible gap where the sub-type tier was, which supports A-D19. |
| Payment Sign-Off | PASS — decode succeeds; the Pending bucket is legitimately empty because the one bill is in REVIEW. |
| Activity, Journals, Journal Booking, Receivables, Settings, Assistant | PASS — all render, no errors. |
| **Banking (A3)** | **PARTIAL** — `list_bank_accounts` succeeds and the empty state is correct, but **this tenant has no linked bank accounts**, so the card (including the restored balances and the `gl_child` fix) and the cash-movement rows are still unrendered. Covered by tests only. |

### Finding A8-3 (cosmetic, fixed): bare section header

With no linked accounts, Banking showed an empty "Cash movements" header under
the accounts empty state, reading like a section that had failed to load. The
section is now hidden when nothing is linked.

## 5. Security sweep — PASS, 1 item fixed

| Check | Result |
|---|---|
| Firebase API key / `securetoken` residue | **none** — no occurrences in the target |
| Session or refresh token logged | **none** |
| Tenant hardcoded | **none** — the only `"public"` literal is inside `isReservedTenant`, which exists to reject it |
| Signed URL in a log or error message | **none** |
| Bearer token sent to a non-Noble host | **none** — the storage `PUT` carries no `Authorization`, asserted by an existing test |
| Debug logging in a shipping build | **1 found, fixed** |

### Finding A8-4 (fixed): debug print of ledger rows

`fetchJournalById` printed the decode error **and the first 500 bytes of the raw
response** to the device console. Pre-existing (not introduced by A1–A9), and it
leaks no credential — so it passes the sweep's stated criteria — but it dumped
journal records from a shipping build, and the failure is already reported as
`.decodingFailed`. Removed. The app target now contains no `print`/`NSLog`.

## 6. Observations — accepted, not fixed

- **Parent group names repeat their first child.** On Accounts, a group header
  reads "Operating Bank Accounts" above a row also named "Operating Bank
  Accounts". This is the honest consequence of the header rows being retired
  (F10): the group name now comes from the first child. Accepted — the
  alternative is inventing a name.
- **"1 pending" counts PENDING *or* REVIEW.** The dashboard tile says "1
  pending" while the sign-off Pending tab is empty, because `MainView` filters
  both states under that label. Pre-existing, mildly inconsistent wording.
  Accepted; worth a copy change if it ever confuses anyone.
- **Test fixtures pin `tenant = "public"`.** Harmless against a stub, but those
  asserted URLs are ones prod would refuse (F14). Accepted — they exist to make
  the derived base deterministic.

## 7. What remains unverified

- **The Banking card and cash-movement rows**, for want of a linked bank
  account in this tenant. This is the one surface where a decode bug could still
  hide, and A8-1 was exactly that bug — so it deserves a look the first time an
  account is linked.
- **A real OCC 409.** Reproducing one needs two concurrent editors; the path is
  covered against the documented body shape only.
- **Every write path.** This walk was deliberately read-only: no approval, no
  scheduling, no edit was submitted against live data.

## 8. Method note for the next review

Two process failures produced the two real findings of this pass, and both are
worth carrying forward:

1. **Grep `request(` call sites *and* variable-built paths.** F16 hid for weeks
   behind `let path = …` followed by `request(path)`.
2. **Read the Go row, not the OpenAPI schema, for any field you rely on.** Three
   separate defects in this pass (A8-1's `required` on a nullable column, A8-2's
   omitted balance fields, F17's phantom `sub_type`) all came from trusting the
   spec. The paths are drift-tested and trustworthy; the schemas are not
   (issues 216–218).

The audit in §2 is scripted and cheap to re-run — it is the check that would
have caught F16, A8-1, and any future member of that family.
