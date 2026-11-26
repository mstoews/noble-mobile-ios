//
//  DemoFixtures.swift
//  nbledger
//
//  Sample API responses for the test-only demo session (see DemoMode.swift).
//  Only endpoints listed in `body(forPath:)` are stubbed; everything else gets
//  DemoURLProtocol's 503.
//
//  `/account_balances` drives both the Chart of Accounts (grouped by
//  acct_type → account → child) and the Budget report (revenue/expense
//  budget_N vs period_N). Values follow the server's sign convention:
//  debit-normal accounts are positive, credit-normal (liability, equity,
//  revenue) are negative.
//

import Foundation

nonisolated enum DemoFixtures {
    /// JSON body for a request path, or nil when the path has no fixture.
    static func body(forPath path: String) -> Data? {
        if path.hasSuffix("/account_balances") {
            return try? JSONSerialization.data(withJSONObject: accountBalances)
        }
        return nil
    }

    // MARK: - /account_balances

    /// (account, child, type, description, monthly budget, monthly actual
    /// variation, balance for balance-sheet accounts)
    private struct Row {
        let account: Int
        let child: Int
        let type: String
        let description: String
        var monthlyBudget: Double = 0
        var variation: [Double] = []   // added to budget to make actuals
        var balance: Double = 0
    }

    private static let rows: [Row] = [
        Row(account: 1000, child: 1, type: "Asset", description: "Operating Bank Account", balance: 48_250),
        Row(account: 1000, child: 2, type: "Asset", description: "Petty Cash", balance: 500),
        Row(account: 1100, child: 1, type: "Asset", description: "Reserve Fund Investments", balance: 312_400),
        Row(account: 1200, child: 1, type: "Asset", description: "Levies Receivable", balance: 6_850),
        Row(account: 2000, child: 1, type: "Liability", description: "Accounts Payable", balance: -12_340),
        Row(account: 2100, child: 1, type: "Liability", description: "Prepaid Levies", balance: -3_200),
        Row(account: 3000, child: 1, type: "Equity", description: "Operating Fund", balance: -40_060),
        Row(account: 3100, child: 1, type: "Equity", description: "Reserve Fund", balance: -312_400),
        Row(account: 4000, child: 1, type: "Revenue", description: "Condominium Fees",
            monthlyBudget: -42_000, variation: [0, 0, 0, 0, 350, 0, 0, 0, -420, 0, 0, 0]),
        Row(account: 4100, child: 1, type: "Revenue", description: "Interest Income",
            monthlyBudget: -650, variation: [-40, -55, -30, -60, -70, -45, -80, -65, -50, -75, -60, 0]),
        Row(account: 5000, child: 1, type: "Expense", description: "Insurance", monthlyBudget: 8_500),
        Row(account: 5100, child: 1, type: "Expense", description: "Utilities",
            monthlyBudget: 9_200, variation: [1_400, 1_100, 600, -300, -800, -1_200, -900, -700, -200, 400, 900, 0]),
        Row(account: 5200, child: 1, type: "Expense", description: "Repairs & Maintenance",
            monthlyBudget: 6_000, variation: [-1_200, 800, 2_300, -500, 3_100, -900, 400, -1_500, 1_800, 600, -300, 0]),
        Row(account: 5300, child: 1, type: "Expense", description: "Management Fees", monthlyBudget: 4_800),
        Row(account: 5400, child: 1, type: "Expense", description: "Reserve Fund Contribution", monthlyBudget: 12_000),
    ]

    private static var accountBalances: [[String: Any]] {
        // Actuals stop at last month so YTD and projections look realistic.
        let elapsed = max(Calendar.current.component(.month, from: Date()) - 1, 1)
        return rows.map { row in
            let isIncomeStatement = row.type == "Revenue" || row.type == "Expense"
            let actuals = (0..<12).map { i -> Double in
                guard isIncomeStatement, i < elapsed else { return 0 }
                return row.monthlyBudget + (i < row.variation.count ? row.variation[i] : 0)
            }
            var json: [String: Any] = [
                "id": "\(row.account)-\(row.child)",
                "account": row.account,
                "child": row.child,
                "parent_account": false,
                "acct_type": row.type,
                "description": row.description,
                "balance": isIncomeStatement ? actuals.reduce(0, +) : row.balance,
                "status": "Open",
                "opening_balance": 0,
            ]
            for m in 1...12 {
                json["period_\(m)"] = actuals[m - 1]
                json["budget_\(m)"] = isIncomeStatement ? row.monthlyBudget : 0
                json["previous_\(m)"] = isIncomeStatement ? row.monthlyBudget * 0.97 : 0
            }
            return json
        }
    }
}
