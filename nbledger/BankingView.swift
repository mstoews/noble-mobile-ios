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
    @State private var movements: [CashMovement] = []
    @State private var isLoadingAccounts = false
    @State private var isLoadingMovements = false
    @State private var errorMessage: String?
    @State private var selectedAccount: BankAccount?
    @State private var outstandingOnly = false
    @State private var isSyncing = false

    /// The server requires an explicit window on the cash-movement read, so
    /// the screen commits to one rather than pretending to show "everything".
    private static let windowDays = 90

    @State private var isLinkingBank = false
    @State private var linkToken: String?
    @State private var showPlaidLink = false

    var body: some View {
        VStack(spacing: 0) {
            accountCards
            movementsList
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Banking")
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    Task { await syncNow() }
                } label: {
                    Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(isSyncing || accounts.isEmpty)
            }
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
            await loadMovements()
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
                            Task { await loadMovements() }
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
    private var movementsList: some View {
        // With nothing linked, the accounts empty state above already says
        // everything; a bare "Cash movements" header under it just looked
        // like a section that had failed to load.
        if accounts.isEmpty {
            Spacer()
        } else {
            movementsListBody
        }
    }

    @ViewBuilder
    private var movementsListBody: some View {
        List {
            Section {
                if isLoadingMovements {
                    ProgressView("Loading movements...")
                        .frame(maxWidth: .infinity)
                } else if movements.isEmpty {
                    if selectedAccount != nil {
                        Text(outstandingOnly
                             ? "Nothing outstanding in this window."
                             : "No cash movements in this window.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else if !accounts.isEmpty {
                        Text("Select an account to view its cash movements.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                } else {
                    ForEach(movements) { movement in
                        CashMovementRow(movement: movement)
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
                HStack {
                    Text("Cash movements")
                    Spacer()
                    if selectedAccount != nil {
                        Toggle("Outstanding only", isOn: $outstandingOnly)
                            .toggleStyle(.button)
                            .font(.caption)
                            .onChange(of: outstandingOnly) {
                                Task { await loadMovements() }
                            }
                    }
                }
            } footer: {
                if !accounts.isEmpty {
                    // Provider-agnostic by design: every payment out and
                    // receipt in lands in cash_movements whatever its origin.
                    Text("Last \(Self.windowDays) days. An unreconciled movement has no journal yet.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
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
                await loadMovements()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Reads one account's movements. The server scopes by account and demands
    /// a date range, so there is no "all accounts" list to filter client-side.
    private func loadMovements() async {
        guard let account = selectedAccount else {
            movements = []
            return
        }
        isLoadingMovements = true
        defer { isLoadingMovements = false }
        let to = Date()
        let from = Calendar.current.date(byAdding: .day, value: -Self.windowDays, to: to) ?? to
        do {
            movements = try await apiService.fetchCashMovements(
                bankAccountID: account.id,
                from: from,
                to: to,
                outstandingOnly: outstandingOnly
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Ingest is normally webhook-driven; this covers an Item whose webhook
    /// Plaid cannot reach, which is why it is a button and not an on-appear
    /// side effect.
    private func syncNow() async {
        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }
        do {
            try await apiService.syncBankTransactions()
            await loadMovements()
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(account.displayName)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .white : .primary)
                Spacer(minLength: 6)
                if let subtype = account.subtype {
                    Text(subtype.capitalized)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                }
            }

            if let institution = account.institutionName {
                Text(institution)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .white.opacity(0.75) : .secondary)
                    .padding(.top, 1)
            }

            if let mask = account.mask {
                Text("···· \(mask)")
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.75) : .secondary)
                    .padding(.top, 1)
            }

            if let current = account.balanceCurrent {
                Text(current, format: .currency(code: account.currency ?? "USD"))
                    .monospacedDigit()
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .padding(.top, 8)
                if let available = account.balanceAvailable, available != current {
                    Text("\(available, format: .currency(code: account.currency ?? "USD")) available")
                        .monospacedDigit()
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                }
            }

            Spacer(minLength: 6)

            HStack(spacing: 6) {
                // Unmapped is a normal state for a freshly linked account, and
                // it is worth surfacing: an unmapped account cannot be used as
                // a payment source.
                if let glChild = account.glChild {
                    Text("GL \(glChild)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? .white : .primary)
                } else {
                    Text("No GL mapping")
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : Color.nobleWarn)
                }
                if let fund = account.fund {
                    Text("· \(fund)")
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                }
                Spacer(minLength: 4)
                if !account.active {
                    StatusPill.open("Paused")
                }
            }
            .padding(.top, 10)
        }
        .padding(16)
        .frame(width: 210, height: 150, alignment: .leading)
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

// MARK: - Cash Movement Row

struct CashMovementRow: View {
    let movement: CashMovement

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(movement.isMoneyIn ? Color.nobleEmeraldSoft : Color(.tertiarySystemFill))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: movement.isMoneyIn ? "arrow.down" : "arrow.up")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(movement.isMoneyIn ? Color.nobleEmerald : Color.nobleSlate)
                }
                .accessibilityLabel(movement.isMoneyIn ? "Money in" : "Money out")

            VStack(alignment: .leading, spacing: 2) {
                Text(movement.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(movement.date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    // journal_id IS NULL is the rec-status source of truth.
                    if movement.isOutstanding {
                        StatusPill.open("Unreconciled")
                    }
                    if movement.status != "posted" {
                        StatusPill.open(movement.status.capitalized)
                    }
                }
            }

            Spacer(minLength: 8)

            // Server convention: + inflow, − outflow. The old Plaid-shaped row
            // assumed the opposite and would have rendered every sign backwards.
            Text("\(movement.isMoneyIn ? "+" : "–")\(abs(movement.amount), format: .currency(code: movement.currency))")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(movement.isMoneyIn ? Color.nobleEmerald : .primary)
        }
        .padding(.vertical, 2)
    }
}
