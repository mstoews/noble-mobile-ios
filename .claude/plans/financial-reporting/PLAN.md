# Financial Reporting on Mobile — Plan

Owner: unassigned. Status: pending.
Goal: let a treasurer answer "are we on budget?" from their phone. Today the
app shows balances and what needs approving, but nothing explains the
financial position.

## Binding references

- Findings F-R1…F-R3 (what exists server-side, what data exists in `sava`,
  and three traps): ./FINDINGS.md
- Rulings R-D1…R-D6 (settled) and R-O1 (open, blocks R-A2): ./DECISIONS.md
- Method note that produced these: ../api-realignment/VERIFICATION.md §8 —
  read the Go row and the live data, not the OpenAPI schema.

## Repo facts (verified 2026-09-20)

- The app makes four reporting-ish reads today: `account_balances`,
  `read_cash_position_history`, `read_budget_accounts`,
  `read_aging_bills_by_period`. The server offers ~30.
- `comparison_trial_balance_by_fund?fund=&year=` returns per account per
  period: `actual`, `budget`, `opening`, `closing`. It is unused by any client
  in this repo.
- `sava` 2026 has 40 ACTUAL and **444 BUDGET** rows for `OPER`; `RES` and `CAP`
  have actuals and no budget.
- `BudgetView` / `BudgetService` already exist and read `read_budget_accounts`.
  Check for reuse before adding a parallel budget model.

## Tasks

### R-A1 — Operating Statement: budget vs actual — pending
The one report (R-D1). A period picker defaulting to the active period, then
per account: actual, budget, variance (amount and %), for the month and
year-to-date. Grouped by account type, sorted so the largest adverse variance
is visible without scrolling — a board reads this to find what went wrong, not
to admire what went right.

Source is one call: `comparison_trial_balance_by_fund?fund=<code>&year=<year>`
(R-D3). Month = the selected period's row; YTD = sum of periods 1..selected.
Fund comes from `funds_list` (R-D4); a fund with no budget rows renders as
unbudgeted rather than underspent (R-D5); budget never comes from
`gl_budget_amt` (R-D6).
- Acceptance: against `sava` 2026 OPER, the month and YTD columns reconcile to
  the Accounts tab's balances for the same period; a fund with no budget says
  so; no fund code is hardcoded anywhere in the diff.
- Touches: `nbledger/APIService.swift` (one read + row model), a new
  `OperatingStatementView.swift`, `nbledger/MoreView.swift` (a "Reports" or
  "Operating Statement" destination).
- Depends on: nothing.

### R-A2 — Fund position vs target — pending
Opening, movement, closing per fund against `fund_target` (real rows: OPER
50,000, RES 125,000, both as of 2025-12-31). For a condo corporation this is
the report with statutory weight and the one most small-condo software does
worst.
- **Blocked on R-O1**: scope it to position-vs-target, not a reserve-study
  continuity report. The study surface has no data here — `reserve_study` and
  `reserve_component` are absent from the tenant and `condo_reserve_component`
  holds one row. A report that looks like a reserve study but is not one is
  worse than no report.
- Acceptance: each fund's closing position and its target, with the gap; funds
  without a target say so rather than showing the gap as the full balance.
- Touches: `nbledger/APIService.swift`, a new view, `MoreView`.
- Depends on: R-A1 (for the shared period picker and row styling), R-O1.

### R-A3 — Verification pass — pending
Same shape as the realignment's A8, and for the same reason: three of that
plan's four wrong calls came from trusting a schema over the data. Re-derive
the endpoint list, run the non-optional-field audit
(`../api-realignment/VERIFICATION.md` §2) over any new models, and walk the
report against the live tenant with a treasurer's eye — do the numbers
reconcile to something they already trust?
- Acceptance: VERIFICATION.md with a verdict; any finding fixed or explicitly
  accepted.
- Depends on: R-A1 (R-A2 if it has landed).

## Deliberately not in scope

Trial balance, full balance sheet, and the report designer surface
(`user_report`, `report_designer_template`, `agent/generate-report`) — R-D2.
The Excel add-in already serves those through `NBL_TB_Data`, and the phone is
the wrong medium for a 40-row grid. Arrears is a third candidate but is partly
covered by the Receivables tab plus `read_ar_aging_snapshot`; revisit once
R-A1 is in use and it is clear whether the gap is felt.

## Status log
- 2026-09-20: plan created from a review of the server's reporting surface and
  the live `sava` data. R-A1 is unblocked and needs no server work; R-A2 waits
  on R-O1.
