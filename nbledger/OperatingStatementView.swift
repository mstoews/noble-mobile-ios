//
//  OperatingStatementView.swift
//  nbledger
//
//  Operating statement — actual against budget, for a period and year-to-date.
//
//  R-A1 of .claude/plans/financial-reporting. The question a board asks every
//  month is "are we on budget?", and nothing in the app answered it: the
//  Dashboard shows balances, Payables shows what is owed, and neither explains
//  the position.
//
//  Everything comes from one call — `comparison_trial_balance_by_fund` returns
//  actual, budget, opening and closing per account per period, so the month is
//  one row and year-to-date is a sum over periods 1...n.
//

import SwiftUI

// MARK: - Model

/// Which column set is on screen. A phone cannot show month and YTD side by
/// side without shrinking the numbers past reading — so it shows one at a time.
enum StatementSpan: String, CaseIterable {
    case month = "Month"
    case yearToDate = "YTD"
}

/// One account line of the statement, already in display sign.
///
/// The wire is in BOOK sign (debits positive), so revenue arrives negative.
/// A financial statement shows revenue positive, and a reader who sees
/// "Revenue −11,541" reasonably concludes income was negative. Flipping once,
/// here, keeps every downstream sum and comparison in one convention.
struct OperatingStatementRow: Identifiable {
    let account: Int
    let child: Int
    let description: String
    let acctType: String
    let actual: Double
    let budget: Double

    var id: Int { child }

    var isRevenue: Bool { acctType.uppercased() == "REVENUE" }

    /// Positive means better than budget, for both halves of the statement —
    /// which is not the same arithmetic on each side. Under-spending an expense
    /// is favourable; under-earning revenue is not.
    var variance: Double {
        isRevenue ? actual - budget : budget - actual
    }

    /// Nil when there is no budget to compare against. A budget of zero
    /// against real spend is not "100% over" — it means nobody set one, and
    /// saying otherwise invents a number the board might act on.
    var variancePercent: Double? {
        guard budget != 0 else { return nil }
        return variance / abs(budget) * 100
    }

    var isAdverse: Bool { variance < 0 }
    var hasBudget: Bool { budget != 0 }
}

/// The statement for one fund, one period.
struct OperatingStatement {
    let rows: [OperatingStatementRow]

    var revenue: [OperatingStatementRow] { rows.filter(\.isRevenue) }
    var expenses: [OperatingStatementRow] { rows.filter { !$0.isRevenue } }

    var revenueActual: Double { revenue.map(\.actual).reduce(0, +) }
    var revenueBudget: Double { revenue.map(\.budget).reduce(0, +) }
    var expenseActual: Double { expenses.map(\.actual).reduce(0, +) }
    var expenseBudget: Double { expenses.map(\.budget).reduce(0, +) }

    var netActual: Double { revenueActual - expenseActual }
    var netBudget: Double { revenueBudget - expenseBudget }
    var netVariance: Double { netActual - netBudget }

    /// No budget anywhere on the statement. Distinct from a budget of zero:
    /// this is "nobody set one", and the view says so rather than rendering
    /// every line as fully over budget.
    var hasNoBudget: Bool { rows.allSatisfy { !$0.hasBudget } }

    /// Builds the statement from the raw grid.
    ///
    /// Only revenue and expense accounts belong here — an operating statement
    /// is a flow report, and including the balance sheet would double-count
    /// the same money. That filter is load-bearing in this data: the budget
    /// currently loaded in some tenants sits entirely on balance-sheet
    /// accounts, and summing everything would show a healthy budget that has
    /// nothing to do with operations.
    static func build(from grid: [ComparisonTrialBalanceRow], upTo period: Int, span: StatementSpan) -> OperatingStatement {
        let periods: ClosedRange<Int> = span == .month ? period...period : 1...max(period, 1)
        var byAccount: [Int: OperatingStatementRow] = [:]

        for cell in grid where periods.contains(cell.period) {
            let type = cell.acctType.uppercased()
            guard type == "REVENUE" || type == "EXPENSE" else { continue }

            // Book sign -> display sign, once.
            let sign: Double = type == "REVENUE" ? -1 : 1
            let existing = byAccount[cell.child]
            byAccount[cell.child] = OperatingStatementRow(
                account: cell.account,
                child: cell.child,
                description: cell.description,
                acctType: type,
                actual: (existing?.actual ?? 0) + cell.actual * sign,
                budget: (existing?.budget ?? 0) + cell.budget * sign
            )
        }

        // Anything with neither activity nor budget is noise on a phone: the
        // grid is dense, so most accounts have twelve empty rows.
        let rows = byAccount.values
            .filter { $0.actual != 0 || $0.budget != 0 }
            // Worst variance first — this is read to find what went wrong.
            .sorted { $0.variance < $1.variance }

        return OperatingStatement(rows: Array(rows))
    }
}

// MARK: - View

struct OperatingStatementView: View {
    @Environment(APIService.self) private var apiService

    @State private var grid: [ComparisonTrialBalanceRow] = []
    @State private var funds: [FundRef] = []
    @State private var selectedFund: String?
    @State private var period: CurrentPeriod?
    @State private var span: StatementSpan = .month
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var statement: OperatingStatement {
        OperatingStatement.build(from: grid, upTo: period?.periodId ?? 1, span: span)
    }

    private var currency: String { "USD" }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Span", selection: $span) {
                ForEach(StatementSpan.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            content
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Operating Statement")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if funds.count > 1 {
                    Menu {
                        Picker("Fund", selection: $selectedFund) {
                            ForEach(funds) { fund in
                                Text(fund.displayName).tag(Optional(fund.fund))
                            }
                        }
                    } label: {
                        Label(selectedFund ?? "Fund", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .onChange(of: selectedFund) { Task { await loadGrid() } }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && grid.isEmpty {
            ProgressView("Loading statement...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage, grid.isEmpty {
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
        } else if statement.rows.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text(span == .month ? "No activity in this period." : "No activity this year.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                summarySection
                if statement.hasNoBudget { noBudgetSection }
                accountSection("Revenue", statement.revenue)
                accountSection("Expenses", statement.expenses)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: Summary

    private var summarySection: some View {
        Section {
            summaryLine("Revenue", statement.revenueActual, statement.revenueBudget)
            summaryLine("Expenses", statement.expenseActual, statement.expenseBudget)
            HStack {
                Text("Net")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(statement.netActual, format: .currency(code: currency))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(statement.netActual < 0 ? Color.nobleWarn : .primary)
                    if !statement.hasNoBudget {
                        Text("budget \(statement.netBudget, format: .currency(code: currency))")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text(headerTitle)
        }
    }

    private func summaryLine(_ label: String, _ actual: Double, _ budget: Double) -> some View {
        HStack {
            Text(label)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(actual, format: .currency(code: currency))
                    .monospacedDigit()
                if budget != 0 {
                    Text("of \(budget, format: .currency(code: currency))")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var headerTitle: String {
        let fund = funds.first { $0.fund == selectedFund }?.description ?? selectedFund ?? ""
        guard let period else { return fund }
        let scope = span == .month ? "Period \(period.periodId)" : "Periods 1–\(period.periodId)"
        return "\(fund) · \(scope) \(period.periodYear)"
    }

    /// The case that matters most in practice right now: budget rows can exist
    /// while no operating budget does.
    private var noBudgetSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text("No budget set for this fund")
                        .font(.subheadline.weight(.semibold))
                    Text("Actuals are shown without comparison. Enter a budget under More → Budget to see variance here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.nobleAmber)
            }
        }
    }

    // MARK: Accounts

    @ViewBuilder
    private func accountSection(_ title: String, _ rows: [OperatingStatementRow]) -> some View {
        if !rows.isEmpty {
            Section(title) {
                ForEach(rows) { row in
                    OperatingStatementLine(row: row, currency: currency)
                }
            }
        }
    }

    // MARK: Data

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        period = try? await apiService.fetchCurrentActivePeriod()
        // Funds come from the server, never a literal: the codes here are
        // OPER / RES / CAP / SPE, not the values the fund_code enum suggests.
        funds = (try? await apiService.fetchFunds()) ?? []
        if selectedFund == nil {
            selectedFund = funds.first { $0.fund.uppercased().hasPrefix("OPER") }?.fund
                ?? funds.first?.fund
        }
        await loadGrid()
    }

    private func loadGrid() async {
        guard let fund = selectedFund, let year = period?.periodYear else { return }
        do {
            grid = try await apiService.fetchComparisonTrialBalance(fund: fund, year: year)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Line

struct OperatingStatementLine: View {
    let row: OperatingStatementRow
    let currency: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.description.isEmpty ? "Account \(row.child)" : row.description)
                    .font(.subheadline)
                    .lineLimit(1)
                Text("\(row.account) / \(row.child)")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(row.actual, format: .currency(code: currency))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()

                if row.hasBudget {
                    HStack(spacing: 4) {
                        Text(row.variance, format: .currency(code: currency))
                            .monospacedDigit()
                        if let pct = row.variancePercent {
                            Text("(\(pct, specifier: "%.0f")%)")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(row.isAdverse ? Color.nobleWarn : Color.nobleEmerald)
                } else {
                    Text("no budget")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
