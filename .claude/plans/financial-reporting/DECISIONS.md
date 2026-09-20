# Financial Reporting on Mobile — Decisions

Rulings for what the app reports and what it deliberately does not. Findings
referenced as F-R1…F-R3 live in ./FINDINGS.md.

R-D1: One report, built properly, before any second one.
→ The Operating Statement: budget vs actual, month and year-to-date, with
variance, drillable to the account.
→ Why: it is the report a condo board reviews monthly, and "are we on budget?"
is the question directors actually ask. Nothing in the app answers it today.
Shipping three half-reports would answer it three times badly.

R-D2: The phone answers "does anything need me", not "show me the ledger".
→ No trial balance, no full balance sheet, no report designer on mobile.
→ Why: the Excel add-in already serves that need through `NBL_TB_Data`, and a
40-row account grid on a six-inch screen invites scrolling rather than
answering a question. The Dashboard and sign-off queue are already shaped
around attention; a variance summary fits that shape and a trial balance does
not. This is a ruling about medium, not about value — those reports are
valuable, just not here.

R-D3: `comparison_trial_balance_by_fund` is the data source, not a new endpoint.
→ `?fund=OPER&year=<year>` returns, per account per period, `actual`, `budget`,
`opening` and `closing`. Month column, YTD roll-up and variance all derive from
one call.
→ Why: no server work is needed, and the alternative sources are worse fits —
`read_income_statement_tb` is better when a true prior-year comparative is
wanted (it takes a full comparative range), and `expense_comparison_by_prd`
covers only expenses and only one period.

R-D4: Funds come from `funds_list`, never from a literal.
→ Why: F-R1. The codes are `OPER`/`RES`/`CAP`/`SPE`, not `OPERATING`, and not
the `fund_code` enum that migration 000078 declares and `gl_funds` ignores.
Hardcoding one is how the API realignment lost a working feature and planned an
impossible one; the habit is worth keeping.

R-D5: "No budget set" is a distinct state from "budget of zero".
→ A fund with no BUDGET rows shows as unbudgeted, not as 100% underspent.
→ Why: F-R2. Rendering an unbudgeted fund as fully underspent would be a
confident lie in a report a board relies on.
→ Strengthened by R-A1 (2026-09-20): F-R2 was corrected — *no* real tenant has
a P&L budget, so this is the normal path, not the edge case. R-A1 therefore
gives it a titled section ("No budget set for this fund") that names the way
out, rather than a muted footnote.

R-D6: Read budget from `gl_account_amts` / `comparison_trial_balance_by_fund`,
never from `gl_budget_amt` or `read_budget_amt`.
→ Why: F-R3. `gl_budget_amt` is empty; the live budget is `amount_type='BUDGET'`
on `gl_account_amts`. A report against the empty table shows nothing and reads
as a data-entry problem rather than a wrong-source one.

## Open — worth deciding before R-A2 starts

R-O1: What the second report should be.
→ The natural candidate is a fund position vs target: opening, movement,
closing, against `fund_target` (which holds real rows — OPER 50,000 and RES
125,000 as of 2025-12-31). A full reserve-study continuity report is NOT
available: `reserve_study` and `reserve_component` do not exist in this tenant
and `condo_reserve_component` holds one row (F-R3 neighbourhood).
→ Recommendation: scope it to position-vs-target and leave the study out until
component data exists. Confirm before building — a reserve report that looks
like a study but is not one would be worse than none.
