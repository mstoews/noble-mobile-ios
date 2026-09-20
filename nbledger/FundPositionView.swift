//
//  FundPositionView.swift
//  nbledger
//
//  Fund position against board target — opening, movement, closing, gap.
//
//  R-A2 of .claude/plans/financial-reporting. For a condominium corporation
//  this is the report with statutory weight: owners and auditors ask whether
//  the reserve fund holds what the board resolved it should hold. R-A1 answers
//  "are we on budget?"; this answers "is the money there?".
//
//  Position is net assets, not a fund-balance account. `comparison_trial_
//  balance_by_fund` already carries `opening` and a running `closing` per leaf
//  account, so summing the asset and liability rows for one period gives the
//  fund's position at that period directly. That is deliberately NOT read off
//  the 3000 equity accounts: in the live data those carry mid-year transfers
//  posted in periods 1, 5, 7 and 8, so treating them as an opening balance
//  would be wrong by the value of every transfer.
//

import SwiftUI

// MARK: - Model

/// One fund's position for a year, with the board target if one exists.
///
/// Amounts are net assets in book sign, where liabilities are already negative,
/// so `assets + liabilities` is the position with no sign gymnastics.
struct FundPosition: Identifiable {
    let fund: String
    let name: String
    /// Position carried in from the prior year — the OPENING rows. Zero when
    /// the tenant has no prior year loaded, which is not the same as a fund
    /// that opened at zero, but is indistinguishable from the data.
    let opening: Double
    /// Position at the selected period, opening plus everything booked since.
    let closing: Double
    /// Nil when no board target exists for this fund. Distinct from a target
    /// of zero: absence means nobody set one, and reporting the whole balance
    /// as the gap would be an invented number.
    let target: Double?
    /// When the target was last set or reviewed. A target carried from an old
    /// board minute is worth seeing next to a current position.
    let targetAsOf: String?

    var id: String { fund }

    var movement: Double { closing - opening }

    /// Positive is a surplus over target, negative a shortfall. Nil with no
    /// target.
    var gap: Double? {
        guard let target else { return nil }
        return closing - target
    }

    /// Share of target held. Nil with no target, and nil at a target of zero —
    /// "infinitely funded" is not a thing to put in front of a board.
    var fundedPercent: Double? {
        guard let target, target != 0 else { return nil }
        return closing / target * 100
    }

    var hasTarget: Bool { target != nil }
    var isShort: Bool { (gap ?? 0) < 0 }
}

/// Every fund's position for one period, plus the totals a board reads first.
struct FundPositionReport {
    let positions: [FundPosition]

    /// Total position across every fund, targeted or not. This is the whole
    /// corporation's net assets and is always meaningful.
    var totalClosing: Double { positions.map(\.closing).reduce(0, +) }

    var targeted: [FundPosition] { positions.filter(\.hasTarget) }
    var untargeted: [FundPosition] { positions.filter { !$0.hasTarget } }

    /// Totals over the targeted funds only. Summing a target across funds that
    /// have none would understate the target and turn a shortfall into a
    /// surplus — the same error as treating a missing target as zero, one
    /// level up.
    var totalTarget: Double? {
        guard !targeted.isEmpty else { return nil }
        return targeted.compactMap(\.target).reduce(0, +)
    }

    var totalTargetedClosing: Double { targeted.map(\.closing).reduce(0, +) }

    var totalGap: Double? {
        guard let totalTarget else { return nil }
        return totalTargetedClosing - totalTarget
    }

    /// True when some funds sit outside the totalled target, so the header can
    /// say the total is partial rather than quietly implying it is complete.
    var hasUntargetedFunds: Bool { !untargeted.isEmpty }

    /// Builds the report from one trial-balance grid per fund.
    ///
    /// - Parameters:
    ///   - grids: fund code to that fund's comparison trial balance.
    ///   - funds: `funds_list`, which defines both the set of funds and their
    ///     display names. Funds absent from `grids` still appear, at zero — a
    ///     fund that exists holding nothing is a finding, not a row to drop.
    ///   - targets: `fund_targets_list`, keyed by fund. Absent means no target.
    ///   - period: the period whose closing position to report.
    static func build(
        grids: [String: [ComparisonTrialBalanceRow]],
        funds: [FundRef],
        targets: [FundTarget],
        upTo period: Int
    ) -> FundPositionReport {
        let targetsByFund = Dictionary(
            targets.map { ($0.fund.uppercased(), $0) },
            // Two targets for one fund should not happen; if it does, the most
            // recently reviewed one is the one the board is working from.
            uniquingKeysWith: { a, b in (a.asOfDate ?? "") >= (b.asOfDate ?? "") ? a : b }
        )

        let positions = funds.map { fund -> FundPosition in
            let grid = grids[fund.fund] ?? []
            let target = targetsByFund[fund.fund.uppercased()]
            return FundPosition(
                fund: fund.fund,
                name: fund.description ?? fund.fund,
                opening: openingPosition(of: grid),
                closing: closingPosition(of: grid, at: period),
                target: target?.targetBalance,
                targetAsOf: target?.asOfDate
            )
        }

        return FundPositionReport(positions: positions)
    }

    /// Only the balance sheet makes up a position. Revenue and expense are the
    /// flows that moved it and are already folded into `closing`; adding them
    /// would count the same money twice.
    private static func isPositionAccount(_ acctType: String) -> Bool {
        let t = acctType.uppercased()
        return t == "ASSET" || t == "LIABILITY"
    }

    /// `opening` is carried onto all twelve period rows of each account, so it
    /// is summed over a single period to avoid multiplying it by twelve.
    private static func openingPosition(of grid: [ComparisonTrialBalanceRow]) -> Double {
        grid.filter { $0.period == 1 && isPositionAccount($0.acctType) }
            .map(\.opening)
            .reduce(0, +)
    }

    private static func closingPosition(of grid: [ComparisonTrialBalanceRow], at period: Int) -> Double {
        grid.filter { $0.period == period && isPositionAccount($0.acctType) }
            .map(\.closing)
            .reduce(0, +)
    }

    /// Independent check on `movement`, from the other side of the books:
    /// the change in net assets equals the negated sum of everything booked to
    /// equity, revenue and expense. Assets and liabilities never appear, so a
    /// mismatch means the fund's journals do not balance within the fund.
    ///
    /// Used by the tests, and by the view to warn rather than present a figure
    /// it cannot stand behind.
    static func movementFromFlows(of grid: [ComparisonTrialBalanceRow], upTo period: Int) -> Double {
        -grid.filter { $0.period <= period && !isPositionAccount($0.acctType) }
            .map(\.actual)
            .reduce(0, +)
    }
}

// MARK: - View

struct FundPositionView: View {
    @Environment(APIService.self) private var apiService

    @State private var report: FundPositionReport?
    @State private var funds: [FundRef] = []
    @State private var period: CurrentPeriod?
    @State private var unbalancedFunds: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var currency: String { "USD" }

    var body: some View {
        content
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Fund Position")
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
            .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && report == nil {
            ProgressView("Loading positions...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage, report == nil {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text(errorMessage)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Retry") { Task { await load() } }
                    .buttonStyle(.bordered)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let report, !report.positions.isEmpty {
            List {
                totalsSection(report)
                if !unbalancedFunds.isEmpty { unbalancedSection }
                if !report.targeted.isEmpty {
                    Section("Against target") {
                        ForEach(report.targeted) { FundPositionRow(position: $0, currency: currency) }
                    }
                }
                if report.hasUntargetedFunds {
                    Section {
                        ForEach(report.untargeted) { FundPositionRow(position: $0, currency: currency) }
                    } header: {
                        Text("No target set")
                    } footer: {
                        // Precise about which total: these balances ARE in
                        // total position, and are only left out of the target
                        // and the gap.
                        Text("Their balances are in the total position above, but not in the target or the gap. A target is set on the web under Funds, from the board resolution or reserve study it comes from.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "building.columns")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("No funds are set up.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Totals

    private func totalsSection(_ report: FundPositionReport) -> some View {
        Section {
            HStack {
                Text("Total position")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(report.totalClosing, format: .currency(code: currency))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(report.totalClosing < 0 ? Color.nobleWarn : .primary)
            }

            if let totalTarget = report.totalTarget, let totalGap = report.totalGap {
                HStack {
                    Text("Target")
                    Spacer()
                    Text(totalTarget, format: .currency(code: currency))
                        .monospacedDigit()
                }
                HStack {
                    Text(totalGap < 0 ? "Shortfall" : "Surplus")
                    Spacer()
                    Text(abs(totalGap), format: .currency(code: currency))
                        .monospacedDigit()
                        .foregroundStyle(totalGap < 0 ? Color.nobleWarn : Color.nobleEmerald)
                }
            }
        } header: {
            Text(headerTitle)
        } footer: {
            if report.hasUntargetedFunds, report.totalTarget != nil {
                Text("Target and \(report.totalGap.map { $0 < 0 ? "shortfall" : "surplus" } ?? "gap") cover the \(report.targeted.count) targeted \(report.targeted.count == 1 ? "fund" : "funds") only.")
            }
        }
    }

    private var headerTitle: String {
        guard let period else { return "Position" }
        return "As at period \(period.periodId) \(period.periodYear)"
    }

    /// A fund whose journals do not balance within the fund. Shown because the
    /// alternative is presenting a position that the other side of the books
    /// contradicts, with nothing on screen to say so.
    private var unbalancedSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Fund does not balance")
                        .font(.subheadline.weight(.semibold))
                    Text("\(unbalancedFunds.joined(separator: ", ")): the change in net assets does not match what was booked to revenue, expense and fund balance. The position shown is the balance-sheet figure.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(Color.nobleWarn)
            }
        }
    }

    // MARK: Data

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        period = try? await apiService.fetchCurrentActivePeriod()
        guard let year = period?.periodYear, let upTo = period?.periodId else {
            errorMessage = "No active period is open."
            return
        }

        // Funds and their codes come from the server; nothing here is keyed off
        // a literal fund code.
        funds = (try? await apiService.fetchFunds()) ?? []
        let targets = (try? await apiService.fetchFundTargets()) ?? []

        // One grid per fund. Sequential rather than concurrent: this file
        // follows the project rule against `async let` fan-out with mixed error
        // handling, and four funds is not worth the risk.
        var grids: [String: [ComparisonTrialBalanceRow]] = [:]
        var unbalanced: [String] = []
        for fund in funds {
            guard let grid = try? await apiService.fetchComparisonTrialBalance(fund: fund.fund, year: year) else { continue }
            grids[fund.fund] = grid

            let fromBalanceSheet = FundPositionReport.build(
                grids: [fund.fund: grid], funds: [fund], targets: [], upTo: upTo
            ).positions.first?.movement ?? 0
            let fromFlows = FundPositionReport.movementFromFlows(of: grid, upTo: upTo)
            // A cent of tolerance: these are two float sums over the same
            // decimals, not an equality of exact values.
            if abs(fromBalanceSheet - fromFlows) > 0.01 { unbalanced.append(fund.fund) }
        }

        if grids.isEmpty && !funds.isEmpty {
            errorMessage = "Could not load fund balances."
            return
        }

        unbalancedFunds = unbalanced
        report = FundPositionReport.build(grids: grids, funds: funds, targets: targets, upTo: upTo)
    }
}

// MARK: - Row

struct FundPositionRow: View {
    let position: FundPosition
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(position.name)
                        .font(.subheadline.weight(.medium))
                    Text(position.fund)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(position.closing, format: .currency(code: currency))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(position.closing < 0 ? Color.nobleWarn : .primary)

                    if let gap = position.gap {
                        HStack(spacing: 4) {
                            Text(gap < 0 ? "short" : "over")
                            Text(abs(gap), format: .currency(code: currency))
                                .monospacedDigit()
                            if let pct = position.fundedPercent {
                                Text("(\(pct, specifier: "%.0f")%)")
                                    .monospacedDigit()
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(position.isShort ? Color.nobleWarn : Color.nobleEmerald)
                    } else {
                        Text("no target")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            continuity

            if let target = position.target {
                HStack(spacing: 4) {
                    Text("Target")
                    Text(target, format: .currency(code: currency))
                        .monospacedDigit()
                    if let asOf = position.targetAsOf {
                        Text("· as at \(asOf)")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    /// Opening → movement → closing on one line. It is the arithmetic an
    /// auditor checks first, and showing it means the closing figure is never
    /// a number the reader has to take on faith.
    private var continuity: some View {
        HStack(spacing: 4) {
            Text(position.opening, format: .currency(code: currency))
                .monospacedDigit()
            Image(systemName: "plus")
                .font(.system(size: 7, weight: .semibold))
            Text(position.movement, format: .currency(code: currency))
                .monospacedDigit()
                .foregroundStyle(position.movement < 0 ? Color.nobleWarn : Color.nobleEmerald)
            Image(systemName: "equal")
                .font(.system(size: 7, weight: .semibold))
            Text(position.closing, format: .currency(code: currency))
                .monospacedDigit()
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}
