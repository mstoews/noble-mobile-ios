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

    var body: some View {
        TabView {
            DashboardView(userName: userName, companyName: companyName)
                .tabItem {
                    Label("Dashboard", systemImage: "house")
                }

            LedgerView()
                .tabItem {
                    Label("Ledger", systemImage: "list.bullet.rectangle")
                }

            InvoicesView()
                .tabItem {
                    Label("Invoices", systemImage: "doc.text.viewfinder")
                }

            BankingView()
                .tabItem {
                    Label("Banking", systemImage: "building.columns")
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
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @Environment(APIService.self) private var apiService
    let userName: String
    let companyName: String

    @State private var recentEntries: [JournalHeader] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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

                    // Summary Cards
                    VStack(spacing: 12) {
                        SummaryCard(title: "Total Assets", amount: "$3265.25", color: .blue)
                        SummaryCard(title: "Total Liabilities", amount: "$25606.00", color: .red)
                        SummaryCard (title: "Net Balance", amount: "$152.26", color: .green)
                    }
                    .padding(.horizontal)

                    // Recent Entries
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Entries")
                            .font(.headline)
                            .padding(.horizontal)

                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                        } else if recentEntries.isEmpty {
                            Text("No entries yet.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(recentEntries) { entry in
                                    RecentEntryRow(entry: entry)
                                    if entry.id != recentEntries.last?.id {
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
                .padding(.top)
            }
            .navigationTitle("Dashboard")
            .task { await fetchRecentEntries() }
        }
    }

    private func fetchRecentEntries() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let headers = try await apiService.fetchJournalHeaders()
            recentEntries = Array(headers.sorted { $0.journalId > $1.journalId }.prefix(5))
        } catch {
            recentEntries = []
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

struct SummaryCard: View {
    let title: String
    let amount: String
    let color: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(amount)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            Spacer()
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: cardIcon(for: title))
                        .foregroundStyle(color)
                }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func cardIcon(for title: String) -> String {
        switch title {
        case "Total Assets":    return "arrow.up.circle"
        case "Total Liabilities": return "arrow.down.circle"
        default:                return "scalemass"
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
