//
//  FundPositionTests.swift
//  nbledgerTests
//
//  The accounting in the fund position report: what makes up a position, what
//  a missing target must not become, and the continuity that lets a reader
//  check the closing figure without trusting it.
//

import Foundation
import Testing
@testable import nbledger

private func cell(
    _ child: Int, _ type: String, period: Int,
    opening: Double = 0, actual: Double = 0, closing: Double = 0,
    account: Int = 1000, description: String = "Account"
) -> ComparisonTrialBalanceRow {
    ComparisonTrialBalanceRow(
        account: account, child: child, description: description, acctType: type,
        period: period, opening: opening, actual: actual, budget: 0, closing: closing
    )
}

private func fund(_ code: String, _ name: String) -> FundRef {
    FundRef(id: "id-\(code)", fund: code, description: name, restriction: "unrestricted")
}

/// A fund whose whole twelve-period grid is generated from per-period activity,
/// the way the server's window function does it: closing = opening + running
/// actual. Keeps the fixtures honest instead of hand-writing closings.
private func grid(
    opening: [Int: Double] = [:],
    activity: [(child: Int, type: String, period: Int, amount: Double)],
    accounts: [Int: String]
) -> [ComparisonTrialBalanceRow] {
    var rows: [ComparisonTrialBalanceRow] = []
    for (child, type) in accounts {
        var running = opening[child] ?? 0
        for period in 1...12 {
            let actual = activity.filter { $0.child == child && $0.period == period }
                .map(\.amount).reduce(0, +)
            running += actual
            rows.append(cell(
                child, type, period: period,
                opening: opening[child] ?? 0, actual: actual, closing: running
            ))
        }
    }
    return rows
}

@MainActor
@Suite(.serialized)
struct FundPositionTests {

    // MARK: What a position is made of

    @Test func positionIsAssetsPlusLiabilitiesNotTheEquityAccount() {
        // The live books post transfers to the 3000 fund-balance accounts
        // mid-year, so equity is NOT an opening balance. Position has to come
        // off the balance sheet: assets arrive positive, liabilities negative.
        let g = grid(
            activity: [
                (1000, "ASSET", 3, 118_761.50),
                (2000, "LIABILITY", 3, -26_387.90),
                (3000, "EQUITY", 7, -110_000),
                (5000, "EXPENSE", 3, 110_000),
            ],
            accounts: [1000: "ASSET", 2000: "LIABILITY", 3000: "EQUITY", 5000: "EXPENSE"]
        )
        let r = FundPositionReport.build(
            grids: ["OPER": g], funds: [fund("OPER", "Operating fund")], targets: [], upTo: 9
        )

        // 118,761.50 - 26,387.90, and nothing from equity or expense.
        #expect(r.positions[0].closing == 92_373.60)
    }

    @Test func revenueAndExpenseAreExcludedFromPosition() {
        let g = grid(
            activity: [
                (1000, "ASSET", 1, 1_000),
                (4000, "REVENUE", 1, -5_000),
                (5000, "EXPENSE", 1, 5_000),
            ],
            accounts: [1000: "ASSET", 4000: "REVENUE", 5000: "EXPENSE"]
        )
        let r = FundPositionReport.build(
            grids: ["RES": g], funds: [fund("RES", "Reserve")], targets: [], upTo: 6
        )

        // Flows moved the position; they are not part of it.
        #expect(r.positions[0].closing == 1_000)
    }

    @Test func openingIsNotMultipliedByTheTwelvePeriodsItRepeatsOn() {
        // The server carries OPENING onto every one of the twelve period rows.
        // Summing the grid naively gives twelve times the opening balance.
        let g = grid(
            opening: [1000: 50_000],
            activity: [(1000, "ASSET", 4, 5_000)],
            accounts: [1000: "ASSET"]
        )
        let r = FundPositionReport.build(
            grids: ["OPER": g], funds: [fund("OPER", "Operating")], targets: [], upTo: 9
        )

        #expect(r.positions[0].opening == 50_000)
        #expect(r.positions[0].closing == 55_000)
        #expect(r.positions[0].movement == 5_000)
    }

    @Test func closingIsAsAtTheSelectedPeriodNotTheWholeYear() {
        let g = grid(
            activity: [(1000, "ASSET", 3, 10_000), (1000, "ASSET", 11, 90_000)],
            accounts: [1000: "ASSET"]
        )
        let funds = [fund("OPER", "Operating")]

        let atPeriod9 = FundPositionReport.build(grids: ["OPER": g], funds: funds, targets: [], upTo: 9)
        let atPeriod12 = FundPositionReport.build(grids: ["OPER": g], funds: funds, targets: [], upTo: 12)

        #expect(atPeriod9.positions[0].closing == 10_000)
        #expect(atPeriod12.positions[0].closing == 100_000)
    }

    // MARK: The missing target

    @Test func aFundWithNoTargetHasNoGapRatherThanAGapOfItsWholeBalance() {
        let g = grid(activity: [(1000, "ASSET", 1, 140_062.90)], accounts: [1000: "ASSET"])
        let r = FundPositionReport.build(
            grids: ["CAP": g], funds: [fund("CAP", "Capital Reserve")], targets: [], upTo: 9
        )

        let p = r.positions[0]
        #expect(p.target == nil)
        #expect(p.gap == nil)
        #expect(p.fundedPercent == nil)
        #expect(p.hasTarget == false)
        // The balance is still reported; only the comparison is withheld.
        #expect(p.closing == 140_062.90)
    }

    @Test func totalsCoverTargetedFundsOnlySoAShortfallCannotBecomeASurplus() {
        // OPER holds 40,000 against a 50,000 target — 10,000 short. SPE holds
        // 60,000 with no target. Totalling all closings against the one target
        // would report a 50,000 surplus on a fund that is under water.
        let oper = grid(activity: [(1000, "ASSET", 1, 40_000)], accounts: [1000: "ASSET"])
        let spe = grid(activity: [(1000, "ASSET", 1, 60_000)], accounts: [1000: "ASSET"])

        let r = FundPositionReport.build(
            grids: ["OPER": oper, "SPE": spe],
            funds: [fund("OPER", "Operating"), fund("SPE", "Special Levy")],
            targets: [FundTarget(id: "t1", fund: "OPER", targetBalance: 50_000)],
            upTo: 9
        )

        #expect(r.totalClosing == 100_000)
        #expect(r.totalTarget == 50_000)
        #expect(r.totalTargetedClosing == 40_000)
        #expect(r.totalGap == -10_000)
        #expect(r.hasUntargetedFunds)
        #expect(r.targeted.map(\.fund) == ["OPER"])
        #expect(r.untargeted.map(\.fund) == ["SPE"])
    }

    @Test func noTargetsAnywhereLeavesTheTotalGapUnstatedNotZero() {
        let g = grid(activity: [(1000, "ASSET", 1, 5_000)], accounts: [1000: "ASSET"])
        let r = FundPositionReport.build(
            grids: ["CAP": g], funds: [fund("CAP", "Capital")], targets: [], upTo: 9
        )

        #expect(r.totalTarget == nil)
        #expect(r.totalGap == nil)
        // A zero gap would read as "exactly on target".
        #expect(r.totalClosing == 5_000)
    }

    @Test func aTargetOfZeroIsNotAMissingTarget() {
        let g = grid(activity: [(1000, "ASSET", 1, 1_000)], accounts: [1000: "ASSET"])
        let r = FundPositionReport.build(
            grids: ["SPE": g], funds: [fund("SPE", "Special Levy")],
            targets: [FundTarget(id: "t", fund: "SPE", targetBalance: 0)],
            upTo: 9
        )

        let p = r.positions[0]
        #expect(p.hasTarget)
        #expect(p.gap == 1_000)
        // Funded percent against a zero target is not a number to show.
        #expect(p.fundedPercent == nil)
    }

    @Test func targetsMatchTheirFundRegardlessOfCase() {
        let g = grid(activity: [(1000, "ASSET", 1, 10_000)], accounts: [1000: "ASSET"])
        let r = FundPositionReport.build(
            grids: ["oper": g], funds: [fund("oper", "Operating")],
            targets: [FundTarget(id: "t", fund: "OPER", targetBalance: 8_000)],
            upTo: 9
        )

        #expect(r.positions[0].gap == 2_000)
    }

    // MARK: Gap direction

    @Test func aShortfallIsNegativeAndASurplusPositive() {
        let short = grid(activity: [(1000, "ASSET", 1, 90_000)], accounts: [1000: "ASSET"])
        let over = grid(activity: [(1000, "ASSET", 1, 140_062.90)], accounts: [1000: "ASSET"])

        let r = FundPositionReport.build(
            grids: ["RES": short, "OPER": over],
            funds: [fund("RES", "Reserve"), fund("OPER", "Operating")],
            targets: [
                FundTarget(id: "t1", fund: "RES", targetBalance: 125_000),
                FundTarget(id: "t2", fund: "OPER", targetBalance: 50_000),
            ],
            upTo: 9
        )

        let res = try! #require(r.positions.first { $0.fund == "RES" })
        let oper = try! #require(r.positions.first { $0.fund == "OPER" })

        #expect(res.gap == -35_000)
        #expect(res.isShort)
        #expect(res.fundedPercent == 72)

        #expect(oper.gap == 90_062.90)
        #expect(oper.isShort == false)
    }

    // MARK: Funds that exist but hold nothing

    @Test func aFundWithNoBalancesStillAppears() {
        // SPE has no rows at all in the live books. Dropping it would make the
        // fund list on this report disagree with the one on every other screen.
        let r = FundPositionReport.build(
            grids: [:],
            funds: [fund("SPE", "Special Levy Fund")],
            targets: [],
            upTo: 9
        )

        #expect(r.positions.count == 1)
        #expect(r.positions[0].closing == 0)
        #expect(r.positions[0].hasTarget == false)
    }

    // MARK: Continuity against the other side of the books

    @Test func movementReconcilesWithWhatWasBookedToFlowsAndEquity() {
        // The check the view runs: change in net assets == -(equity + revenue
        // + expense). Figures are the live OPER 2026 shape.
        let g = grid(
            activity: [
                (1000, "ASSET", 5, 118_761.50),
                (2000, "LIABILITY", 5, -26_387.90),
                (3000, "EQUITY", 1, 2_000),
                (3000, "EQUITY", 7, -110_000),
                (3010, "EQUITY", 5, -256_000),
                (4000, "REVENUE", 7, -11_541.50),
                (5000, "EXPENSE", 5, 283_167.90),
            ],
            accounts: [
                1000: "ASSET", 2000: "LIABILITY", 3000: "EQUITY",
                3010: "EQUITY", 4000: "REVENUE", 5000: "EXPENSE",
            ]
        )
        let r = FundPositionReport.build(
            grids: ["OPER": g], funds: [fund("OPER", "Operating")], targets: [], upTo: 9
        )

        let fromFlows = FundPositionReport.movementFromFlows(of: g, upTo: 9)
        #expect(abs(r.positions[0].movement - fromFlows) < 0.01)
        #expect(abs(r.positions[0].movement - 92_373.60) < 0.01)
    }

    @Test func unbalancedBooksMakeTheTwoSidesDisagree() {
        // An asset with no offsetting credit anywhere: the balance-sheet
        // movement is 1,000 and the flow side says nothing moved.
        let g = grid(activity: [(1000, "ASSET", 2, 1_000)], accounts: [1000: "ASSET"])
        let r = FundPositionReport.build(
            grids: ["OPER": g], funds: [fund("OPER", "Operating")], targets: [], upTo: 9
        )

        #expect(r.positions[0].movement == 1_000)
        #expect(FundPositionReport.movementFromFlows(of: g, upTo: 9) == 0)
    }

    // MARK: Decoding the sqlc row

    @Test func fundTargetDecodesThePgtypeShapeIncludingNulls() throws {
        // As `fund_targets_list` actually serialises it: target_balance is a
        // bare pgtype.Numeric decimal, notes/updated_by are string-or-null,
        // and as_of_date is a date-only string, not RFC3339.
        let json = """
        [
          {"id":"01a06b6c-ed27-7c6b-8fd4-42f3ab25a488","target_balance":50000.00,
           "notes":null,"updated_at":"2026-09-04T07:58:15.846894Z",
           "updated_by":"@mstoews","fund":"OPER","as_of_date":"2025-12-31"},
          {"id":"01a06b6d-735b-7d8e-a075-afe58608ef0c","target_balance":125000.00,
           "notes":"per 2025 reserve study","updated_at":"2026-09-04T07:58:50.203559Z",
           "updated_by":null,"fund":"RES","as_of_date":null}
        ]
        """
        let rows = try JSONDecoder().decode([FundTarget].self, from: Data(json.utf8))

        #expect(rows.count == 2)
        #expect(rows[0].fund == "OPER")
        #expect(rows[0].targetBalance == 50_000)
        #expect(rows[0].notes == nil)
        #expect(rows[0].asOfDate == "2025-12-31")
        #expect(rows[0].updatedBy == "@mstoews")

        #expect(rows[1].targetBalance == 125_000)
        #expect(rows[1].notes == "per 2025 reserve study")
        #expect(rows[1].asOfDate == nil)
        #expect(rows[1].updatedBy == nil)
    }

    @Test func fundTargetAcceptsNumericAsAString() throws {
        // pgx renders numerics unquoted today; the project convention is that
        // every numeric on this API may arrive as a string.
        let json = #"[{"id":"x","target_balance":"125000.00","fund":"RES"}]"#
        let rows = try JSONDecoder().decode([FundTarget].self, from: Data(json.utf8))

        #expect(rows[0].targetBalance == 125_000)
    }

    // MARK: R-A3 findings

    @Test func aMissingTargetBalanceThrowsRatherThanDecodingAsZero() {
        // A target of zero and no target are different values with different
        // meanings. Defaulting a decode miss to zero would report the fund's
        // whole balance as a surplus.
        let json = #"[{"id":"x","target_balance":null,"fund":"RES"}]"#
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode([FundTarget].self, from: Data(json.utf8))
        }
    }

    @Test func aFundDroppedFromTheReportIsNotTotalledAsZero() {
        // The view omits funds whose grid failed to load and names them
        // separately. Anything carried at zero here would understate the
        // corporation by whatever that fund holds.
        let g = grid(activity: [(1000, "ASSET", 1, 40_000)], accounts: [1000: "ASSET"])
        let r = FundPositionReport.build(
            grids: ["OPER": g],
            funds: [fund("OPER", "Operating")],   // RES deliberately absent
            targets: [FundTarget(id: "t", fund: "OPER", targetBalance: 50_000)],
            upTo: 9
        )

        #expect(r.positions.count == 1)
        #expect(r.totalClosing == 40_000)
        #expect(r.hasUntargetedFunds == false)
    }
}
