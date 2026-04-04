//
//  LedgerView.swift
//  nbledger
//
//  Created by Murray Toews on 3/31/26.
//

import SwiftUI

// MARK: - Ledger

struct LedgerView: View {
    @Environment(APIService.self) private var apiService
    @State private var accounts: [Account] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading accounts…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Retry") { Task { await fetchAccounts() } }
                            .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if accounts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No accounts found.")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(accounts) { account in
                        AccountRow(account: account)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Accounts")
            .task { await fetchAccounts() }
            .refreshable { await fetchAccounts() }
        }
    }

    private func fetchAccounts() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            accounts = try await apiService.fetchAccountList()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AccountRow: View {
    let account: Account

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.body)
                HStack(spacing: 6) {
                    Text(account.accountCode)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let acctType = account.acctType {
                        Text(acctType.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(typeColor(acctType).opacity(0.15), in: Capsule())
                            .foregroundStyle(typeColor(acctType))
                    }
                }
            }
            Spacer()
            if let balance = account.balance {
                Text(balance, format: .currency(code: "USD"))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(balance < 0 ? .red : .primary)
            }
        }
        .padding(.vertical, 2)
    }

    private func typeColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "asset":      return .blue
        case "liability":  return .red
        case "equity":     return .purple
        case "income", "revenue": return .green
        case "expense":    return .orange
        default:           return .secondary
        }
    }
}
