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

    @State private var isLinkingBank = false
    @State private var linkToken: String?
    @State private var showPlaidLink = false

    var body: some View {
        VStack(spacing: 0) {
            accountCards
            transactionsList
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Banking")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await connectBank() }
                } label: {
                    if isLinkingBank {
                        ProgressView()
                    } else {
                        Text("Connect")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(isLinkingBank)
            }
        }
        .task { await loadAccounts() }
        .refreshable {
            await loadAccounts()
            await loadTransactions()
        }
        .sheet(isPresented: $showPlaidLink) {
            if let linkToken {
                PlaidLinkFlow(
                    linkToken: linkToken,
                    onSuccess: { publicToken in
                        showPlaidLink = false
                        Task {
                            await exchangeToken(publicToken)
                            await loadAccounts()
                        }
                    },
                    onExit: {
                        showPlaidLink = false
                        isLinkingBank = false
                    }
                )
            }
        }
    }

    // MARK: - Account cards

    @ViewBuilder
    private var accountCards: some View {
        if isLoadingAccounts && accounts.isEmpty {
            ProgressView("Loading accounts...")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if accounts.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "building.columns")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("No bank accounts linked.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Tap Connect to link one via Plaid.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(accounts) { account in
                        BankAccountCard(
                            account: account,
                            isSelected: selectedAccount?.id == account.id
                        )
                        .onTapGesture {
                            selectedAccount = account
                            Task { await loadTransactions() }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Transactions

    @ViewBuilder
    private var transactionsList: some View {
        List {
            Section {
                if isLoadingTransactions {
                    ProgressView("Loading transactions...")
                        .frame(maxWidth: .infinity)
                } else if filteredTransactions.isEmpty {
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

                // With no linked accounts the server's "no linked Plaid item"
                // error just restates the empty state above — skip it.
                if let errorMessage, !accounts.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Color.nobleWarn)
                }
            } header: {
                Text("Recent transactions")
            } footer: {
                if !accounts.isEmpty {
                    Text("Synced via Plaid")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
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

    // MARK: - Plaid connect (same flow as Settings)

    private func connectBank() async {
        isLinkingBank = true
        errorMessage = nil
        do {
            let token = try await apiService.createLinkToken()
            linkToken = token
            showPlaidLink = true
        } catch {
            errorMessage = error.localizedDescription
            isLinkingBank = false
        }
    }

    private func exchangeToken(_ publicToken: String) async {
        do {
            try await apiService.exchangePublicToken(publicToken)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLinkingBank = false
    }
}

// MARK: - Bank Account Card

struct BankAccountCard: View {
    let account: BankAccount
    var isSelected: Bool = false

    private var currency: String { account.isoCurrencyCode ?? "USD" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(account.displayName)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .white : .primary)
                Spacer(minLength: 6)
                if let type = account.subtype ?? account.type {
                    Text(type.capitalized)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                }
            }
            if let mask = account.mask {
                Text("···· \(mask)")
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.75) : .secondary)
                    .padding(.top, 1)
            }
            if let current = account.currentBalance {
                Text(current, format: .currency(code: currency))
                    .monospacedDigit()
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .padding(.top, 10)
            }
            if let available = account.availableBalance {
                Text("\(available, format: .currency(code: currency)) available")
                    .monospacedDigit()
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                    .padding(.top, 1)
            }
        }
        .padding(16)
        .frame(width: 210, alignment: .leading)
        .background(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: NobleRadius.card, style: .continuous)
                        .fill(LinearGradient.nobleHero)
                } else {
                    RoundedRectangle(cornerRadius: NobleRadius.card, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                }
            }
        )
        .shadow(
            color: isSelected ? Color.nobleEmerald.opacity(0.28) : .black.opacity(0.06),
            radius: isSelected ? 10 : 3, x: 0, y: isSelected ? 6 : 1
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Bank Transaction Row

struct BankTransactionRow: View {
    let transaction: BankTransaction

    /// Plaid amounts are positive for money out, negative for money in.
    private var isMoneyIn: Bool { (transaction.amount ?? 0) < 0 }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(isMoneyIn ? Color.nobleEmeraldSoft : Color(.tertiarySystemFill))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: isMoneyIn ? "arrow.down" : "arrow.up")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(isMoneyIn ? Color.nobleEmerald : Color.nobleSlate)
                }
                .accessibilityLabel(isMoneyIn ? "Money in" : "Money out")

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let date = transaction.date {
                        Text(date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if transaction.pending == true {
                        StatusPill.open("Pending")
                    }
                }
            }

            Spacer(minLength: 8)

            if let amount = transaction.amount {
                Text("\(isMoneyIn ? "+" : "–")\(abs(amount), format: .currency(code: transaction.isoCurrencyCode ?? "USD"))")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(isMoneyIn ? Color.nobleEmerald : .primary)
            }
        }
        .padding(.vertical, 2)
    }
}
