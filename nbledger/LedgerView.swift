//
//  LedgerView.swift
//  nbledger
//
//  Created by Murray Toews on 3/31/26.
//

import SwiftUI

// MARK: - Account Type Ordering

private let acctTypeOrder: [String] = ["asset", "liability", "equity", "revenue", "income", "expense"]

private func acctTypeSortKey(_ type: String) -> Int {
    acctTypeOrder.firstIndex(of: type.lowercased()) ?? 99
}

// MARK: - Grouped Account Hierarchy

/// Two tiers: account type, then the parent account number.
///
/// There used to be a sub-type tier between them, but no account read exposes
/// a sub-type: `gl_accounts` has no such column (`gl_sub_type` is a standalone
/// lookup table with no link to an account), so every account fell into a
/// single "General" bucket and the tier rendered one meaningless row per
/// group. Restoring it needs a server-side schema change, not a client fix.
struct AccountTypeGroup: Identifiable {
    let acctType: String
    let parentAccounts: [ParentAccountGroup]
    let totalBalance: Double
    var id: String { acctType }
}

struct ParentAccountGroup: Identifiable {
    let account: Int
    let description: String
    let children: [Account]
    let totalBalance: Double
    var id: Int { account }
}

private func buildParentGroups(_ accounts: [Account]) -> [ParentAccountGroup] {
    let byParent = Dictionary(grouping: accounts) { $0.account }
    var result: [ParentAccountGroup] = []
    for (parentAcct, children) in byParent {
        let sorted = children.sorted { $0.child < $1.child }
        // The group name used to come from a header row (child = 0,
        // parent_account = true). Migration 000136 deleted those rows and
        // normalised parent_account to uniformly false, so that lookup could
        // never match again and silently fell through to this same first-child
        // description. Asking directly is honest about what is available.
        let parentDesc = sorted.first?.description ?? "Account \(parentAcct)"
        let total = sorted.compactMap(\.balance).reduce(0, +)
        result.append(ParentAccountGroup(account: parentAcct, description: parentDesc, children: sorted, totalBalance: total))
    }
    return result.sorted { $0.account < $1.account }
}

private func buildHierarchy(_ accounts: [Account]) -> [AccountTypeGroup] {
    let byType = Dictionary(grouping: accounts) { ($0.acctType ?? "Other").lowercased() }
    var result: [AccountTypeGroup] = []
    for (acctType, accts) in byType {
        let parents = buildParentGroups(accts)
        let total = parents.map(\.totalBalance).reduce(0, +)
        result.append(AccountTypeGroup(acctType: acctType, parentAccounts: parents, totalBalance: total))
    }
    return result.sorted { acctTypeSortKey($0.acctType) < acctTypeSortKey($1.acctType) }
}

// MARK: - Ledger

struct LedgerView: View {
    @Environment(APIService.self) private var apiService
    @State private var accounts: [Account] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var hierarchy: [AccountTypeGroup] {
        buildHierarchy(accounts)
    }

    // No root NavigationStack — this view is pushed from the More hub's stack.
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading accounts...")
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
                List {
                    ForEach(hierarchy) { typeGroup in
                        AccountTypeSection(group: typeGroup)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Accounts")
        .task { await fetchAccounts() }
        .refreshable { await fetchAccounts() }
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

// MARK: - Account Type Section

// Raw signed balances (credit-natured categories read negative) render in
// the primary color everywhere — red is reserved for variance/overdue, not
// for the ledger's sign convention.
struct AccountTypeSection: View {
    let group: AccountTypeGroup

    @State private var isExpanded = true

    var body: some View {
        Section {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Text(group.acctType.capitalized)
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Text.money(group.totalBalance)
                        .font(.subheadline.weight(.semibold))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(group.acctType.capitalized), \(isExpanded ? "expanded" : "collapsed")")

            if isExpanded {
                ForEach(group.parentAccounts) { parent in
                    ParentAccountSection(parent: parent, acctType: group.acctType)
                }
            }
        }
    }   
}

// MARK: - Parent Account Section

struct ParentAccountSection: View {
    let parent: ParentAccountGroup
    let acctType: String

    var body: some View {
        if parent.children.count == 1, let only = parent.children.first {
            AccountRow(account: only, acctType: acctType, indent: 1)
        } else {
            VStack(spacing: 0) {
                // Parent header
                HStack {
                    Text(parent.description)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Text.money(parent.totalBalance)
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.vertical, 2)

                // Child accounts
                ForEach(parent.children) { child in
                    if child.parentAccount != true {
                        AccountRow(account: child, acctType: acctType, indent: 2)
                    }
                }
            }
        }
    }
}

// MARK: - Account Row

struct AccountRow: View {
    let account: Account
    let acctType: String
    let indent: Int

    var body: some View {
        HStack(spacing: 8) {
            if indent > 1 {
                Color.clear.frame(width: CGFloat(indent - 1) * 14, height: 1)
            }
            Text(String(account.child))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.nobleEmerald)
                .frame(width: 42, alignment: .leading)
            Text(account.displayName)
                .font(indent > 1 ? .footnote : .subheadline)
                .lineLimit(1)
            Spacer()
            if let balance = account.balance {
                Text.money(balance)
                    .font(indent > 1 ? .footnote : .subheadline)
            }
        }
        .padding(.vertical, 2)
    }
}
