//
//  BudgetService.swift
//  nbledger
//
//  Budget derivation layer — the iOS counterpart to noble-web's BudgetStore
//  (noble-web/src/app/store/budget.store.ts). It rolls the per-account monthly
//  buckets that `/account_balances` already returns (budget_1..12, period_1..12,
//  previous_1..12) into the YTD / variance / year-end figures the budget screens
//  render. No new network calls: the enriched account rows are the single source.
//
//  Parity notes with the web feature:
//   • Revenue accounts are credit-stored (raw sums read negative) and are
//     sign-flipped to display-positive here, exactly as budget.store's computeds
//     do. Expenses pass through positive.
//   • "Months elapsed" is a real-time client calc — max(calendarMonth - 1, 1) —
//     mirroring the web's `Math.max(new Date().getMonth(), 1)`. Only the fiscal
//     *year* comes from the server's active period.
//   • This reads the all-funds aggregate (`/account_balances`), whereas the web
//     dashboard is single-fund. A fund selector can layer on later via the
//     dedicated /read_budget_accounts?fund= endpoint.
//

import Foundation

// MARK: - Account monthly accessors

extension Account {
    /// [Jan…Dec] planned budget, nils coalesced to 0.
    var monthlyBudget: [Double] {
        [budget1, budget2, budget3, budget4, budget5, budget6,
         budget7, budget8, budget9, budget10, budget11, budget12].map { $0 ?? 0 }
    }

    /// [Jan…Dec] current-year actual (booked activity), nils coalesced to 0.
    var monthlyActual: [Double] {
        [period1, period2, period3, period4, period5, period6,
         period7, period8, period9, period10, period11, period12].map { $0 ?? 0 }
    }

    /// [Jan…Dec] prior-year actual, nils coalesced to 0.
    var monthlyPrevious: [Double] {
        [previous1, previous2, previous3, previous4, previous5, previous6,
         previous7, previous8, previous9, previous10, previous11, previous12].map { $0 ?? 0 }
    }

    /// Case-normalized type test — the catalog casing drifts (REVENUE vs Revenue).
    var isRevenueAccount: Bool {
        let t = (acctType ?? "").lowercased()
        return t == "revenue" || t == "income"
    }

    var isExpenseAccount: Bool {
        (acctType ?? "").lowercased() == "expense"
    }
}

// MARK: - View models

/// One month's actual vs budget for a series (line or aggregate). Values are
/// already sign-normalized (revenue flipped positive).
struct BudgetMonthPoint: Identifiable {
    let month: Int          // 1…12
    let actual: Double
    let budget: Double
    var id: Int { month }
    var label: String { BudgetReport.monthLabels[month - 1] }
}

/// A single GL account rolled up for the analysis / forecast grids.
struct BudgetLine: Identifiable {
    let child: Int
    let account: Int
    let description: String
    let isRevenue: Bool
    let monthly: [BudgetMonthPoint]   // 12 entries, sign-normalized
    let ytdActual: Double
    let ytdBudget: Double
    let fullYearBudget: Double
    let yearEndProjection: Double     // elapsed months actual + remaining months budget

    var id: Int { child }

    var ytdVariance: Double { ytdActual - ytdBudget }
    var yearEndVariance: Double { yearEndProjection - fullYearBudget }

    /// % over/under YTD budget, signed (positive = actual above budget).
    var ytdVariancePct: Double {
        ytdBudget == 0 ? 0 : (ytdActual - ytdBudget) / abs(ytdBudget) * 100
    }

    /// Favorable = revenue above plan, or expense below plan.
    var ytdFavorable: Bool { isRevenue ? ytdVariance >= 0 : ytdVariance <= 0 }
    var yearEndFavorable: Bool { isRevenue ? yearEndVariance >= 0 : yearEndVariance <= 0 }
}

/// A description-grouped slice for the expense-distribution donut.
struct BudgetCategory: Identifiable {
    let name: String
    let actual: Double
    let budget: Double
    var id: String { name }
}

// MARK: - Report

/// The fully-derived budget picture for one fiscal year — everything the
/// BudgetView tabs consume. Build with `BudgetReport.build(...)`.
struct BudgetReport {
    static let monthLabels = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                              "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    let year: Int
    /// Completed months (1…12); YTD sums cover months 1…monthsElapsed.
    let monthsElapsed: Int

    let revenueLines: [BudgetLine]
    let expenseLines: [BudgetLine]
    let revenueMonthly: [BudgetMonthPoint]
    let expenseMonthly: [BudgetMonthPoint]
    let cashFlowMonthly: [BudgetMonthPoint]
    let expenseCategories: [BudgetCategory]

    // KPI aggregates (sign-normalized).
    let totalRevenueYTD: Double
    let totalRevenueBudgetYTD: Double
    let totalExpenseYTD: Double
    let totalExpenseBudgetYTD: Double
    let projectedRevenue: Double
    let projectedExpense: Double
    let fullYearRevenueBudget: Double
    let fullYearExpenseBudget: Double

    var netCashFlowYTD: Double { totalRevenueYTD - totalExpenseYTD }
    var netCashFlowBudgetYTD: Double { totalRevenueBudgetYTD - totalExpenseBudgetYTD }
    var projectedNet: Double { projectedRevenue - projectedExpense }
    var fullYearBudgetNet: Double { fullYearRevenueBudget - fullYearExpenseBudget }

    /// The label of the last completed month, for "YTD through …" captions.
    var throughMonthLabel: String { Self.monthLabels[min(max(monthsElapsed, 1), 12) - 1] }

    static func build(accounts: [Account], year: Int, monthsElapsed: Int) -> BudgetReport {
        let elapsed = min(max(monthsElapsed, 1), 12)

        let revenueLines = makeLines(accounts.filter(\.isRevenueAccount),
                                     isRevenue: true, elapsed: elapsed)
        let expenseLines = makeLines(accounts.filter(\.isExpenseAccount),
                                     isRevenue: false, elapsed: elapsed)

        let revenueMonthly = aggregate(revenueLines)
        let expenseMonthly = aggregate(expenseLines)
        let cashFlowMonthly: [BudgetMonthPoint] = zip(revenueMonthly, expenseMonthly).map { rev, exp in
            BudgetMonthPoint(month: rev.month,
                             actual: rev.actual - exp.actual,
                             budget: rev.budget - exp.budget)
        }

        func ytdActual(_ pts: [BudgetMonthPoint]) -> Double {
            pts.prefix(elapsed).reduce(0.0) { $0 + $1.actual }
        }
        func ytdBudget(_ pts: [BudgetMonthPoint]) -> Double {
            pts.prefix(elapsed).reduce(0.0) { $0 + $1.budget }
        }
        func sumProjection(_ lines: [BudgetLine]) -> Double {
            lines.reduce(0.0) { $0 + $1.yearEndProjection }
        }
        func sumFullYear(_ lines: [BudgetLine]) -> Double {
            lines.reduce(0.0) { $0 + $1.fullYearBudget }
        }

        let sortedRevenue = revenueLines.sorted { $0.ytdActual > $1.ytdActual }
        let sortedExpense = expenseLines.sorted { $0.ytdActual > $1.ytdActual }

        return BudgetReport(
            year: year,
            monthsElapsed: elapsed,
            revenueLines: sortedRevenue,
            expenseLines: sortedExpense,
            revenueMonthly: revenueMonthly,
            expenseMonthly: expenseMonthly,
            cashFlowMonthly: cashFlowMonthly,
            expenseCategories: categories(expenseLines, topN: 8),
            totalRevenueYTD: ytdActual(revenueMonthly),
            totalRevenueBudgetYTD: ytdBudget(revenueMonthly),
            totalExpenseYTD: ytdActual(expenseMonthly),
            totalExpenseBudgetYTD: ytdBudget(expenseMonthly),
            projectedRevenue: sumProjection(revenueLines),
            projectedExpense: sumProjection(expenseLines),
            fullYearRevenueBudget: sumFullYear(revenueLines),
            fullYearExpenseBudget: sumFullYear(expenseLines)
        )
    }

    // MARK: Builders

    private static func makeLines(_ accounts: [Account], isRevenue: Bool, elapsed: Int) -> [BudgetLine] {
        let sign: Double = isRevenue ? -1 : 1   // revenue is credit-stored
        // Flip then normalize: -1 * 0 yields IEEE -0.0, which renders "-$0.00".
        func flip(_ v: Double) -> Double { let r = v * sign; return r == 0 ? 0 : r }
        return accounts.map { acct in
            let actual = acct.monthlyActual.map(flip)
            let budget = acct.monthlyBudget.map(flip)
            let monthly = (0..<12).map { i in
                BudgetMonthPoint(month: i + 1, actual: actual[i], budget: budget[i])
            }
            let ytdActual = actual.prefix(elapsed).reduce(0, +)
            let ytdBudget = budget.prefix(elapsed).reduce(0, +)
            let fullYearBudget = budget.reduce(0, +)
            // Elapsed months use actuals; remaining months fall back to budget.
            let projection = (0..<12).reduce(0.0) { sum, i in
                sum + (i < elapsed ? actual[i] : budget[i])
            }
            return BudgetLine(
                child: acct.child,
                account: acct.account,
                description: acct.displayName,
                isRevenue: isRevenue,
                monthly: monthly,
                ytdActual: ytdActual,
                ytdBudget: ytdBudget,
                fullYearBudget: fullYearBudget,
                yearEndProjection: projection
            )
        }
    }

    private static func aggregate(_ lines: [BudgetLine]) -> [BudgetMonthPoint] {
        (0..<12).map { i in
            BudgetMonthPoint(
                month: i + 1,
                actual: lines.reduce(0) { $0 + $1.monthly[i].actual },
                budget: lines.reduce(0) { $0 + $1.monthly[i].budget }
            )
        }
    }

    /// Group lines by description, keep the top N by actual, collapse the tail
    /// into "Other". Only positive-actual categories feed the donut.
    private static func categories(_ lines: [BudgetLine], topN: Int) -> [BudgetCategory] {
        let grouped = Dictionary(grouping: lines, by: \.description)
        let rolled = grouped.map { name, group in
            BudgetCategory(name: name,
                           actual: group.reduce(0) { $0 + $1.ytdActual },
                           budget: group.reduce(0) { $0 + $1.ytdBudget })
        }
        .filter { $0.actual > 0 }
        .sorted { $0.actual > $1.actual }

        guard rolled.count > topN else { return rolled }
        let head = Array(rolled.prefix(topN))
        let tail = rolled.dropFirst(topN)
        let other = BudgetCategory(name: "Other",
                                   actual: tail.reduce(0) { $0 + $1.actual },
                                   budget: tail.reduce(0) { $0 + $1.budget })
        return head + [other]
    }
}

// MARK: - Fetch

extension APIService {
    /// Loads the enriched chart of accounts and derives the budget report for
    /// the current fiscal year. Reuses `/account_balances` (all funds) and the
    /// server's active period for the year; months-elapsed is a client calc.
    func fetchBudgetReport() async throws -> BudgetReport {
        let accounts = try await fetchAccountList()

        var year = Calendar.current.component(.year, from: Date())
        if let period = try? await fetchCurrentActivePeriod() {
            year = period.periodYear
        }
        // Matches noble-web: completed calendar months, floored at 1.
        let month = Calendar.current.component(.month, from: Date())
        let monthsElapsed = max(month - 1, 1)

        return BudgetReport.build(accounts: accounts, year: year, monthsElapsed: monthsElapsed)
    }
}
