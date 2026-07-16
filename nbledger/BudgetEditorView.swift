//
//  BudgetEditorView.swift
//  nbledger
//
//  Budget Maintenance editor — the write counterpart to the read-only Budget
//  screens, mirroring noble-web's BudgetUpdate tab. Pick a fund, edit each
//  account's 12 monthly budgets (in display space), optionally bulk-Generate
//  from prior-year actuals or Spread an annual across the year, then Save —
//  which writes each changed row via `/set_budget_amts`.
//

import SwiftUI

struct BudgetEditorView: View {
    @Environment(APIService.self) private var apiService

    @State private var funds: [FundRef] = []
    @State private var selectedFund = ""
    @State private var rows: [EditableBudgetRow] = []
    /// child → 12 prior-year actuals in display space, for Generate.
    @State private var priorActualByChild: [Int: [Double]] = [:]

    @State private var growthPct = 0.0
    @State private var weight = 1.0
    @State private var spreadMode: SpreadMode = .seasonal

    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var banner: String?
    @State private var pendingFund: String?

    private var dirtyCount: Int { rows.filter(\.isDirty).count }
    private var revenueIndices: [Int] { rows.indices.filter { rows[$0].isRevenue } }
    private var expenseIndices: [Int] { rows.indices.filter { !rows[$0].isRevenue } }

    var body: some View {
        Group {
            if isLoading && rows.isEmpty {
                ProgressView("Loading budget…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, rows.isEmpty {
                errorState(errorMessage)
            } else {
                editor
            }
        }
        .navigationTitle("Edit Budget")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { fundMenu }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { Task { await save() } }
                    .fontWeight(.semibold)
                    .disabled(dirtyCount == 0 || isSaving)
            }
        }
        .task { if funds.isEmpty { await initialLoad() } }
        .overlay(alignment: .top) { bannerView }
        .confirmationDialog(
            "Discard unsaved changes?",
            isPresented: Binding(get: { pendingFund != nil }, set: { if !$0 { pendingFund = nil } }),
            titleVisibility: .visible
        ) {
            Button("Discard & switch", role: .destructive) {
                if let f = pendingFund { pendingFund = nil; selectedFund = f; Task { await loadFund() } }
            }
            Button("Keep editing", role: .cancel) { pendingFund = nil }
        }
    }

    // MARK: Editor body

    private var editor: some View {
        ScrollView {
            VStack(spacing: 16) {
                bulkToolsCard
                if isSaving { ProgressView().frame(maxWidth: .infinity) }
                group(title: "Revenue", indices: revenueIndices)
                group(title: "Expenses", indices: expenseIndices)
                Text("Editing \(fundName) · values shown as positive; saved in the ledger's sign convention.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var bulkToolsCard: some View {
        NobleCard(padding: 14) {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel("Generate from prior year")
                HStack {
                    Text("Growth")
                        .font(.subheadline)
                    Spacer()
                    TextField("0", value: $growthPct, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                    Text("%").foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Blend").font(.subheadline)
                        Spacer()
                        Text(weightLabel).font(.caption).foregroundStyle(.secondary)
                    }
                    Slider(value: $weight, in: 0...1, step: 0.05)
                        .tint(.nobleEmerald)
                }
                Button {
                    applyGenerateAll()
                } label: {
                    Label("Generate all accounts", systemImage: "wand.and.stars")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.nobleEmerald)

                Divider()

                SectionLabel("Spread annual across months")
                Picker("Spread mode", selection: $spreadMode) {
                    ForEach(SpreadMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                Button {
                    applySpreadAll()
                } label: {
                    Label("Spread each annual", systemImage: "chart.bar.doc.horizontal")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.nobleEmerald)
            }
        }
    }

    private func group(title: String, indices: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !indices.isEmpty {
                HStack {
                    SectionLabel(title)
                    Spacer()
                    Text.money(indices.reduce(0.0) { $0 + rows[$1].annual })
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                NobleCard {
                    VStack(spacing: 0) {
                        ForEach(indices, id: \.self) { i in
                            NavigationLink {
                                BudgetAccountEditorView(
                                    row: $rows[i],
                                    priorActual: priorActualByChild[rows[i].child] ?? Array(repeating: 0, count: 12),
                                    growthPct: growthPct,
                                    weight: weight,
                                    spreadMode: spreadMode
                                )
                            } label: {
                                accountRow(rows[i])
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            if i != indices.last { Divider().padding(.leading, 14) }
                        }
                    }
                }
            }
        }
    }

    private func accountRow(_ row: EditableBudgetRow) -> some View {
        HStack(spacing: 10) {
            if row.isDirty {
                Circle().fill(Color.nobleAmber).frame(width: 7, height: 7)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(row.description).font(.subheadline.weight(.medium)).lineLimit(1)
                Text("#\(row.child)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text.money(row.annual)
                .font(.subheadline.weight(.semibold))
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private var fundMenu: some View {
        Menu {
            ForEach(funds) { fund in
                Button {
                    guard fund.fund != selectedFund else { return }
                    if dirtyCount > 0 { pendingFund = fund.fund }
                    else { selectedFund = fund.fund; Task { await loadFund() } }
                } label: {
                    if fund.fund == selectedFund {
                        Label(fund.displayName, systemImage: "checkmark")
                    } else {
                        Text(fund.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text(selectedFund.isEmpty ? "Fund" : selectedFund)
            }
            .font(.subheadline.weight(.semibold))
        }
    }

    @ViewBuilder private var bannerView: some View {
        if let banner {
            Text(banner)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.nobleEmerald, in: Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40)).foregroundStyle(.secondary)
            Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Retry") { Task { await initialLoad() } }.buttonStyle(.bordered)
        }
        .padding().frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fundName: String {
        funds.first(where: { $0.fund == selectedFund })?.displayName ?? selectedFund
    }

    private var weightLabel: String {
        switch weight {
        case ..<0.01: return "prior budget"
        case 0.99...: return "prior actuals"
        default: return "\(Int((weight * 100).rounded()))% actuals"
        }
    }

    // MARK: Bulk edits

    private func applyGenerateAll() {
        for i in rows.indices {
            let prior = priorActualByChild[rows[i].child] ?? Array(repeating: 0, count: 12)
            rows[i].months = BudgetMath.generate(priorActual: prior, existingBudget: rows[i].months,
                                                 growthPct: growthPct, weight: weight)
        }
        flash("Generated \(rows.count) accounts — review, then Save")
    }

    private func applySpreadAll() {
        for i in rows.indices {
            rows[i].months = BudgetMath.spread(annual: rows[i].annual, mode: spreadMode)
        }
        flash("Spread \(rows.count) annuals — review, then Save")
    }

    // MARK: Data

    private func initialLoad() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            funds = try await apiService.fetchFunds()
            selectedFund = defaultFund(funds)
            // Prior-year actuals (all-funds aggregate) for Generate.
            if let accounts = try? await apiService.fetchAccountList() {
                priorActualByChild = Dictionary(
                    accounts.map { acct in
                        let sign: Double = acct.isRevenueAccount ? -1 : 1
                        return (acct.child, acct.monthlyPrevious.map { v -> Double in let r = v * sign; return r == 0 ? 0 : r })
                    },
                    uniquingKeysWith: { a, _ in a }
                )
            }
            await loadFund()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadFund() async {
        guard !selectedFund.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let accounts = try await apiService.fetchBudgetAccounts(fund: selectedFund)
                .filter { $0.isRevenue || $0.isExpense }
                .sorted { ($0.isRevenue ? 0 : 1, $0.account, $0.child) < ($1.isRevenue ? 0 : 1, $1.account, $1.child) }
            rows = accounts.map(EditableBudgetRow.init)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        let dirty = rows.filter(\.isDirty)
        guard !dirty.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        var failures = 0
        // Sequential per the app's concurrency convention.
        for row in dirty {
            do {
                try await apiService.setBudgetAmts(
                    SetBudgetAmtsRequest(account: row.account, child: row.child,
                                         fund: selectedFund, monthly: row.rawMonths)
                )
            } catch {
                failures += 1
            }
        }
        if failures == 0 {
            flash("Saved \(dirty.count) account\(dirty.count == 1 ? "" : "s")")
        } else {
            flash("Saved \(dirty.count - failures) of \(dirty.count) — \(failures) failed")
        }
        await loadFund()   // reset dirty state from server truth
    }

    private func flash(_ message: String) {
        withAnimation { banner = message }
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation { banner = nil }
        }
    }

    private func defaultFund(_ funds: [FundRef]) -> String {
        // Prefer the operating fund, matching web's effectiveFund default.
        if let oper = funds.first(where: {
            $0.fund.range(of: "oper", options: .caseInsensitive) != nil ||
            ($0.description ?? "").range(of: "oper", options: .caseInsensitive) != nil
        }) {
            return oper.fund
        }
        return funds.first?.fund ?? ""
    }
}

// MARK: - Per-account month editor

struct BudgetAccountEditorView: View {
    @Binding var row: EditableBudgetRow
    let priorActual: [Double]
    let growthPct: Double
    let weight: Double
    var spreadMode: SpreadMode

    @State private var localMode: SpreadMode
    @State private var annualText: String

    init(row: Binding<EditableBudgetRow>, priorActual: [Double], growthPct: Double, weight: Double, spreadMode: SpreadMode) {
        self._row = row
        self.priorActual = priorActual
        self.growthPct = growthPct
        self.weight = weight
        self.spreadMode = spreadMode
        self._localMode = State(initialValue: spreadMode)
        let annual = row.wrappedValue.annual
        self._annualText = State(initialValue: annual == 0 ? "" : String(format: "%.0f", annual))
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                toolsCard
                monthsCard
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(row.description)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        NobleCard(padding: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    StatusPill(text: row.isRevenue ? "REVENUE" : "EXPENSE",
                               color: .nobleEmerald, background: .nobleEmeraldSoft)
                    Spacer()
                    Text("#\(row.child)").font(.caption).foregroundStyle(.secondary)
                }
                Text("Annual total").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                Text.money(row.annual)
                    .font(.title2.weight(.bold))
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var toolsCard: some View {
        NobleCard(padding: 14) {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel("Spread an annual amount")
                HStack(spacing: 10) {
                    TextField("Annual", text: $annualText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                    Picker("", selection: $localMode) {
                        ForEach(SpreadMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
                Button {
                    let annual = Double(annualText) ?? row.annual
                    row.months = BudgetMath.spread(annual: annual, mode: localMode)
                } label: {
                    Text("Spread across 12 months")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.nobleEmerald)

                Divider()

                Button {
                    row.months = BudgetMath.generate(priorActual: priorActual, existingBudget: row.months,
                                                     growthPct: growthPct, weight: weight)
                    annualText = String(format: "%.0f", row.annual)
                } label: {
                    Label("Generate from prior year", systemImage: "wand.and.stars")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.nobleEmerald)
                Text("Growth \(growthPct, format: .number.precision(.fractionLength(0...1)))% · blend set on the previous screen")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var monthsCard: some View {
        NobleCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Monthly budget")
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(0..<12, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(BudgetReport.monthLabels[i])
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("0", value: $row.months[i], format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .padding(8)
                                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
    }
}
