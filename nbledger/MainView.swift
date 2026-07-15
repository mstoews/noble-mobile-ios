//
//  MainView.swift
//  nbledger
//
//  Created by Murray Toews on 3/31/26.
//

import SwiftUI

enum AppTab: Hashable {
    case home
    case activity
    case capture
    case more
}

struct MainView: View {
    let userName: String
    let userEmail: String
    let companyName: String
    var onLogout: () -> Void

    @State private var selectedTab: AppTab = .home
    @State private var showCapture = false

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(userName: userName, companyName: companyName)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(AppTab.home)

            ActivityView()
                .tabItem {
                    Label("Activity", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(AppTab.activity)

            // Placeholder slot — selecting it opens the capture flow instead
            // of switching tabs (see onChange below).
            Color.clear
                .tabItem {
                    Label("Capture", systemImage: "doc.viewfinder")
                }
                .tag(AppTab.capture)

            MoreView(
                userName: userName,
                userEmail: userEmail,
                companyName: companyName,
                onLogout: onLogout
            )
            .tabItem {
                Label("More", systemImage: "ellipsis")
            }
            .tag(AppTab.more)
        }
        .tint(.nobleEmerald)
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == .capture {
                selectedTab = oldValue
                showCapture = true
            }
        }
        .fullScreenCover(isPresented: $showCapture) {
            InvoicesView(onClose: { showCapture = false })
        }
    }
}

// MARK: - Date Helper

private let dashDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

// MARK: - Dashboard (prototype DashboardA — cash hero, open items, funds, sign-off)

struct DashboardView: View {
    @Environment(APIService.self) private var apiService
    let userName: String
    let companyName: String

    @State private var cashResponse: CashPositionResponse?
    @State private var assetChildren: Set<Int> = []
    @State private var funds: [FundRef] = []
    @State private var payments: [Payment] = []
    @State private var arTransactions: [ArTransaction] = []
    @State private var signOffBills: [AgingBill] = []
    @State private var vendorNames: [String: String] = [:]
    @State private var readOnlyRole = false
    @State private var isLoading = false
    @State private var showAgentChat = false

    // MARK: Computed — Cash position

    /// Rows at an anchor, kept to asset accounts when the chart is known —
    /// the server's cash filter is description-based and can leak expense
    /// accounts like "Bank Charges" until its cash_flow_section column ships.
    private func cashRows(at anchor: String?) -> [CashPositionRow] {
        guard let cashResponse, let anchor else { return [] }
        return cashResponse.rows.filter { row in
            row.asOf == anchor && (assetChildren.isEmpty || assetChildren.contains(row.child))
        }
    }

    private var latestCashRows: [CashPositionRow] { cashRows(at: cashResponse?.anchors.last) }

    private var totalCash: Double {
        latestCashRows.map(\.balance).reduce(0, +)
    }

    private var previousTotalCash: Double? {
        guard let anchors = cashResponse?.anchors, anchors.count >= 2 else { return nil }
        let rows = cashRows(at: anchors[anchors.count - 2])
        guard !rows.isEmpty else { return nil }
        return rows.map(\.balance).reduce(0, +)
    }

    private var cashTrendPercent: Double? {
        guard let previous = previousTotalCash, previous != 0 else { return nil }
        return (totalCash - previous) / abs(previous) * 100
    }

    private struct FundBalance: Identifiable {
        let code: String
        let name: String
        let note: String
        let balance: Double
        var id: String { code }
    }

    private var fundBalances: [FundBalance] {
        let grouped = Dictionary(grouping: latestCashRows, by: \.fund)
        return grouped.map { code, rows in
            var note: [String] = []
            for row in rows where !note.contains(row.childDesc) {
                note.append(row.childDesc)
            }
            let name = funds.first { $0.fund == code }?.description ?? code
            return FundBalance(
                code: code,
                name: name,
                note: note.joined(separator: " · "),
                balance: rows.map(\.balance).reduce(0, +)
            )
        }
        .sorted { $0.balance > $1.balance }
    }

    // MARK: Computed — Open items

    private var openAP: [Payment] {
        payments.filter { $0.status?.uppercased() == "OPEN" }
    }
    private var apOutstanding: Double { openAP.map(\.remainingBalance).reduce(0, +) }

    private var openAR: [ArTransaction] {
        arTransactions.filter {
            let s = $0.status?.uppercased() ?? ""
            return s == "OPEN" || s == "PARTIAL"
        }
    }
    private var arOutstanding: Double { openAR.map(\.remainingBalance).reduce(0, +) }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !companyName.isEmpty {
                        Text(companyName)
                            .font(.footnote.weight(.semibold))
                            .kerning(0.4)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.nobleEmerald)
                    }

                    if isLoading && cashResponse == nil {
                        ProgressView("Loading dashboard...")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                    } else {
                        cashHero
                        openItemTiles
                        fundBalancesSection
                        signOffSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAgentChat = true
                    } label: {
                        Image(systemName: "sparkles")
                    }
                    .accessibilityLabel("AI Assistant")
                }
            }
            .sheet(isPresented: $showAgentChat) {
                AgentChatView()
            }
            .task { await loadDashboardData() }
            .refreshable { await loadDashboardData() }
        }
    }

    // MARK: Sections

    private var cashHero: some View {
        MetricHero(label: "TOTAL CASH ON HAND", value: totalCash) {
            HStack(spacing: 8) {
                Text(fundBalances.count == 1
                     ? "Across 1 fund account"
                     : "Across \(fundBalances.count) fund accounts")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
                if let trend = cashTrendPercent {
                    Text("\(trend >= 0 ? "▲" : "▼") \(abs(trend), specifier: "%.1f")% this month")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(trend >= 0 ? Color.nobleEmeraldOnDark : .white.opacity(0.9))
                }
            }
        }
    }

    private var openItemTiles: some View {
        HStack(spacing: 12) {
            OpenItemTile(
                label: "Open Payments",
                amount: apOutstanding,
                sub: openAP.count == 1 ? "1 bill" : "\(openAP.count) bills",
                tone: .nobleWarn
            )
            OpenItemTile(
                label: "Open Receipts",
                amount: arOutstanding,
                sub: openAR.count == 1 ? "1 invoice" : "\(openAR.count) invoices",
                tone: .nobleBlue
            )
        }
    }

    @ViewBuilder
    private var fundBalancesSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionLabel("Fund balances")
                .padding(.horizontal, 4)
            NobleCard {
                if fundBalances.isEmpty {
                    Text("No cash accounts found.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    VStack(spacing: 0) {
                        ForEach(fundBalances) { fund in
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.nobleFund(fund.code))
                                    .frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(fund.name)
                                        .font(.subheadline.weight(.semibold))
                                    if !fund.note.isEmpty {
                                        Text(fund.note)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 8)
                                Text.money(fund.balance)
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            if fund.id != fundBalances.last?.id {
                                Divider().padding(.leading, 38)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var signOffSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                SectionLabel("Needs sign-off")
                Spacer()
                if !signOffBills.isEmpty {
                    Text("\(signOffBills.count) pending")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.nobleEmerald)
                }
            }
            .padding(.horizontal, 4)

            NobleCard {
                if signOffBills.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal")
                            .foregroundStyle(Color.nobleEmerald)
                        Text("All caught up — nothing awaiting sign-off.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 0) {
                        ForEach(signOffBills) { bill in
                            NavigationLink {
                                BillSignOffDetailView(
                                    bill: bill,
                                    vendorName: vendorNames[bill.vendorId],
                                    readOnlyRole: readOnlyRole,
                                    onUpdated: { Task { await loadDashboardData() } }
                                )
                            } label: {
                                HStack {
                                    SignOffBillRow(bill: bill, vendorName: vendorNames[bill.vendorId])
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            if bill.id != signOffBills.last?.id {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Data

    private func loadDashboardData() async {
        isLoading = true
        defer { isLoading = false }

        // Sequential calls per the app's concurrency convention.
        do {
            let accounts = try await apiService.fetchAccountList()
            assetChildren = Set(
                accounts
                    .filter { $0.acctType?.lowercased() == "asset" }
                    .map(\.child)
            )
        } catch {
            assetChildren = []
        }

        // Previous month end + current month end → hero total and MTD trend.
        let cal = Calendar.current
        let now = Date()
        if let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)),
           let prevMonthStart = cal.date(byAdding: .month, value: -1, to: monthStart),
           let nextMonthStart = cal.date(byAdding: .month, value: 1, to: monthStart),
           let monthEnd = cal.date(byAdding: .day, value: -1, to: nextMonthStart) {
            cashResponse = try? await apiService.fetchCashPosition(
                from: dashDateFormatter.string(from: prevMonthStart),
                to: dashDateFormatter.string(from: monthEnd),
                interval: "monthly"
            )
        }

        funds = (try? await apiService.fetchFunds()) ?? []

        do { payments = try await apiService.fetchApTransactions() } catch { payments = [] }
        do { arTransactions = try await apiService.fetchArTransactions() } catch { arTransactions = [] }

        var year = cal.component(.year, from: now)
        if let period = try? await apiService.fetchCurrentActivePeriod() {
            year = period.periodYear
        }
        if let bills = try? await apiService.fetchAgingBills(periodYear: year, status: "ALL") {
            signOffBills = bills.filter {
                $0.approvalStatus == "PENDING" || $0.approvalStatus == "REVIEW"
            }
        }
        if let vendors = try? await apiService.fetchApVendors() {
            vendorNames = Dictionary(uniqueKeysWithValues: vendors.map { ($0.id, $0.name) })
        }
        if let profile = try? await apiService.fetchMyProfile() {
            let role = (profile.role ?? "").uppercased()
            readOnlyRole = role == "AUDITOR" || role == "REVIEWER"
        }
    }
}

// MARK: - Open Item Tile

private struct OpenItemTile: View {
    let label: String
    let amount: Double
    let sub: String
    let tone: Color

    var body: some View {
        NobleCard(padding: 14) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(tone)
                        .frame(width: 8, height: 8)
                    Text(label)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text.money(amount)
                    .font(.title3.weight(.bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.top, 8)
                Text(sub)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
    @AppStorage("darkAppearance") private var darkAppearance = false
    @State private var role: String?
    @State private var title: String?
    @State private var showLogoutConfirmation = false
    @State private var isLinkingBank = false
    @State private var linkToken: String?
    @State private var showPlaidLink = false
    @State private var bankMessage: String?
    @State private var bankError: String?

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (short, build) {
        case let (short?, build?): return "v\(short).\(build)"
        case let (short?, nil): return "v\(short)"
        default: return ""
        }
    }

    var body: some View {
        List {
            Section("Account") {
                LabeledContent("Name", value: userName.isEmpty ? "—" : userName)
                LabeledContent("Email", value: userEmail.isEmpty ? "—" : userEmail)
                if !companyName.isEmpty {
                    LabeledContent("Company", value: companyName)
                }
                if role != nil || title != nil {
                    LabeledContent("Role") {
                        HStack(spacing: 8) {
                            if let title, !title.isEmpty {
                                Text(title)
                            }
                            if let role, !role.isEmpty {
                                StatusPill(
                                    text: role.uppercased(),
                                    color: .nobleEmerald,
                                    background: .nobleEmeraldSoft
                                )
                            }
                        }
                    }
                }
            }

            Section("Security") {
                Toggle(isOn: $biometricEnabled) {
                    Label("Face ID / Touch ID", systemImage: "faceid")
                }
                .tint(.nobleEmerald)
                Toggle(isOn: $darkAppearance) {
                    Label("Dark appearance", systemImage: "moon")
                }
                .tint(.nobleEmerald)
            }

            Section("Banking") {
                Button {
                    Task { await connectBank() }
                } label: {
                    HStack {
                        Label("Connect a bank account", systemImage: "building.columns")
                            .foregroundStyle(Color.nobleEmerald)
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
                        .foregroundStyle(Color.nobleEmerald)
                }
                if let bankError {
                    Text(bankError)
                        .font(.caption)
                        .foregroundStyle(Color.nobleWarn)
                }
            }

            Section {
                Button("Log Out", role: .destructive) {
                    showLogoutConfirmation = true
                }
                .frame(maxWidth: .infinity)
            } footer: {
                Text("Noble Ledger · \(appVersion)")
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
        .navigationTitle("Settings")
        .task {
            if let profile = try? await apiService.fetchMyProfile() {
                role = profile.role
                title = profile.title
            }
        }
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
    .environment(APIService())
}
