//
//  BankingView.swift
//  nbledger
//
//  Created by Murray Toews on 4/4/26.
//

import SwiftUI

// MARK: - Banking Container

struct BankingView: View {
    @Environment(APIService.self) private var apiService

    @State private var accounts: [BankAccount] = []
    @State private var transactions: [BankTransaction] = []
    @State private var isLoadingAccounts = false
    @State private var isLoadingTransactions = false
    @State private var errorMessage: String?
    @State private var selectedAccount: BankAccount?

    var body: some View {
        List {
            accountsSection
            transactionsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Banking")
        .task { await loadAccounts() }
        .refreshable {
            await loadAccounts()
            await loadTransactions()
        }
    }

    // MARK: - Accounts Section

    private var accountsSection: some View {
        Section("Accounts") {
            if isLoadingAccounts {
                ProgressView("Loading accounts...")
                    .frame(maxWidth: .infinity)
            } else if accounts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "building.columns")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No bank accounts linked.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Go to Settings to connect a bank.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                ForEach(accounts) { account in
                    BankAccountRow(
                        account: account,
                        isSelected: selectedAccount?.id == account.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedAccount = account
                        Task { await loadTransactions() }
                    }
                }
            }
        }
    }

    // MARK: - Transactions Section

    private var transactionsSection: some View {
        Section(transactionsSectionTitle) {
            if isLoadingTransactions {
                ProgressView("Loading transactions...")
                    .frame(maxWidth: .infinity)
            } else if transactions.isEmpty {
                if selectedAccount != nil {
                    Text("No transactions found.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else if !accounts.isEmpty {
                    Text("Select an account to view transactions.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            } else {
                ForEach(filteredTransactions) { transaction in
                    BankTransactionRow(transaction: transaction)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var transactionsSectionTitle: String {
        if let account = selectedAccount {
            return "Transactions - \(account.displayName)"
        }
        return "Transactions"
    }

    private var filteredTransactions: [BankTransaction] {
        guard let account = selectedAccount else { return transactions }
        return transactions.filter { $0.accountId == account.id }
    }

    // MARK: - Data Loading

    private func loadAccounts() async {
        isLoadingAccounts = true
        errorMessage = nil
        defer { isLoadingAccounts = false }
        do {
            accounts = try await apiService.fetchBankAccounts()
            if selectedAccount == nil, let first = accounts.first {
                selectedAccount = first
                await loadTransactions()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadTransactions() async {
        isLoadingTransactions = true
        defer { isLoadingTransactions = false }
        do {
            transactions = try await apiService.fetchBankTransactions()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Bank Account Row

struct BankAccountRow: View {
    let account: BankAccount
    var isSelected: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(account.displayName)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                HStack(spacing: 8) {
                    if let institution = account.institutionName {
                        Text(institution)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let type = account.subtype ?? account.type {
                        Text(type.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                    if let mask = account.mask {
                        Text("••\(mask)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let current = account.currentBalance {
                    Text(current, format: .currency(code: account.isoCurrencyCode ?? "USD"))
                        .font(.body.monospacedDigit())
                }
                if let available = account.availableBalance {
                    Text("Avail: \(available, format: .currency(code: account.isoCurrencyCode ?? "USD"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(isSelected ? Color.blue.opacity(0.08) : nil)
    }
}

// MARK: - Bank Transaction Row

struct BankTransactionRow: View {
    let transaction: BankTransaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.displayName)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let date = transaction.date {
                        Text(date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let category = transaction.primaryCategory {
                        Text(category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if transaction.pending == true {
                        Text("Pending")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
            }
            Spacer()
            if let amount = transaction.amount {
                Text(amount, format: .currency(code: transaction.isoCurrencyCode ?? "USD"))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(amount < 0 ? .green : .primary)
            }
        }
        .padding(.vertical, 2)
    }
}
