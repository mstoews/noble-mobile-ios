//
//  OperatingStatementTests.swift
//  nbledgerTests
//
//  The accounting in the operating statement: sign convention, what counts as
//  favourable, and what gets left out. These are the parts a board would act
//  on, and the parts that are wrong in a way nobody notices.
//

import Foundation
import Testing
@testable import nbledger

private func cell(
    _ child: Int, _ type: String, period: Int, actual: Double = 0, budget: Double = 0,
    account: Int = 5000, description: String = "Account"
) -> ComparisonTrialBalanceRow {
    ComparisonTrialBalanceRow(
        account: account, child: child, description: description, acctType: type,
        period: period, opening: 0, actual: actual, budget: budget, closing: 0
    )
}

@MainActor
@Suite(.serialized)
struct OperatingStatementTests {

    // MARK: Sign

    @Test func revenueIsFlippedOutOfBookSign() {
        // The wire is debits-positive, so revenue arrives NEGATIVE. Shown as
        // it arrives, a board reads "Revenue −11,541" as income being negative.
        let grid = [
            cell(4000, "REVENUE", period: 9, actual: -11_541.50, budget: -12_000),
            cell(5010, "EXPENSE", period: 9, actual: 788.90, budget: 700),
        ]
        let s = OperatingStatement.build(from: grid, upTo: 9, span: .month)

        #expect(s.revenueActual == 11_541.50)
        #expect(s.revenueBudget == 12_000)
        #expect(s.expenseActual == 788.90)
        // Net is revenue less expenses, in display sign.
        #expect(abs(s.netActual - (11_541.50 - 788.90)) < 0.001)
    }

    // MARK: Favourable is not the same arithmetic on each side

    @Test func underSpendingIsFavourableAndUnderEarningIsNot() {
        let grid = [
            cell(5010, "EXPENSE", period: 9, actual: 700, budget: 1_000),   // spent less
            cell(4000, "REVENUE", period: 9, actual: -9_000, budget: -10_000), // earned less
        ]
        let s = OperatingStatement.build(from: grid, upTo: 9, span: .month)

        let expense = try! #require(s.expenses.first)
        // Under budget on an expense is money saved.
        #expect(expense.variance == 300)
        #expect(!expense.isAdverse)

        let revenue = try! #require(s.revenue.first)
        // Under budget on revenue is money missing — the same sign of
        // difference, the opposite meaning.
        #expect(revenue.variance == -1_000)
        #expect(revenue.isAdverse)
    }

    @Test func overSpendingIsAdverse() {
        let s = OperatingStatement.build(
            from: [cell(5020, "EXPENSE", period: 9, actual: 1_200, budget: 1_000)],
            upTo: 9, span: .month
        )
        let row = try! #require(s.rows.first)
        #expect(row.variance == -200)
        #expect(row.isAdverse)
        #expect(row.variancePercent == -20)
    }

    // MARK: No budget

    @Test func noBudgetIsNotOneHundredPercentOver() {
        // Real spend against a zero budget is NOT "100% over" — it means
        // nobody set one. Reporting a percentage there invents a number a
        // board might act on.
        let s = OperatingStatement.build(
            from: [cell(5010, "EXPENSE", period: 9, actual: 788.90, budget: 0)],
            upTo: 9, span: .month
        )
        let row = try! #require(s.rows.first)
        #expect(!row.hasBudget)
        #expect(row.variancePercent == nil)
        #expect(s.hasNoBudget)
    }

    @Test func aFundWithSomeBudgetIsNotFlaggedAsUnbudgeted() {
        let s = OperatingStatement.build(
            from: [
                cell(5010, "EXPENSE", period: 9, actual: 700, budget: 0),
                cell(5020, "EXPENSE", period: 9, actual: 900, budget: 1_000),
            ],
            upTo: 9, span: .month
        )
        #expect(!s.hasNoBudget)
    }

    // MARK: Span

    @Test func yearToDateSumsPeriodsOneThroughSelected() {
        // `actual` is the PERIOD's amount, not cumulative — YTD has to sum.
        let grid = [
            cell(5010, "EXPENSE", period: 7, actual: 100, budget: 120),
            cell(5010, "EXPENSE", period: 8, actual: 200, budget: 120),
            cell(5010, "EXPENSE", period: 9, actual: 300, budget: 120),
            cell(5010, "EXPENSE", period: 10, actual: 999, budget: 120), // future
        ]

        let month = OperatingStatement.build(from: grid, upTo: 9, span: .month)
        #expect(month.expenseActual == 300)
        #expect(month.expenseBudget == 120)

        let ytd = OperatingStatement.build(from: grid, upTo: 9, span: .yearToDate)
        // Periods 1..9 only — period 10 has not happened.
        #expect(ytd.expenseActual == 600)
        #expect(ytd.expenseBudget == 360)
    }

    // MARK: What is excluded

    @Test func balanceSheetAccountsAreExcluded() {
        // An operating statement is a flow report. This filter is load-bearing
        // in the live data: the budget loaded in `sava` sits ENTIRELY on
        // balance-sheet accounts, so summing everything would show a healthy
        // budget that has nothing to do with operations.
        let grid = [
            cell(1000, "ASSET", period: 9, actual: 5_000, budget: 20_000, account: 1000),
            cell(2000, "LIABILITY", period: 9, actual: 1_000, budget: 35_000, account: 2000),
            cell(3000, "EQUITY", period: 9, actual: 2_000, budget: 26_000, account: 3000),
            cell(5010, "EXPENSE", period: 9, actual: 788.90, budget: 0),
        ]
        let s = OperatingStatement.build(from: grid, upTo: 9, span: .month)

        #expect(s.rows.count == 1)
        #expect(s.rows.first?.child == 5010)
        // The balance-sheet budget must not leak into the statement's totals.
        #expect(s.expenseBudget == 0)
        #expect(s.hasNoBudget)
    }

    @Test func emptyAccountsAreDroppedFromTheDenseGrid() {
        // The server emits a dense 1..12 grid per leaf account, so most
        // accounts arrive as twelve empty rows.
        let grid = (1...12).map { cell(5999, "EXPENSE", period: $0) }
            + [cell(5010, "EXPENSE", period: 9, actual: 788.90)]
        let s = OperatingStatement.build(from: grid, upTo: 9, span: .yearToDate)

        #expect(s.rows.count == 1)
        #expect(s.rows.first?.child == 5010)
    }

    // MARK: Ordering

    @Test func worstVarianceSortsFirst() {
        // This report is read to find what went wrong.
        let grid = [
            cell(5010, "EXPENSE", period: 9, actual: 100, budget: 500),   // +400 good
            cell(5020, "EXPENSE", period: 9, actual: 900, budget: 500),   // -400 bad
            cell(5030, "EXPENSE", period: 9, actual: 500, budget: 500),   //    0
        ]
        let s = OperatingStatement.build(from: grid, upTo: 9, span: .month)
        #expect(s.rows.map(\.child) == [5020, 5030, 5010])
    }
}
