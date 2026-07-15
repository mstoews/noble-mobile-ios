//
//  DashboardService.swift
//  nbledger
//
//  Swift client for the Go server's cash-position endpoint
//  (noble-go-server api/cash_position_history.go) — the data source for
//  the dashboard's "Total cash on hand" hero and fund-balance list.
//
//  All paths ride APIService.request, which already targets the
//  tenant-aware {host}/{slug}/v1 base — nothing tenant-specific lives here.
//

import Foundation

// MARK: - Models

/// One cash-account balance at an anchor date, per fund, as returned by
/// `GET read_cash_position_history`.
struct CashPositionRow: Codable {
    let asOf: String
    let account: Int
    let child: Int
    let childDesc: String
    let fund: String
    let balance: Double

    private enum CodingKeys: String, CodingKey {
        case asOf = "as_of"
        case account, child, fund, balance
        case childDesc = "child_desc"
    }
}

struct CashPositionResponse: Codable {
    let from: String
    let to: String
    let interval: String
    let anchors: [String]
    let rows: [CashPositionRow]
}

// MARK: - Fetch

extension APIService {
    /// Cash balances per cash account × fund at each anchor in the range.
    /// The server decides which accounts are cash accounts.
    func fetchCashPosition(from: String, to: String, interval: String = "monthly") async throws -> CashPositionResponse {
        let data = try await request("/read_cash_position_history?from=\(from)&to=\(to)&interval=\(interval)")
        do {
            return try decoder.decode(CashPositionResponse.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }
}
