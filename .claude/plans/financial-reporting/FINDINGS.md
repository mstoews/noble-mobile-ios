# Financial Reporting on Mobile — Findings

Date: 2026-09-20. Client: noble-mobile-ios @ main. Server: noble-go-server @
master. Tenant inspected: `sava` (read-only).

Question asked: should the app carry more reports explaining the financial
position — a monthly comparison of the operating position, for example?

## The short answer

The reports largely **already exist server-side**. The gap is that the iOS app
surfaces almost none of them, and the one a condo board actually reviews
each month — operating budget vs actual — is fully backed by live data today.

## What the app surfaces now

Four reporting-ish reads, out of ~30 the server offers:

| Read | Where |
|---|---|
| `account_balances` | Accounts tab, Dashboard fund balances |
| `read_cash_position_history` | Dashboard cash sparkline |
| `read_budget_accounts` | Budget screen (read-only) |
| `read_aging_bills_by_period` | Payables, Sign-Off, Activity, Dashboard |

Nothing answers "are we on budget", "where does the reserve stand", or "what
does this month look like against last".

## What the server already has, unused by mobile

| Endpoint | Gives |
|---|---|
| `comparison_trial_balance_by_fund?fund=&year=` | **Per account, per period: `actual`, `budget`, `opening`, `closing`.** One call for a whole year of one fund. |
| `read_income_statement_tb` | Income statement over a period range, optional `fund`, with a full comparative range (`compare_to_period_from/to` + years) |
| `expense_comparison_by_prd/{id}` | Per account: `previous_period`, `current_period`, `current_budget` |
| `read_balance_sheet_tb` | Balance sheet over a period range |
| `read_trial_balance_by_period` / `_by_date_range` / `read_posted_trial_balance_by_period` / `trial_balance_by_fund` | Trial balances, several shapes |
| `read_ar_aging_snapshot`, `read_ar_aging_history`, `read_ap_aging_history` | Aging, current and over time |
| `fund_targets_list` | Per-fund target balance and as-of date |
| `read_gl_balances_by_period` | Period balances |

`comparison_trial_balance_by_fund` is the standout: a single call returns
everything a budget-vs-actual view needs, already keyed by period.

## What data actually exists in `sava`

This is what makes the recommendation concrete rather than aspirational.

**Funds** (`gl_funds`):

| Code | Description |
|---|---|
| `OPER` | Operating fund |
| `RES` | Contingency Reserve Fund |
| `CAP` | Capital Reserve Fund |
| `SPE` | Special Levy Fund |

**Balances and budget** (`gl_account_amts`, year 2026):

| Fund | ACTUAL rows | BUDGET rows |
|---|---|---|
| `OPER` | 40 | **444** |
| `RES` | 16 | 0 |
| `CAP` | 2 | 0 |
| `SPE` | — | — |

**Fund targets** (`fund_target`): 2 rows — OPER 50,000.00 and RES 125,000.00,
both as of 2025-12-31.

**Reserve study**: effectively absent. `reserve_study` and `reserve_component`
do not exist as tables in this tenant; `condo_reserve_component` exists with
**1 row**. The `reserve_components` / `reserve_study` endpoints therefore have
nothing to report on here.

## Two traps

**F-R1 — the fund codes are not what they look like.** They are `OPER`, `RES`,
`CAP`, `SPE`. *Not* `OPERATING`, and *not* the `fund_code` enum declared in
migration 000078 (`OPER`, `RESV`, `CAPA`, `SPAS`), which `gl_funds` does not
use. Anything built here must read `funds_list` rather than hardcode a code —
the same class of assumption that cost this project a removed feature and an
impossible plan during the API realignment (see that plan's VERIFICATION.md §8).

**F-R2 — only `OPER` has a budget.** A budget-vs-actual view pointed at `RES`
or `CAP` would render every line as 100% underspent, which is false. The UI has
to distinguish "no budget set" from "budget of zero".

**F-R3 — budget does not live where its table name suggests.** `gl_budget_amt`
is **empty** (0 rows). The live budget is on `gl_account_amts` with
`amount_type = 'BUDGET'`. A report written against `gl_budget_amt`, or against
the `read_budget_amt` endpoint that reads it, would show nothing and look like
a data-entry problem rather than a wrong-source problem.
