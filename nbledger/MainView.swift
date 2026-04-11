//
//  MainView.swift
//  nbledger
//
//  Created by Murray Toews on 3/31/26.
//

import SwiftUI

struct MainView: View {
    let userName: String
    let userEmail: String
    let companyName: String
    var onLogout: () -> Void

    @State private var showAgentChat = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView {
                DashboardView(userName: userName, companyName: companyName)
                    .tabItem {
                        Label("Dashboard", systemImage: "house")
                    }

                LedgerView()
                    .tabItem {
                        Label("Accounts", systemImage: "list.bullet.rectangle")
                    }

                GLJournalView()
                    .tabItem {
                        Label("Journals", systemImage: "doc.text")
                    }

                InvoicesView()
                    .tabItem {
                        Label("Invoices", systemImage: "doc.text.viewfinder")
                    }

                APPayablesView()
                    .tabItem {
                        Label("Payables", systemImage: "creditcard")
                    }

                BankingView()
                    .tabItem {
                        Label("Banking", systemImage: "building.columns")
                    }

                ARReceivablesView()
                    .tabItem {
                        Label("Receivables", systemImage: "dollarsign.arrow.circlepath")
                    }

                SettingsView(
                    userName: userName,
                    userEmail: userEmail,
                    companyName: companyName,
                    onLogout: onLogout
                )
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
            }

            // Floating AI chat button
            Button {
                showAgentChat = true
            } label: {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.14, green: 0.20, blue: 0.36), Color(red: 0.20, green: 0.40, blue: 0.70)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 70)
        }
        .sheet(isPresented: $showAgentChat) {
            AgentChatView()
        }
    }
}

// MARK: - Date Helper

private let dashDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

private func daysBetween(_ dateString: String?, and reference: Date = Date()) -> Int? {
    guard let dateString, let date = dashDateFormatter.date(from: dateString) else { return nil }
    return Calendar.current.dateComponents([.day], from: date, to: reference).day
}

// MARK: - Aging Bucket

struct AgingBucket: Identifiable {
    let label: String
    let amount: Double
    let count: Int
    let color: Color
    var id: String { label }
}

private func computeAgingBuckets(items: [(dueDate: String?, amount: Double)]) -> [AgingBucket] {
    var current = (amount: 0.0, count: 0)
    var d1to30 = (amount: 0.0, count: 0)
    var d31to60 = (amount: 0.0, count: 0)
    var d61to90 = (amount: 0.0, count: 0)
    var d90plus = (amount: 0.0, count: 0)

    for item in items {
        guard let days = daysBetween(item.dueDate) else {
            current.amount += item.amount
            current.count += 1
            continue
        }
        switch days {
        case ...0:
            current.amount += item.amount
            current.count += 1
        case 1...30:
            d1to30.amount += item.amount
            d1to30.count += 1
        case 31...60:
            d31to60.amount += item.amount
            d31to60.count += 1
        case 61...90:
            d61to90.amount += item.amount
            d61to90.count += 1
        default:
            d90plus.amount += item.amount
            d90plus.count += 1
        }
    }

    return [
        AgingBucket(label: "Current", amount: current.amount, count: current.count, color: .green),
        AgingBucket(label: "1-30", amount: d1to30.amount, count: d1to30.count, color: .yellow),
        AgingBucket(label: "31-60", amount: d31to60.amount, count: d31to60.count, color: .orange),
        AgingBucket(label: "61-90", amount: d61to90.amount, count: d61to90.count, color: Color(red: 1.0, green: 0.4, blue: 0.2)),
        AgingBucket(label: "90+", amount: d90plus.amount, count: d90plus.count, color: .red),
    ]
}

// MARK: - Dashboard

struct DashboardView: View {
    @Environment(APIService.self) private var apiService
    let userName: String
    let companyName: String

    @State private var accounts: [Account] = []
    @State private var payments: [Payment] = []
    @State private var arTransactions: [ArTransaction] = []
    @State private var journals: [JournalHeader] = []
    @State private var isLoading = false

    // MARK: Computed — Financial Summary

    private var totalAssets: Double {
        accounts.filter { $0.acctType?.lowercased() == "asset" }.compactMap(\.balance).reduce(0, +)
    }
    private var totalLiabilities: Double {
        accounts.filter { $0.acctType?.lowercased() == "liability" }.compactMap(\.balance).reduce(0, +)
    }
    private var totalEquity: Double {
        accounts.filter { $0.acctType?.lowercased() == "equity" }.compactMap(\.balance).reduce(0, +)
    }
    private var netPosition: Double { totalAssets - totalLiabilities }

    // MARK: Computed — AR

    private var openAR: [ArTransaction] {
        arTransactions.filter {
            let s = $0.status?.uppercased() ?? ""
            return s == "OPEN" || s == "PARTIAL"
        }
    }
    private var arOutstanding: Double { openAR.map(\.remainingBalance).reduce(0, +) }
    private var arOverdue: [ArTransaction] {
        openAR.filter { guard let d = daysBetween($0.dueDate) else { return false }; return d > 0 }
    }
    private var arDueWithin7: [ArTransaction] {
        openAR.filter {
            guard let d = daysBetween($0.dueDate) else { return false }
            return d >= -7 && d <= 0
        }
    }
    private var arReceivedThisMonth: Double {
        let cal = Calendar.current
        let now = Date()
        return arTransactions.filter {
            guard let ds = $0.datePaid, let d = dashDateFormatter.date(from: ds) else { return false }
            return cal.isDate(d, equalTo: now, toGranularity: .month)
        }.compactMap(\.amountReceived).reduce(0, +)
    }
    private var arAgingBuckets: [AgingBucket] {
        computeAgingBuckets(items: openAR.map { ($0.dueDate, $0.remainingBalance) })
    }

    // MARK: Computed — AP

    private var openAP: [Payment] {
        payments.filter { $0.status?.uppercased() == "OPEN" }
    }
    private var apOutstanding: Double { openAP.map(\.remainingBalance).reduce(0, +) }
    private var apOverdue: [Payment] {
        openAP.filter { guard let d = daysBetween($0.dueDate) else { return false }; return d > 0 }
    }
    private var apDueWithin7: [Payment] {
        openAP.filter {
            guard let d = daysBetween($0.dueDate) else { return false }
            return d >= -7 && d <= 0
        }
    }
    private var apPaidThisMonth: Double {
        let cal = Calendar.current
        let now = Date()
        return payments.filter {
            guard let ds = $0.datePaid, let d = dashDateFormatter.date(from: ds) else { return false }
            return cal.isDate(d, equalTo: now, toGranularity: .month)
        }.compactMap(\.amountPaid).reduce(0, +)
    }
    private var apAgingBuckets: [AgingBucket] {
        computeAgingBuckets(items: openAP.map { ($0.dueDate, $0.remainingBalance) })
    }

    // MARK: Computed — Cash Flow

    private var currentPeriod: Int { Calendar.current.component(.month, from: Date()) }

    private func periodValue(_ account: Account, _ period: Int) -> Double {
        switch period {
        case 1: return account.period1 ?? 0
        case 2: return account.period2 ?? 0
        case 3: return account.period3 ?? 0
        case 4: return account.period4 ?? 0
        case 5: return account.period5 ?? 0
        case 6: return account.period6 ?? 0
        case 7: return account.period7 ?? 0
        case 8: return account.period8 ?? 0
        case 9: return account.period9 ?? 0
        case 10: return account.period10 ?? 0
        case 11: return account.period11 ?? 0
        case 12: return account.period12 ?? 0
        default: return 0
        }
    }

    private func budgetValue(_ account: Account, _ period: Int) -> Double {
        switch period {
        case 1: return account.budget1 ?? 0
        case 2: return account.budget2 ?? 0
        case 3: return account.budget3 ?? 0
        case 4: return account.budget4 ?? 0
        case 5: return account.budget5 ?? 0
        case 6: return account.budget6 ?? 0
        case 7: return account.budget7 ?? 0
        case 8: return account.budget8 ?? 0
        case 9: return account.budget9 ?? 0
        case 10: return account.budget10 ?? 0
        case 11: return account.budget11 ?? 0
        case 12: return account.budget12 ?? 0
        default: return 0
        }
    }

    private func monthlyRevenue(_ period: Int) -> Double {
        accounts.filter { $0.acctType?.lowercased() == "revenue" || $0.acctType?.lowercased() == "income" }
            .map { periodValue($0, period) }.reduce(0, +)
    }

    private func monthlyExpenses(_ period: Int) -> Double {
        accounts.filter { $0.acctType?.lowercased() == "expense" }
            .map { periodValue($0, period) }.reduce(0, +)
    }

    private var cashFlowData: [(period: Int, revenue: Double, expenses: Double)] {
        let start = max(1, currentPeriod - 5)
        return (start...currentPeriod).map { p in
            (period: p, revenue: monthlyRevenue(p), expenses: monthlyExpenses(p))
        }
    }

    // MARK: Computed — Budget vs Actual

    private var ytdActualRevenue: Double {
        (1...currentPeriod).map { monthlyRevenue($0) }.reduce(0, +)
    }
    private var ytdBudgetRevenue: Double {
        let revenueAccts = accounts.filter { $0.acctType?.lowercased() == "revenue" || $0.acctType?.lowercased() == "income" }
        return (1...currentPeriod).flatMap { p in revenueAccts.map { budgetValue($0, p) } }.reduce(0, +)
    }
    private var ytdActualExpenses: Double {
        (1...currentPeriod).map { monthlyExpenses($0) }.reduce(0, +)
    }
    private var ytdBudgetExpenses: Double {
        let expenseAccts = accounts.filter { $0.acctType?.lowercased() == "expense" }
        return (1...currentPeriod).flatMap { p in expenseAccts.map { budgetValue($0, p) } }.reduce(0, +)
    }

    // MARK: Computed — Open Journals

    private var unbookedJournals: [JournalHeader] {
        journals.filter { $0.booked != true }
    }
    private var unbookedAmount: Double {
        unbookedJournals.compactMap(\.amount).reduce(0, +)
    }

    private var recentEntries: [JournalHeader] {
        Array(journals.sorted { $0.journalId > $1.journalId }.prefix(5))
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Greeting
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hello, \(userName.isEmpty ? "there" : userName)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        if !companyName.isEmpty {
                            Text(companyName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    if isLoading {
                        ProgressView("Loading dashboard...")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else {
                        // 1. Financial Summary
                        FinancialSummaryWidget(
                            assets: totalAssets,
                            liabilities: totalLiabilities,
                            equity: totalEquity,
                            netPosition: netPosition
                        )

                        // 2. AR Aging
                        AgingWidget(
                            title: "Receivables",
                            icon: "dollarsign.arrow.circlepath",
                            outstanding: arOutstanding,
                            overdueCount: arOverdue.count,
                            overdueAmount: arOverdue.map(\.remainingBalance).reduce(0, +),
                            due7Count: arDueWithin7.count,
                            due7Amount: arDueWithin7.map(\.remainingBalance).reduce(0, +),
                            paidLabel: "Received This Month",
                            paidAmount: arReceivedThisMonth,
                            buckets: arAgingBuckets
                        )

                        // 3. AP Aging
                        AgingWidget(
                            title: "Payables",
                            icon: "creditcard",
                            outstanding: apOutstanding,
                            overdueCount: apOverdue.count,
                            overdueAmount: apOverdue.map(\.remainingBalance).reduce(0, +),
                            due7Count: apDueWithin7.count,
                            due7Amount: apDueWithin7.map(\.remainingBalance).reduce(0, +),
                            paidLabel: "Paid This Month",
                            paidAmount: apPaidThisMonth,
                            buckets: apAgingBuckets
                        )

                        // 4. Cash Flow
                        CashFlowWidget(data: cashFlowData, currentPeriod: currentPeriod)

                        // 5. Budget vs Actual
                        BudgetWidget(
                            actualRevenue: ytdActualRevenue,
                            budgetRevenue: ytdBudgetRevenue,
                            actualExpenses: ytdActualExpenses,
                            budgetExpenses: ytdBudgetExpenses
                        )

                        // 6. Open Journals
                        OpenJournalsWidget(count: unbookedJournals.count, amount: unbookedAmount)

                        // Recent Entries
                        RecentEntriesWidget(entries: recentEntries)
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Dashboard")
            .task { await loadDashboardData() }
            .refreshable { await loadDashboardData() }
        }
    }

    private func loadDashboardData() async {
        isLoading = true
        defer { isLoading = false }

        do { accounts = try await apiService.fetchAccountList() } catch { accounts = [] }
        do { journals = try await apiService.fetchJournalHeaders() } catch { journals = [] }
        do { payments = try await apiService.fetchPayments() } catch { payments = [] }
        do { arTransactions = try await apiService.fetchArTransactions() } catch { arTransactions = [] }
    }
}

// MARK: - Financial Summary Widget

struct FinancialSummaryWidget: View {
    let assets: Double
    let liabilities: Double
    let equity: Double
    let netPosition: Double

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                SummaryCard(title: "Assets", amount: assets, color: .blue, icon: "arrow.up.circle")
                SummaryCard(title: "Liabilities", amount: liabilities, color: .red, icon: "arrow.down.circle")
            }
            HStack(spacing: 10) {
                SummaryCard(title: "Equity", amount: equity, color: .purple, icon: "building.columns")
                SummaryCard(title: "Net Position", amount: netPosition, color: .green, icon: "scalemass")
            }
        }
        .padding(.horizontal)
    }
}

struct SummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(amount, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(amount < 0 ? .red : .primary)
            }
            Spacer()
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(color)
                }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Aging Widget (shared AR/AP)

struct AgingWidget: View {
    let title: String
    let icon: String
    let outstanding: Double
    let overdueCount: Int
    let overdueAmount: Double
    let due7Count: Int
    let due7Amount: Double
    let paidLabel: String
    let paidAmount: Double
    let buckets: [AgingBucket]

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Label(title, systemImage: icon)
                        .font(.headline)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            // KPI Row
            HStack(spacing: 0) {
                KPICell(label: "Outstanding", value: outstanding, color: .primary)
                KPICell(label: "Overdue (\(overdueCount))", value: overdueAmount, color: .red)
                KPICell(label: "Due 7d (\(due7Count))", value: due7Amount, color: .orange)
            }

            if isExpanded {
                // Paid this month
                HStack {
                    Text(paidLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(paidAmount, format: .currency(code: "USD"))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.green)
                }

                // Aging bars
                let total = buckets.map(\.amount).reduce(0, +)
                if total > 0 {
                    VStack(spacing: 6) {
                        Text("Aging")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(buckets) { bucket in
                            if bucket.count > 0 {
                                HStack(spacing: 8) {
                                    Text(bucket.label)
                                        .font(.caption2)
                                        .frame(width: 50, alignment: .leading)
                                    GeometryReader { geo in
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(bucket.color.opacity(0.7))
                                            .frame(width: max(4, geo.size.width * bucket.amount / total))
                                    }
                                    .frame(height: 12)
                                    Text(bucket.amount, format: .currency(code: "USD"))
                                        .font(.caption2.monospacedDigit())
                                        .frame(width: 80, alignment: .trailing)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

struct KPICell: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value, format: .currency(code: "USD"))
                .font(.caption.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Cash Flow Widget

struct CashFlowWidget: View {
    let data: [(period: Int, revenue: Double, expenses: Double)]
    let currentPeriod: Int

    private let monthNames = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                               "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    private var currentCashFlow: Double {
        guard let current = data.last else { return 0 }
        return current.revenue - current.expenses
    }

    private var previousCashFlow: Double {
        guard data.count >= 2 else { return 0 }
        let prev = data[data.count - 2]
        return prev.revenue - prev.expenses
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Cash Flow", systemImage: "chart.bar")
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: currentCashFlow >= previousCashFlow ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption)
                        .foregroundStyle(currentCashFlow >= previousCashFlow ? .green : .red)
                    Text(currentCashFlow, format: .currency(code: "USD"))
                        .font(.subheadline.monospacedDigit())
                        .fontWeight(.semibold)
                        .foregroundStyle(currentCashFlow >= 0 ? .green : .red)
                }
            }

            if !data.isEmpty {
                let maxVal = data.map { max(abs($0.revenue), abs($0.expenses)) }.max() ?? 1
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(data, id: \.period) { item in
                        VStack(spacing: 4) {
                            let net = item.revenue - item.expenses
                            RoundedRectangle(cornerRadius: 3)
                                .fill(net >= 0 ? Color.green.opacity(0.7) : Color.red.opacity(0.7))
                                .frame(height: max(4, CGFloat(abs(net) / maxVal) * 60))
                            Text(item.period <= 12 ? monthNames[item.period] : "\(item.period)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 80)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Budget Widget

struct BudgetWidget: View {
    let actualRevenue: Double
    let budgetRevenue: Double
    let actualExpenses: Double
    let budgetExpenses: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Budget vs Actual (YTD)", systemImage: "chart.pie")
                .font(.headline)

            BudgetRow(
                label: "Revenue",
                actual: actualRevenue,
                budget: budgetRevenue,
                overIsGood: true
            )
            BudgetRow(
                label: "Expenses",
                actual: actualExpenses,
                budget: budgetExpenses,
                overIsGood: false
            )
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

struct BudgetRow: View {
    let label: String
    let actual: Double
    let budget: Double
    let overIsGood: Bool

    private var variance: Double {
        guard budget != 0 else { return 0 }
        return ((actual - budget) / abs(budget)) * 100
    }

    private var progress: Double {
        guard budget != 0 else { return 0 }
        return min(actual / abs(budget), 1.5)
    }

    private var isHealthy: Bool {
        overIsGood ? actual >= budget : actual <= budget
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(actual, format: .currency(code: "USD")) / \(budget, format: .currency(code: "USD"))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.15))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isHealthy ? Color.green.opacity(0.7) : Color.red.opacity(0.7))
                            .frame(width: max(0, min(geo.size.width, geo.size.width * progress)))
                    }
                }
                .frame(height: 10)
                Text(String(format: "%+.1f%%", variance))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(isHealthy ? .green : .red)
                    .frame(width: 50, alignment: .trailing)
            }
        }
    }
}

// MARK: - Open Journals Widget

struct OpenJournalsWidget: View {
    let count: Int
    let amount: Double

    var body: some View {
        HStack {
            Label("Open Journals", systemImage: "doc.text")
                .font(.headline)
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange, in: Capsule())
                Text(amount, format: .currency(code: "USD"))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text("All booked")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Recent Entries Widget

struct RecentEntriesWidget: View {
    let entries: [JournalHeader]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Entries")
                .font(.headline)
                .padding(.horizontal)

            if entries.isEmpty {
                Text("No entries yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                VStack(spacing: 0) {
                    ForEach(entries) { entry in
                        RecentEntryRow(entry: entry)
                        if entry.id != entries.last?.id {
                            Divider()
                                .padding(.horizontal)
                        }
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
    }
}

struct RecentEntryRow: View {
    let entry: JournalHeader

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.description)
                    .font(.subheadline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let date = entry.transactionDate {
                        Text(date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let type = entry.type {
                        Text(type)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if let amount = entry.amount {
                Text(amount, format: .currency(code: "USD"))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(amount < 0 ? .red : .primary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Environment(APIService.self) private var apiService
    let userName: String
    let userEmail: String
    let companyName: String
    var onLogout: () -> Void

    @AppStorage("biometricEnabled") private var biometricEnabled = false
    @State private var showLogoutConfirmation = false
    @State private var isLinkingBank = false
    @State private var linkToken: String?
    @State private var showPlaidLink = false
    @State private var bankMessage: String?
    @State private var bankError: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    LabeledContent("Name", value: userName.isEmpty ? "—" : userName)
                    LabeledContent("Email", value: userEmail.isEmpty ? "—" : userEmail)
                    if !companyName.isEmpty {
                        LabeledContent("Company", value: companyName)
                    }
                }

                Section("Security") {
                    Toggle(isOn: $biometricEnabled) {
                        Label("Face ID / Touch ID", systemImage: "faceid")
                    }
                }

                Section("Maintenance") {
                    NavigationLink {
                        VendorMaintenanceView()
                    } label: {
                        Label("AP Vendors", systemImage: "person.2")
                    }
                    NavigationLink {
                        CustomerMaintenanceView()
                    } label: {
                        Label("AR Customers", systemImage: "person.3")
                    }
                }

                Section("Banking") {
                    Button {
                        Task { await connectBank() }
                    } label: {
                        HStack {
                            Label("Connect Bank Account", systemImage: "building.columns")
                            Spacer()
                            if isLinkingBank {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isLinkingBank)

                    if let bankMessage {
                        Text(bankMessage)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    if let bankError {
                        Text(bankError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button("Log Out", role: .destructive) {
                        showLogoutConfirmation = true
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Are you sure you want to log out?", isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
                Button("Log Out", role: .destructive, action: onLogout)
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showPlaidLink) {
                if let linkToken {
                    PlaidLinkFlow(
                        linkToken: linkToken,
                        onSuccess: { publicToken in
                            showPlaidLink = false
                            Task { await exchangeToken(publicToken) }
                        },
                        onExit: {
                            showPlaidLink = false
                            isLinkingBank = false
                        }
                    )
                }
            }
        }
    }

    private func connectBank() async {
        isLinkingBank = true
        bankMessage = nil
        bankError = nil

        do {
            let token = try await apiService.createLinkToken()
            linkToken = token
            showPlaidLink = true
        } catch {
            bankError = error.localizedDescription
            isLinkingBank = false
        }
    }

    private func exchangeToken(_ publicToken: String) async {
        do {
            try await apiService.exchangePublicToken(publicToken)
            bankMessage = "Bank account connected successfully."
        } catch {
            bankError = error.localizedDescription
        }
        isLinkingBank = false
    }
}

// MARK: - Preview

#Preview {
    MainView(
        userName: "Jane Smith",
        userEmail: "jane@example.com",
        companyName: "Acme Corp",
        onLogout: {}
    )
}
