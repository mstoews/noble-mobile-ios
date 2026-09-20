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

**F-R2 — CORRECTED (2026-09-20, during R-A1): no tenant has an *operating*
budget.** The original finding said "only `OPER` has a budget". That was read
off row counts without checking which accounts those rows sit on. `sava`'s 444
BUDGET rows ($481,060) are **entirely on balance-sheet accounts** — bank,
receivables, prepaid insurance, fund balances, AP. Verified for OPER/2026
periods 1–9:

| acct_type | actual YTD | budget YTD |
|---|---:|---:|
| ASSET | 118,761.50 | 241,450.00 |
| EQUITY | -364,000.00 | 82,356.40 |
| LIABILITY | -26,387.90 | 28,169.17 |
| **EXPENSE** | **283,167.90** | **0.00** |
| **REVENUE** | **-11,541.50** | **0.00** |

`nbl` has no budget rows at all. Only `public` — the reserved template schema,
not a real tenant — carries $69,231 of P&L budget. So the variance columns of
any budget-vs-actual report render as "no budget" in **every real tenant**
until someone enters one through the app's existing Budget editor
(`set_budget_amts` → `gl_account_amts`).

The original conclusion still holds for a different reason: the UI must
distinguish "no budget set" from "budget of zero", and that state is the
*normal* case today, not an edge case. R-A1 makes it a first-class section
rather than a footnote.

**F-R3 — budget does not live where its table name suggests.** `gl_budget_amt`
is **empty** (0 rows). The live budget is on `gl_account_amts` with
`amount_type = 'BUDGET'`. A report written against `gl_budget_amt`, or against
the `read_budget_amt` endpoint that reads it, would show nothing and look like
a data-entry problem rather than a wrong-source problem.

## Found while building R-A2 (2026-09-20)

**F-R4 — fund balance equity accounts are NOT opening balances.** The obvious
way to get a fund's position is to read the 3000 fund-balance accounts. It is
wrong. In `sava` those carry mid-year transfers, not a brought-forward figure:

| fund | account | period | amount |
|---|---|---:|---:|
| OPER | 3000/3000 Operating Fund Balance | 1 | 2,000.00 |
| OPER | 3000/3000 Operating Fund Balance | 7 | -110,000.00 |
| OPER | 3000/3010 Reserve Fund Balance | 5 | -256,000.00 |
| RES | 3000/3010 Reserve Fund Balance | 1 | -2,000.00 |
| RES | 3000/3010 Reserve Fund Balance | 7 | 30,000.00 |
| RES | 3000/3010 Reserve Fund Balance | 8 | -89,999.90 |
| CAP | 3000/3010 Reserve Fund Balance | 5 | -1,000.00 |

Position is `ASSET + LIABILITY` instead — net assets, with liabilities already
stored negative. The two agree: `-(equity + revenue + expense)` equals the
change in net assets for every fund, which R-A2 uses as a live reconciliation
check.

**F-R5 — there are no OPENING rows in this tenant.** `gl_account_amts` holds
only `ACTUAL` and `BUDGET`, and only for 2026. So every fund opens at zero, and
`comparison_trial_balance_by_fund`'s `opening` column is uniformly zero. Two
consequences: a continuity report reads `0 + movement = closing` until a prior
year is loaded, and the `opening` column — which the server carries onto all
twelve period rows of each account — must be summed over a single period or it
comes out twelve times too large.

**F-R6 — only two of four funds have a target.** `fund_target` holds OPER
50,000 and RES 125,000, both as at 2025-12-31. SPE and CAP have none. This is
the acceptance case for R-A2 and it is live, not hypothetical.

**F-R7 — both reserve funds are marked `unrestricted`.** `gl_funds.restriction`
is `unrestricted` on all four funds, contingency and capital reserve included.
For a condominium corporation a contingency reserve is restricted by statute
and cannot be spent on operations. The data currently asserts the opposite.
Not a reporting bug — a setup question, and one that would change what a
position report is entitled to total together.

**→ FIXED 2026-09-20** in noble-go-server, pending migration + deploy:

- `db/migration/000160_reserve_funds_restricted.{up,down}.sql` sets RES and CAP
  to `temporarily_restricted` — restricted as to *purpose*, released when spent
  on it, which is what a statutory reserve is; `permanently_restricted` would
  assert the principal may never be spent. `public` is corrected explicitly
  because `provisioning.copyTemplateRows` clones it with `SELECT *`, so the
  template fix is what stops this recurring for every new tenant. Guarded on
  `restriction = 'unrestricted'`, so it repairs the seeded default and will not
  overwrite a deliberate classification. Verified up / re-run / down in a
  rolled-back transaction against prod: 2 rows each in `sava`, `nbl`,
  `acme_condos`, plus `public`; OPER and SPE untouched.
- `db/seed/12_gl_funds.sql` now sets `restriction` explicitly, so a fresh
  database does not reintroduce it.
- `api/ai_skills.go` claimed "There is NO structured net-asset-class,
  restriction, or functional-expense column — restriction is expressed by
  CONVENTION in fund and account naming. Infer classification from those
  names." The restriction half was false, and would have had the assistant
  contradict the corrected books. Corrected; the functional-expense half is
  still true and was left.

**Root cause, still open:** the API cannot set `restriction` at all.
`createFundReq` and `updateFundReq` (`api/gl_funds.go:18-27`) have no such
field and the sqlc queries never mention it, so every fund created through the
product takes the `unrestricted` default with no way to correct it in-app. The
migration repairs today's data; without a write path the defect returns with
the next fund anyone creates. Needs request fields, handler + query changes,
an OpenAPI entry and a web control — a feature, not part of this repair.

**Also open:** the agent has no fund-listing tool. `ai_skills.go` references
`list_funds` twice; the tool set in `api/ai_tools.go` has no such tool and
nothing else returns fund metadata, so the assistant cannot read the
classification. Pre-existing; one reference remains in the reserve-adequacy
paragraph.

**Not touched:** SPE `Special Levy Fund`. A special levy is raised for a named
purpose and is restricted by the same reasoning, but whether a tenant uses that
fund that way is a books question. The migration prints a per-schema notice
naming it so the decision is visible rather than forgotten.
