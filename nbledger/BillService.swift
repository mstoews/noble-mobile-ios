//
//  BillService.swift
//  nbledger
//
//  Swift client for the Go server's AP bill flow (noble-go-server
//  api/create_bill.go + api/bill_attachments.go) and the v1 reference
//  data the bill form needs (ap_vendors, funds, gl_accounts).
//
//  Captured invoices are saved with POST create_bill (booked:false from
//  mobile) which writes the AP bill + a balanced journal entry atomically
//  and returns header.journal_id — the id used to attach the captured
//  document via POST attach_bill_asset. See
//  .claude/plans/document-capture/CONTRACT.md §2 and §4 (Desktop repo).
//
//  All paths ride APIService.request, which already targets the
//  tenant-aware {host}/{slug}/v1 base — nothing tenant-specific lives here.
//

import Foundation

// MARK: - Reference data models (v1 routes)

/// A row of `ap_vendors` as returned by `GET list_ap_vendors`.
/// `id` is the uuid `vendor_id` that `create_bill` requires.
struct APVendor: Identifiable, Codable {
    let id: String
    let name: String?
    let shortName: String?
    /// Vendor's default expense account/child — a prefill hint only.
    let account: Int?
    let child: Int?
    let apAccount: Int?
    let apChild: Int?
    let description: String?
    let type: String?
    let status: String?
    let vendorTerms: Int?

    var displayName: String {
        name ?? shortName ?? id
    }

    private enum CodingKeys: String, CodingKey {
        case id, name
        case shortName = "short_name"
        case account, child
        case apAccount = "ap_account"
        case apChild = "ap_child"
        case description, type, status
        case vendorTerms = "vendor_terms"
    }
}

/// A row of `gl_funds` as returned by `GET funds_list`.
struct FundRef: Identifiable, Codable {
    let id: String
    let fund: String
    let description: String?
    let restriction: String?

    var displayName: String {
        if let description, !description.isEmpty {
            return "\(fund) — \(description)"
        }
        return fund
    }
}

/// A row of `gl_accounts` as returned by the v1 `GET account_list`.
/// (The legacy `Account` model keys `id` as Int and cannot decode the
/// v1 payload, whose `id` is a uuid string.)
struct GLAccountRef: Identifiable, Codable {
    let id: String
    let account: Int
    let child: Int
    let parentAccount: Bool?
    let acctType: String?
    let description: String?
    let status: String?

    var displayName: String {
        description ?? "Account \(account)/\(child)"
    }

    var codeLabel: String {
        "\(account) / \(child)"
    }

    private enum CodingKeys: String, CodingKey {
        case id, account, child
        case parentAccount = "parent_account"
        case acctType = "acct_type"
        case description, status
    }
}

// MARK: - create_bill request/response (CONTRACT.md §4)

struct CreateBillExpenseLine: Encodable {
    let fund: String
    let account: Int
    let child: Int
    /// Money as a STRING — the server parses and requires > 0.
    let amount: String
    let description: String

    private enum CodingKeys: String, CodingKey {
        case fund, account, child, amount, description
    }
}

struct CreateBillRequest: Encodable {
    /// uuid of an `ap_vendors` row (`APVendor.id`).
    let vendorId: String
    let invoiceNo: String
    /// RFC3339 timestamps, e.g. "2026-06-28T00:00:00Z".
    let transactionDate: String
    let dueDate: String
    let description: String
    let expenseLines: [CreateBillExpenseLine]
    /// Always false from mobile — booked:true requires ADMIN/ACCT.
    let booked: Bool

    private enum CodingKeys: String, CodingKey {
        case vendorId = "vendor_id"
        case invoiceNo = "invoice_no"
        case transactionDate = "transaction_date"
        case dueDate = "due_date"
        case description
        case expenseLines = "expense_lines"
        case booked
    }
}

/// `header` of the create_bill 201 response. `journalId` is the id to
/// pass to `attachBillAsset`.
struct CreateBillHeader: Codable {
    let journalId: Int
    let transactionDate: String?
    let dueDate: String?
    let description: String?
    let invoiceNo: String?
    let partyId: String?
    let amount: Double?
    let period: Int?
    let periodYear: Int?
    let status: String?
    let booked: Bool?

    private enum CodingKeys: String, CodingKey {
        case journalId = "journal_id"
        case transactionDate = "transaction_date"
        case dueDate = "due_date"
        case description
        case invoiceNo = "invoice_no"
        case partyId = "party_id"
        case amount, period
        case periodYear = "period_year"
        case status, booked
    }
}

struct CreateBillResponse: Decodable {
    let header: CreateBillHeader
}

/// Response of `POST attach_bill_asset` (CONTRACT.md §2.1).
struct BillAssetLink: Codable {
    let journalId: Int
    let assetId: String

    private enum CodingKeys: String, CodingKey {
        case journalId = "journal_id"
        case assetId = "asset_id"
    }
}

// MARK: - Endpoints

extension APIService {

    /// AP vendors (uuid `id` = `vendor_id` for create_bill).
    func fetchAPVendors() async throws -> [APVendor] {
        let data = try await request("/list_ap_vendors")
        do {
            return try decoder.decode([APVendor].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    /// Funds for the expense-line fund picker.
    func fetchFunds() async throws -> [FundRef] {
        let data = try await request("/funds_list")
        do {
            return try decoder.decode([FundRef].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    /// Chart of accounts for the expense-account picker (v1 shape).
    func fetchGLAccounts() async throws -> [GLAccountRef] {
        let data = try await request("/account_list")
        do {
            return try decoder.decode([GLAccountRef].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    /// Saves an AP bill + balanced journal entry (CONTRACT.md §4).
    /// Returns 201 with `header.journal_id` — the id documents attach to.
    func createBill(_ params: CreateBillRequest) async throws -> CreateBillResponse {
        let body = try JSONEncoder().encode(params)
        let data = try await request("/create_bill", method: "POST", body: body)
        do {
            return try decoder.decode(CreateBillResponse.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    /// Links a confirmed asset to a journal entry (CONTRACT.md §2.1).
    /// Only pass journal ids returned by the server — a nonexistent
    /// journal_id surfaces as a raw 500 (FK violation, no pre-check).
    /// Attach only after a successful asset confirm.
    @discardableResult
    func attachBillAsset(journalId: Int, assetId: String) async throws -> BillAssetLink {
        struct AttachRequest: Encodable {
            let journalId: Int
            let assetId: String

            private enum CodingKeys: String, CodingKey {
                case journalId = "journal_id"
                case assetId = "asset_id"
            }
        }

        let body = try JSONEncoder().encode(AttachRequest(journalId: journalId, assetId: assetId))
        let data = try await request("/attach_bill_asset", method: "POST", body: body)
        do {
            return try decoder.decode(BillAssetLink.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    /// Assets attached to a journal entry, newest attachment first
    /// (CONTRACT.md §2.2).
    func listBillAssets(journalId: Int) async throws -> [AssetRecord] {
        let data = try await request("/list_bill_assets/\(journalId)")
        do {
            return try decoder.decode([AssetRecord].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }
}
