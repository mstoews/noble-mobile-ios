//
//  BudgetEditorService.swift
//  nbledger
//
//  Write side of the budget feature — the counterpart to noble-web's
//  BudgetUpdate ("Maintenance") tab. Reads the per-fund budget grid from
//  `/read_budget_accounts?fund=` and writes each edited account back through
//  `/set_budget_amts` (one call per row, matching budget.store's forkJoin).
//  Also ports budget-generator.ts (generate-from-prior-year + spread).
//
//  Sign convention: the server stores budgets credit-natured (revenue negative).
//  The editor works in display space (everything positive) via a per-account
//  sign factor, then flips back to raw on save — the same flip BudgetService
//  applies for the read-only screens.
//

import Foundation

// MARK: - Models

/// One account's 12 monthly budgets for a fund, as returned by
/// `GET /read_budget_accounts?fund=` (raw / credit-natured values).
struct BudgetAccount: Identifiable, Codable {
    let child: Int
    let account: Int
    let acctType: String
    let description: String
    let monthly: [Double]   // 12 raw values, Jan…Dec

    var id: Int { child }

    var isRevenue: Bool {
        let t = acctType.lowercased()
        return t == "revenue" || t == "income"
    }
    var isExpense: Bool { acctType.lowercased() == "expense" }

    private enum CodingKeys: String, CodingKey {
        case child, account, description
        case acctType = "acct_type"
        case b1 = "budget_1", b2 = "budget_2", b3 = "budget_3", b4 = "budget_4"
        case b5 = "budget_5", b6 = "budget_6", b7 = "budget_7", b8 = "budget_8"
        case b9 = "budget_9", b10 = "budget_10", b11 = "budget_11", b12 = "budget_12"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        child = try c.decode(Int.self, forKey: .child)
        account = try c.decode(Int.self, forKey: .account)
        acctType = (try? c.decode(String.self, forKey: .acctType)) ?? ""
        description = (try? c.decode(String.self, forKey: .description)) ?? "Account \(child)"
        // pgtype.Numeric may arrive as a JSON number or string — decode flexibly.
        let keys: [CodingKeys] = [.b1, .b2, .b3, .b4, .b5, .b6, .b7, .b8, .b9, .b10, .b11, .b12]
        monthly = try keys.map { try c.decodeFlexibleDouble(forKey: $0) ?? 0 }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(child, forKey: .child)
        try c.encode(account, forKey: .account)
        try c.encode(acctType, forKey: .acctType)
        try c.encode(description, forKey: .description)
        let keys: [CodingKeys] = [.b1, .b2, .b3, .b4, .b5, .b6, .b7, .b8, .b9, .b10, .b11, .b12]
        for (i, key) in keys.enumerated() { try c.encode(monthly[i], forKey: key) }
    }
}

/// `POST /set_budget_amts` body — overwrites the 12 monthly BUDGET rows for one
/// (account, child, fund). Year is derived server-side.
struct SetBudgetAmtsRequest: Encodable {
    let account: Int
    let child: Int
    let fund: String
    let monthly: [Double]   // 12 raw values

    private enum CodingKeys: String, CodingKey {
        case account, child, fund
        case b1 = "budget_1", b2 = "budget_2", b3 = "budget_3", b4 = "budget_4"
        case b5 = "budget_5", b6 = "budget_6", b7 = "budget_7", b8 = "budget_8"
        case b9 = "budget_9", b10 = "budget_10", b11 = "budget_11", b12 = "budget_12"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(account, forKey: .account)
        try c.encode(child, forKey: .child)
        try c.encode(fund, forKey: .fund)
        let keys: [CodingKeys] = [.b1, .b2, .b3, .b4, .b5, .b6, .b7, .b8, .b9, .b10, .b11, .b12]
        for (i, key) in keys.enumerated() { try c.encode(monthly[i], forKey: key) }
    }
}

// MARK: - Editable working row

enum SpreadMode: String, CaseIterable, Identifiable {
    case seasonal = "Seasonal"
    case even = "Even"
    var id: String { rawValue }
}

/// Mutable editor row in DISPLAY space (revenue flipped positive). Tracks its
/// original to compute dirtiness.
struct EditableBudgetRow: Identifiable {
    let child: Int
    let account: Int
    let acctType: String
    let description: String
    let isRevenue: Bool
    var months: [Double]          // 12, display space (positive)
    let original: [Double]        // 12, display space

    var id: Int { child }
    var annual: Double { months.reduce(0, +) }
    var isDirty: Bool { zip(months, original).contains { abs($0 - $1) > 0.005 } }

    /// -1 for revenue (credit-natured), 1 otherwise.
    var sign: Double { isRevenue ? -1 : 1 }

    init(_ acct: BudgetAccount) {
        child = acct.child
        account = acct.account
        acctType = acct.acctType
        description = acct.description
        isRevenue = acct.isRevenue
        let sign: Double = acct.isRevenue ? -1 : 1
        let display = acct.monthly.map { v -> Double in let r = v * sign; return r == 0 ? 0 : r }
        months = display
        original = display
    }

    /// Raw (credit-natured) months for the save payload.
    var rawMonths: [Double] {
        months.map { v -> Double in let r = v * sign; return r == 0 ? 0 : r }
    }
}

// MARK: - Budget math (ported from budget-generator.ts)

enum BudgetMath {
    /// Monthly seasonality weights (budget-generator.ts SEASONAL_CURVE).
    static let seasonalCurve: [Double] =
        [0.95, 0.88, 1.02, 1.05, 1.10, 0.98, 0.85, 0.90, 1.05, 1.12, 1.08, 1.02]

    /// Blend grown prior-year actuals with the existing budget. All arrays 12-long,
    /// same sign space. weight = 1 → pure grown actuals; weight = 0 → existing budget.
    static func generate(priorActual: [Double], existingBudget: [Double],
                         growthPct: Double, weight: Double) -> [Double] {
        let growth = 1 + growthPct / 100
        return (0..<12).map { i in
            let prev = (i < priorActual.count ? priorActual[i] : 0) * growth
            let existing = i < existingBudget.count ? existingBudget[i] : 0
            let blended = prev * weight + existing * (1 - weight)
            return (blended * 100).rounded() / 100
        }
    }

    /// Distribute an annual figure across 12 months by the chosen curve. Month 12
    /// absorbs the rounding remainder so the months sum to `annual` exactly.
    static func spread(annual: Double, mode: SpreadMode) -> [Double] {
        let weights = mode == .even ? Array(repeating: 1.0, count: 12) : seasonalCurve
        let total = weights.reduce(0, +)
        guard total != 0 else { return Array(repeating: 0, count: 12) }
        var result: [Double] = []
        var running = 0.0
        for i in 0..<11 {
            let v = (annual * weights[i] / total * 100).rounded() / 100
            result.append(v)
            running += v
        }
        result.append(((annual - running) * 100).rounded() / 100)
        return result
    }
}

// MARK: - Endpoints

extension APIService {
    /// The per-fund budget grid (budget_1..12 pivoted from gl_account_amts).
    func fetchBudgetAccounts(fund: String) async throws -> [BudgetAccount] {
        let encoded = fund.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fund
        let data = try await request("/read_budget_accounts?fund=\(encoded)")
        do {
            return try decoder.decode([BudgetAccount].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    /// Overwrites one account's 12 monthly budgets for a fund. Year is server-derived.
    func setBudgetAmts(_ req: SetBudgetAmtsRequest) async throws {
        let body = try JSONEncoder().encode(req)
        _ = try await request("/set_budget_amts", method: "POST", body: body)
    }
}
