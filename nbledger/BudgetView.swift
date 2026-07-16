//
//  BudgetView.swift
//  nbledger
//
//  Budget screen — the mobile counterpart to noble-web's budget feature
//  (features/budget/*). A segmented control maps to the web's tabs:
//   • Overview  → BudgetLanding: KPI tiles + revenue/expense, cash-flow, and
//     expense-distribution charts.
//   • Analysis  → BudgetAnalysis: per-account YTD actual vs budget variance,
//     grouped by type.
//   • Forecast  → BudgetForecast: per-account year-end projection, tap through
//     to a 12-month actual-vs-budget breakdown.
//
//  All figures come from BudgetReport (BudgetService.swift); this file is
//  presentation only. Read-only for now — the maintenance editor (set_budget_amts)
//  is a later phase.
//

import SwiftUI
import Charts

// MARK: - Root

struct BudgetView: View {
    @Environment(APIService.self) private var apiService

    @State private var report: BudgetReport?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var tab: BudgetTab = .overview

    enum BudgetTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case analysis = "Analysis"
        case forecast = "Forecast"
        var id: String { rawValue }
    }

    var body: some View {
        Group {
            if isLoading && report == nil {
                ProgressView("Loading budget…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, report == nil {
                errorState(errorMessage)
            } else if let report {
                content(report)
            } else {
                emptyState
            }
        }
        .navigationTitle("Budget")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    BudgetEditorView()
                } label: {
                    Label("Edit Budget", systemImage: "slider.horizontal.3")
                }
            }
        }
        .task { if report == nil { await load() } }
        .refreshable { await load() }
    }

    private func content(_ report: BudgetReport) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("View", selection: $tab) {
                    ForEach(BudgetTab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                Text("All funds · FY \(String(report.year)) · YTD through \(report.throughMonthLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if report.revenueLines.isEmpty && report.expenseLines.isEmpty {
                    noDataNote
                } else {
                    switch tab {
                    case .overview: BudgetOverview(report: report)
                    case .analysis: BudgetAnalysisList(report: report)
                    case .forecast: BudgetForecastList(report: report)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var noDataNote: some View {
        NobleCard(padding: 20) {
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("No budget data for FY \(report.map { String($0.year) } ?? "")")
                    .font(.headline)
                Text("Budgets are set per fund in the web app. Once entered, they'll roll up here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No budget data.").font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Retry") { Task { await load() } }
                .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            report = try await apiService.fetchBudgetReport()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Overview

private struct BudgetOverview: View {
    let report: BudgetReport

    var body: some View {
        VStack(spacing: 16) {
            kpiGrid
            revenueExpenseChart
            cashFlowChart
            if !report.expenseCategories.isEmpty { expensePieChart }
        }
    }

    private var kpiGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                BudgetKPITile(
                    label: "Revenue YTD",
                    value: report.totalRevenueYTD,
                    variancePct: report.totalRevenueBudgetYTD == 0 ? nil
                        : pct(report.totalRevenueYTD, report.totalRevenueBudgetYTD),
                    favorable: report.totalRevenueYTD >= report.totalRevenueBudgetYTD
                )
                BudgetKPITile(
                    label: "Expenses YTD",
                    value: report.totalExpenseYTD,
                    variancePct: report.totalExpenseBudgetYTD == 0 ? nil
                        : pct(report.totalExpenseYTD, report.totalExpenseBudgetYTD),
                    favorable: report.totalExpenseYTD <= report.totalExpenseBudgetYTD
                )
            }
            HStack(spacing: 12) {
                BudgetKPITile(
                    label: "Net Cash Flow YTD",
                    value: report.netCashFlowYTD,
                    variancePct: report.netCashFlowBudgetYTD == 0 ? nil
                        : pct(report.netCashFlowYTD, report.netCashFlowBudgetYTD),
                    favorable: report.netCashFlowYTD >= report.netCashFlowBudgetYTD
                )
                BudgetKPITile(
                    label: "Year-End Projection",
                    value: report.projectedNet,
                    variancePct: report.fullYearBudgetNet == 0 ? nil
                        : pct(report.projectedNet, report.fullYearBudgetNet),
                    favorable: report.projectedNet >= report.fullYearBudgetNet
                )
            }
        }
    }

    private var revenueExpenseChart: some View {
        ChartCard(title: "Revenue vs Expenses") {
            Chart {
                ForEach(report.revenueMonthly) { p in
                    BarMark(x: .value("Month", p.label), y: .value("Amount", p.actual))
                        .foregroundStyle(by: .value("Series", "Revenue"))
                        .position(by: .value("Series", "Revenue"))
                }
                ForEach(report.expenseMonthly) { p in
                    BarMark(x: .value("Month", p.label), y: .value("Amount", p.actual))
                        .foregroundStyle(by: .value("Series", "Expenses"))
                        .position(by: .value("Series", "Expenses"))
                }
            }
            .chartForegroundStyleScale(["Revenue": Color.nobleEmerald, "Expenses": Color.nobleBlue])
            .chartXScale(domain: BudgetReport.monthLabels)
            .chartXAxis { monthAxis }
            .chartYAxis { moneyAxis }
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 200)
        }
    }

    private var cashFlowChart: some View {
        ChartCard(title: "Cash Flow — Actual vs Budget", legend: {
            HStack(spacing: 14) {
                LegendSwatch(color: .nobleEmerald, label: "Actual")
                LegendSwatch(color: .nobleSlate, label: "Budget", dashed: true)
            }
        }) {
            Chart {
                ForEach(report.cashFlowMonthly) { p in
                    AreaMark(x: .value("Month", p.label), y: .value("Cash Flow", p.actual))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.nobleEmerald.opacity(0.32), .nobleEmerald.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                }
                ForEach(report.cashFlowMonthly) { p in
                    LineMark(x: .value("Month", p.label),
                             y: .value("Actual", p.actual),
                             series: .value("Series", "Actual"))
                        .foregroundStyle(Color.nobleEmerald)
                        .interpolationMethod(.catmullRom)
                }
                ForEach(report.cashFlowMonthly) { p in
                    LineMark(x: .value("Month", p.label),
                             y: .value("Budget", p.budget),
                             series: .value("Series", "Budget"))
                        .foregroundStyle(Color.nobleSlate)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .interpolationMethod(.catmullRom)
                }
            }
            .chartXScale(domain: BudgetReport.monthLabels)
            .chartXAxis { monthAxis }
            .chartYAxis { moneyAxis }
            .frame(height: 200)
        }
    }

    private var expensePieChart: some View {
        ChartCard(title: "Expense Distribution (YTD)") {
            Chart(report.expenseCategories) { cat in
                SectorMark(
                    angle: .value("Amount", cat.actual),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .cornerRadius(3)
                .foregroundStyle(by: .value("Category", cat.name))
            }
            .chartForegroundStyleScale(range: budgetPalette)
            .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
            .frame(height: 240)
        }
    }

    private func pct(_ actual: Double, _ budget: Double) -> Double {
        budget == 0 ? 0 : (actual - budget) / abs(budget) * 100
    }
}

// MARK: - Analysis

private struct BudgetAnalysisList: View {
    let report: BudgetReport

    var body: some View {
        VStack(spacing: 16) {
            groupCard(
                title: "Revenue",
                actual: report.totalRevenueYTD,
                budget: report.totalRevenueBudgetYTD,
                favorable: report.totalRevenueYTD >= report.totalRevenueBudgetYTD,
                lines: report.revenueLines
            )
            groupCard(
                title: "Expenses",
                actual: report.totalExpenseYTD,
                budget: report.totalExpenseBudgetYTD,
                favorable: report.totalExpenseYTD <= report.totalExpenseBudgetYTD,
                lines: report.expenseLines
            )
        }
    }

    private func groupCard(title: String, actual: Double, budget: Double,
                           favorable: Bool, lines: [BudgetLine]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(title)
                Spacer()
                Text("\(Text.money(actual)) / \(Text.money(budget))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(favorable ? Color.nobleEmerald : Color.nobleWarn)
            }
            NobleCard {
                VStack(spacing: 0) {
                    ForEach(lines) { line in
                        BudgetMetricRow(
                            title: line.description,
                            subtitle: "#\(line.child)",
                            value: line.ytdActual,
                            compareLabel: "of \(money(line.ytdBudget)) YTD",
                            variancePct: line.ytdBudget == 0 ? nil : line.ytdVariancePct,
                            favorable: line.ytdFavorable
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        if line.id != lines.last?.id { Divider().padding(.leading, 14) }
                    }
                    if lines.isEmpty {
                        Text("No \(title.lowercased()) accounts.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
            }
        }
    }
}

// MARK: - Forecast

private struct BudgetForecastList: View {
    let report: BudgetReport

    var body: some View {
        VStack(spacing: 16) {
            groupCard(title: "Revenue", lines: report.revenueLines)
            groupCard(title: "Expenses", lines: report.expenseLines)
        }
    }

    private func groupCard(title: String, lines: [BudgetLine]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("\(title) · Year-End Projection")
            NobleCard {
                VStack(spacing: 0) {
                    ForEach(lines) { line in
                        NavigationLink {
                            BudgetLineDetailView(line: line, monthsElapsed: report.monthsElapsed)
                        } label: {
                            BudgetMetricRow(
                                title: line.description,
                                subtitle: "#\(line.child)",
                                value: line.yearEndProjection,
                                compareLabel: "of \(money(line.fullYearBudget)) plan",
                                variancePct: line.fullYearBudget == 0 ? nil
                                    : line.yearEndVariance / abs(line.fullYearBudget) * 100,
                                favorable: line.yearEndFavorable,
                                showChevron: true
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        if line.id != lines.last?.id { Divider().padding(.leading, 14) }
                    }
                    if lines.isEmpty {
                        Text("No \(title.lowercased()) accounts.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
            }
        }
    }
}

// MARK: - Line detail (12-month breakdown)

struct BudgetLineDetailView: View {
    let line: BudgetLine
    let monthsElapsed: Int

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ChartCard(title: "Monthly Actual vs Budget", legend: {
                    HStack(spacing: 14) {
                        LegendSwatch(color: .nobleEmerald, label: "Actual")
                        LegendSwatch(color: .nobleSlate, label: "Budget")
                    }
                }) {
                    Chart {
                        ForEach(line.monthly) { p in
                            BarMark(x: .value("Month", p.label), y: .value("Actual", p.actual))
                                .foregroundStyle(by: .value("Series", "Actual"))
                                .position(by: .value("Series", "Actual"))
                        }
                        ForEach(line.monthly) { p in
                            BarMark(x: .value("Month", p.label), y: .value("Budget", p.budget))
                                .foregroundStyle(by: .value("Series", "Budget"))
                                .position(by: .value("Series", "Budget"))
                        }
                    }
                    .chartForegroundStyleScale(["Actual": Color.nobleEmerald, "Budget": Color.nobleSlate])
                    .chartXScale(domain: BudgetReport.monthLabels)
                    .chartXAxis { monthAxis }
                    .chartYAxis { moneyAxis }
                    .chartLegend(.hidden)
                    .frame(height: 220)
                }

                NobleCard {
                    VStack(spacing: 0) {
                        ForEach(line.monthly) { p in
                            let elapsed = p.month <= monthsElapsed
                            HStack {
                                Text(p.label)
                                    .font(.subheadline.weight(.medium))
                                    .frame(width: 42, alignment: .leading)
                                if !elapsed {
                                    Text("proj")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Color.nobleAmberText)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.nobleAmberSoft, in: Capsule())
                                }
                                Spacer()
                                Text.money(elapsed ? p.actual : p.budget)
                                    .font(.subheadline)
                                Text("/ \(money(p.budget))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 78, alignment: .trailing)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            if p.month != 12 { Divider().padding(.leading, 14) }
                        }
                    }
                }

                NobleCard(padding: 14) {
                    VStack(spacing: 8) {
                        DetailRow(label: "YTD Actual", value: money(line.ytdActual))
                        Divider()
                        DetailRow(label: "YTD Budget", value: money(line.ytdBudget))
                        Divider()
                        DetailRow(label: "Full-Year Plan", value: money(line.fullYearBudget))
                        Divider()
                        DetailRow(label: "Year-End Projection", value: money(line.yearEndProjection))
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(line.description)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Shared pieces

private struct BudgetKPITile: View {
    let label: String
    let value: Double
    var variancePct: Double? = nil
    var favorable: Bool? = nil

    var body: some View {
        NobleCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text.money(value)
                    .font(.title3.weight(.bold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if let favorable {
                    VarianceChip(pct: variancePct, favorable: favorable)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct BudgetMetricRow: View {
    let title: String
    let subtitle: String
    let value: Double
    let compareLabel: String
    let variancePct: Double?
    let favorable: Bool
    var showChevron = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text.money(value)
                    .font(.subheadline.weight(.semibold))
                Text(compareLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                VarianceChip(pct: variancePct, favorable: favorable)
            }
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct VarianceChip: View {
    /// nil = no budget baseline to compare against (renders a neutral chip
    /// rather than a misleading 0.0%).
    let pct: Double?
    let favorable: Bool

    var body: some View {
        if let pct {
            let up = pct >= 0
            HStack(spacing: 3) {
                Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2.weight(.bold))
                Text("\(abs(pct), format: .number.precision(.fractionLength(1)))%")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(favorable ? Color.nobleEmerald : Color.nobleWarn)
        } else {
            Text("no budget")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ChartCard<Content: View, Legend: View>: View {
    let title: String
    @ViewBuilder var legend: Legend
    @ViewBuilder var content: Content

    init(title: String,
         @ViewBuilder legend: () -> Legend = { EmptyView() },
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.legend = legend()
        self.content = content()
    }

    var body: some View {
        NobleCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel(title)
                    Spacer()
                    legend
                }
                content
            }
        }
    }
}

private struct LegendSwatch: View {
    let color: Color
    let label: String
    var dashed: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1)
                .fill(dashed ? AnyShapeStyle(color.opacity(0.5)) : AnyShapeStyle(color))
                .frame(width: 14, height: dashed ? 2 : 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Chart axis + formatting helpers

/// Quarterly month ticks keep the 12-point x-axis readable on a phone.
@AxisContentBuilder
private var monthAxis: some AxisContent {
    AxisMarks(values: ["Jan", "Apr", "Jul", "Oct"]) { value in
        AxisGridLine()
        AxisTick()
        AxisValueLabel {
            if let s = value.as(String.self) { Text(s).font(.caption2) }
        }
    }
}

@AxisContentBuilder
private var moneyAxis: some AxisContent {
    AxisMarks(position: .leading) { value in
        AxisGridLine()
        AxisValueLabel {
            if let d = value.as(Double.self) {
                Text(compactMoney(d)).font(.caption2)
            }
        }
    }
}

/// Compact currency for chart axes/labels ($1.2k / $3M).
private func compactMoney(_ v: Double) -> String {
    let sign = v < 0 ? "-" : ""
    let a = abs(v)
    if a >= 1_000_000 {
        return "\(sign)$\((a / 1_000_000).formatted(.number.precision(.fractionLength(0...1))))M"
    }
    if a >= 1_000 {
        return "\(sign)$\((a / 1_000).formatted(.number.precision(.fractionLength(0...1))))k"
    }
    return "\(sign)$\(a.formatted(.number.precision(.fractionLength(0))))"
}

/// Full currency string for inline labels (non-Text contexts).
private func money(_ v: Double) -> String {
    v.formatted(.currency(code: "USD"))
}

/// Donut category palette drawn from the brand tokens.
private let budgetPalette: [Color] = [
    .nobleEmerald, .nobleBlue, .noblePurple, .nobleAmber,
    .nobleEmeraldOnDark, .nobleWarn, .nobleSlate, .nobleEmeraldHighlight, .teal,
]
