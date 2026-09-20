# Verification — financial reporting (R-A3)

Date: 2026-09-20. Covers R-A1 (Operating Statement) and R-A2 (Fund Position).

**Verdict: SHIP.** Four findings, all four fixed. Both reports reconcile to the
Accounts tab, which is the figure a treasurer already trusts.

Run the same way as the realignment's A8, and for the same reason: three of that
plan's four wrong calls came from trusting a schema over the data.

---

## 1. Endpoint re-derivation — CLEAN

The realignment missed variable-built paths by grepping only `request("…")`,
which hid F16 (see `../api-realignment/VERIFICATION.md` §8). Re-derived with
both shapes — a literal first argument, and `let path = "…"` assigned then
passed — via `scratchpad/endpoints.py`.

| | count |
|---|---:|
| client endpoints (76 total, normalised) | 76 |
| present in `docs/openapi.json` | 74 |
| served by `api/routes.go` | 76 |

The script had a bug of its own on the first pass: its interpolation
normaliser used `\\\([^)]*\)`, which stops at the inner close paren of
`\(escapePathComponent(id))` and leaves a stray `)`. Four asset paths looked
undocumented as a result. Fixed to allow one level of nesting; the four resolve.

The two genuinely undocumented paths are `POST plaid_link_token` and
`POST get_access_token`. Both are real routes, both are already on
`knownUndocumentedRoutes` in `api/openapi_drift_test.go` — tracked pre-existing
debt on a list that may only shrink. Not introduced by this work, and the client
is correct in both cases.

Reporting endpoints, all documented and all served:

```
/account_balances                  /read_aging_bills_by_period
/comparison_trial_balance_by_fund  /read_budget_accounts
/fund_targets_list                 /read_journal_header_by_period
/funds_list                        /set_budget_amts
/get_current_active_period
```

## 2. Required-field (decode) audit — 1 finding, fixed

Only non-optional stored properties can throw, so those are the whole risk
surface. Two `Codable` models were added by this work; both audited against the
Go struct the handler actually serialises, not the spec.

### `ComparisonTrialBalanceRow` → `api.comparisonTrialBalanceRow` — OK

All nine fields non-optional, and all nine safe. This endpoint does **not**
pass pgtype straight through — it has its own wire struct:

| client | Go | why it cannot be null |
|---|---|---|
| `account`, `child`, `period` : `Int` | `int32` | plain scalars |
| `description`, `acctType` : `String` | `string` | handler flattens `r.Description.String` / `r.AcctType.String`, so a NULL becomes `""` |
| `opening`, `actual`, `budget`, `closing` : `Double` | `float64` | via `numericToFloat`, which returns `0` for invalid **and** NaN (`api/journal_entries_asof.go:62`) — never emits a non-finite number |

This is why these four are plain `Double` and not `decodeFlexibleDouble`, which
looks like a convention violation and is not: the handler has already converted
them. Recorded so nobody "fixes" it later.

### `FundTarget` → raw `db.FundTarget` sqlc row — 1 FAIL, fixed

Raw row, so pgtype shapes reach the client unflattened. Column nullability
checked against `information_schema`, not the spec:

| client | Go | column | verdict |
|---|---|---|---|
| `id` : `String` | `uuid.UUID` | NOT NULL | OK |
| `fund` : `String` | `string` | NOT NULL | OK |
| `targetBalance` : `Double` | `pgtype.Numeric` | NOT NULL | **FAIL → fixed** |
| `notes` : `String?` | `pgtype.Text` | nullable | OK |
| `updatedBy` : `String?` | `pgtype.Text` | nullable | OK |
| `asOfDate` : `String?` | `pgtype.Date` | NOT NULL | OK (optional is lenient in the safe direction) |

### Finding R-A3-1 (silent wrong number): `target_balance` defaulted to zero

`targetBalance = try c.decodeFlexibleDouble(forKey: .targetBalance) ?? 0`.

The column is NOT NULL so the branch is unreachable today, but the failure mode
if it were ever reached is the exact lie R-D5 and R-D10 exist to prevent,
arrived at from a third direction: a target of **zero** is a meaningful value
distinct from **no target**, and a fund would report its entire balance as a
surplus against a target nobody set.

Fixed: throws `DecodingError.dataCorruptedError`, which surfaces as the view's
error state. Pinned by `aMissingTargetBalanceThrowsRatherThanDecodingAsZero`.

Note, not a finding: `pgtype.Date` can also emit `"infinity"` / `"-infinity"`.
`asOfDate` is a `String?`, so that decodes and renders as "as at infinity" —
cosmetically odd, cannot crash, and cannot occur while the column holds real
dates.

## 3. Treasurer's-eye reconciliation — CLEAN

The question the plan asked: do the numbers tie to something already trusted?
The Accounts tab (`LedgerView` → `/account_balances`) is that thing.

`/account_balances` for `sava` 2026, all funds:

| acct_type | balance |
|---|---:|
| ASSET | 258,824.40 |
| LIABILITY | -26,387.90 |
| EQUITY | -426,999.90 |
| REVENUE | -90,604.50 |
| EXPENSE | 285,167.90 |

**Fund Position ties exactly.** Assets 258,824.40 less liabilities 26,387.90 =
**232,436.50**, which is the report's "Total position" to the cent. Per fund,
both sides of the movement check agree:

| fund | position (balance sheet) | movement (from flows) |
|---|---:|---:|
| OPER | 92,373.60 | 92,373.60 |
| RES | 140,062.90 | 140,062.90 |
| CAP | 0.00 | 0.00 |
| SPE | — no rows — | — |

**The Operating Statement deliberately does NOT tie**, and that is correct.
It is one fund; the Accounts tab is all funds:

| | Accounts tab (all funds) | Operating Statement (OPER) | difference |
|---|---:|---:|---|
| EXPENSE | 285,167.90 | 283,167.90 | RES 1,000 + CAP 1,000 |
| REVENUE | -90,604.50 | -11,541.50 | RES holds -79,063.00 |

Written down because the gap looks like a bug and is not, and because the
reserve fund carrying 79,063.00 of revenue against 1,000 of expense is worth
someone's attention on its own.

### Accepted, not fixed: a latent basis difference

`/account_balances` computes `balance` as OPENING + **full-year** ACTUAL (all
twelve periods). Fund Position is as at the **active period**. In a tenant with
postings dated after the active period the two screens would disagree.

Checked: the last posted ACTUAL period is **8** in both `sava` and `nbl`, and
the active period is 9. So the difference is latent, not live, and the two
figures coincide today (232,436.50 either way).

Accepted rather than fixed, because **Fund Position's basis is the correct
one** — a position "as at period 9" must not include period 11 postings. If the
two ever diverge the Accounts tab is the screen that is wrong.

## 4. Behaviour under failure — 3 findings, all fixed

The audits above cover wrong *shapes*. These are wrong *numbers* shown
confidently when something upstream fails, which is the harder class on a
financial report.

### Finding R-A3-2 (wrong explanation): no active period blamed the books

`OperatingStatementView.load()` did `period = try? await …` and, on nil, fell
through to `loadGrid()`, whose guard returned silently. The screen then showed
**"No activity in this period."** — blaming the ledger for a lookup that
failed. R-A2 already handled this correctly, which is how the inconsistency
surfaced.

Fixed: explicit `"No active period is open."`, matching R-A2.

### Finding R-A3-3 (wrong label on right numbers): stale fund after a failed switch

The worst of the four. `loadGrid()` assigned `grid` only on success, and the
error state renders only `if let errorMessage, grid.isEmpty`. So switching funds
and having the second fetch fail left **fund A's numbers on screen under fund
B's heading**, with the error suppressed because the grid was non-empty.

Fixed: `grid = []` before the fetch, so a failure shows the error rather than
the previous fund's statement.

### Finding R-A3-4 (silent wrong number): an unloaded fund totalled as zero

`FundPositionView.load()` did `guard let grid = try? … else { continue }`. A
fund whose trial balance failed to load appeared at **$0.00** and was totalled
as such — understating the corporation by whatever that fund holds, with nothing
on screen to say so.

Fixed: failures are collected, those funds are dropped from the report rather
than carried at zero, and a named warning section says which ones are missing
from the totals. Pinned by `aFundDroppedFromTheReportIsNotTotalledAsZero`.

## 5. Tests and live walk

| | |
|---|---|
| unit suite | **104/104 across 15 suites** |
| new for R-A3 | 2 (R-A3-1, R-A3-4) |
| live screenshot walk | `FundPositionScreenshotTests`, `OperatingStatementScreenshotTests` — both pass against `sava`, re-run after the fixes with no change to any figure |

## 6. Standing data findings (not code)

Carried from FINDINGS.md because they limit what these reports can say:

- **F-R2** — no real tenant has a P&L budget, so R-A1's variance columns are
  empty everywhere. The Budget editor already writes the right place.
- **F-R5** — no OPENING rows exist, so every fund opens at zero and R-A2's
  continuity line reads `0 + movement = closing`.
- **F-R7** — `gl_funds.restriction` is `unrestricted` on all four funds,
  including both reserve funds. For a condominium corporation a contingency
  reserve is restricted by statute. This one changes what Fund Position is
  entitled to total together, so it is the most consequential of the three.
