//
//  APIService.swift
//  nbledger
//
//  Created by Murray Toews on 3/31/26.
//

import Foundation

// MARK: - Errors

enum APIError: LocalizedError {
    case unauthorized
    case serverError(statusCode: Int, message: String)
    case decodingFailed
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Session expired. Please log in again."
        case .serverError(_, let message):
            return message
        case .decodingFailed:
            return "Failed to read server response."
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Models

struct Account: Identifiable, Codable {
    let id: Int
    let account: Int
    let child: Int
    let parentAccount: Bool?
    let acctType: String?
    let subType: String?
    let description: String?
    let balance: Double?
    let comments: String?
    let status: String?
    let createDate: String?
    let createUser: String?
    let updateDate: String?
    let updateUser: String?
    let period1: Double?
    let period2: Double?
    let period3: Double?
    let period4: Double?
    let period5: Double?
    let period6: Double?
    let period7: Double?
    let period8: Double?
    let period9: Double?
    let period10: Double?
    let period11: Double?
    let period12: Double?
    let previous1: Double?
    let previous2: Double?
    let previous3: Double?
    let previous4: Double?
    let previous5: Double?
    let previous6: Double?
    let previous7: Double?
    let previous8: Double?
    let previous9: Double?
    let previous10: Double?
    let previous11: Double?
    let previous12: Double?
    let budget1: Double?
    let budget2: Double?
    let budget3: Double?
    let budget4: Double?
    let budget5: Double?
    let budget6: Double?
    let budget7: Double?
    let budget8: Double?
    let budget9: Double?
    let budget10: Double?
    let budget11: Double?
    let budget12: Double?
    let openingBalance: Double?

    /// Display name derived from account number and description
    var displayName: String {
        description ?? "Account \(account)"
    }

    /// Account number as a string for display
    var accountCode: String {
        String(account)
    }

    /// Identifiable conformance using the integer id
    var stringId: String {
        String(id)
    }

    private enum CodingKeys: String, CodingKey {
        case id, account, child
        case parentAccount = "parent_account"
        case acctType = "acct_type"
        case subType = "sub_type"
        case description, balance, comments, status
        case createDate = "create_date"
        case createUser = "create_user"
        case updateDate = "update_date"
        case updateUser = "update_user"
        case period1 = "period_1"
        case period2 = "period_2"
        case period3 = "period_3"
        case period4 = "period_4"
        case period5 = "period_5"
        case period6 = "period_6"
        case period7 = "period_7"
        case period8 = "period_8"
        case period9 = "period_9"
        case period10 = "period_10"
        case period11 = "period_11"
        case period12 = "period_12"
        case previous1 = "previous_1"
        case previous2 = "previous_2"
        case previous3 = "previous_3"
        case previous4 = "previous_4"
        case previous5 = "previous_5"
        case previous6 = "previous_6"
        case previous7 = "previous_7"
        case previous8 = "previous_8"
        case previous9 = "previous_9"
        case previous10 = "previous_10"
        case previous11 = "previous_11"
        case previous12 = "previous_12"
        case budget1 = "budget_1"
        case budget2 = "budget_2"
        case budget3 = "budget_3"
        case budget4 = "budget_4"
        case budget5 = "budget_5"
        case budget6 = "budget_6"
        case budget7 = "budget_7"
        case budget8 = "budget_8"
        case budget9 = "budget_9"
        case budget10 = "budget_10"
        case budget11 = "budget_11"
        case budget12 = "budget_12"
        case openingBalance = "opening_balance"
    }
}

struct JournalHeader: Identifiable, Codable {
    let journalId: Int
    let description: String
    let booked: Bool?
    let bookedDate: String?
    let bookedUser: String?
    let createDate: String?
    let createUser: String?
    let period: Int?
    let periodYear: Int?
    let transactionDate: String?
    let status: String?
    let type: String?
    let amount: Double?
    let subType: String?
    let partyId: String?
    let templateRef: Int?
    let invoiceNo: String?
    let dueDate: String?

    var id: Int { journalId }

    private enum CodingKeys: String, CodingKey {
        case journalId = "journal_id"
        case description, booked
        case bookedDate = "booked_date"
        case bookedUser = "booked_user"
        case createDate = "create_date"
        case createUser = "create_user"
        case period
        case periodYear = "period_year"
        case transactionDate = "transaction_date"
        case status, type, amount
        case subType = "sub_type"
        case partyId = "party_id"
        case templateRef = "template_ref"
        case invoiceNo = "invoice_no"
        case dueDate = "due_date"
    }
}

struct Vendor: Identifiable, Codable {
    let partyId: String
    let name: String?
    let partyType: String?
    let addressId: Int?
    let createDate: String?
    let createUser: String?
    let updateDate: String?
    let updateUser: String?

    var id: String { partyId }

    var displayName: String {
        name ?? partyId
    }

    private enum CodingKeys: String, CodingKey {
        case partyId = "party_id"
        case name
        case partyType = "party_type"
        case addressId = "address_id"
        case createDate = "create_date"
        case createUser = "create_user"
        case updateDate = "update_date"
        case updateUser = "update_user"
    }
}

struct CreatePaymentRequest: Codable {
    var status: String?
    var vendorId: String?
    var invoiceId: String?
    var description: String?
    var amount: Double?
    var transactionDate: String?
    var dueDate: String?
    var orderNo: String?
    var reference: String?
    var createDate: String?
    var createUser: String?

    private enum CodingKeys: String, CodingKey {
        case status
        case vendorId = "vendor_id"
        case invoiceId = "invoice_id"
        case description, amount
        case transactionDate = "transaction_date"
        case dueDate = "due_date"
        case orderNo = "order_no"
        case reference
        case createDate = "create_date"
        case createUser = "create_user"
    }
}

struct Payment: Identifiable, Codable {
    let transactionId: String
    let status: String?
    let vendorId: String?
    let invoiceId: String?
    let description: String?
    let amount: Double?
    let amountPaid: Double?
    let transactionDate: String?
    let dueDate: String?
    let datePaid: String?
    let orderNo: String?
    let paymentReference: String?
    let reference: String?
    let gstAmount: Double?
    let pstAmount: Double?
    let createDate: String?
    let createUser: String?

    var id: String { transactionId }

    private enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case status
        case vendorId = "vendor_id"
        case invoiceId = "invoice_id"
        case description, amount
        case amountPaid = "amount_paid"
        case transactionDate = "transaction_date"
        case dueDate = "due_date"
        case datePaid = "date_paid"
        case orderNo = "order_no"
        case paymentReference = "payment_reference"
        case reference
        case gstAmount = "gst_amount"
        case pstAmount = "pst_amount"
        case createDate = "create_date"
        case createUser = "create_user"
    }
}

// MARK: - Bank Models (Plaid)

struct LinkTokenResponse: Codable {
    let linkToken: String

    private enum CodingKeys: String, CodingKey {
        case linkToken = "link_token"
    }
}

struct ExchangeTokenRequest: Codable {
    let publicToken: String

    private enum CodingKeys: String, CodingKey {
        case publicToken = "public_token"
    }
}

struct BankAccount: Identifiable, Codable {
    let accountId: String
    let name: String?
    let officialName: String?
    let type: String?
    let subtype: String?
    let mask: String?
    let currentBalance: Double?
    let availableBalance: Double?
    let isoCurrencyCode: String?
    let institutionName: String?

    var id: String { accountId }

    var displayName: String {
        officialName ?? name ?? "Account ••\(mask ?? "")"
    }

    private enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case name
        case officialName = "official_name"
        case type, subtype, mask
        case currentBalance = "current_balance"
        case availableBalance = "available_balance"
        case isoCurrencyCode = "iso_currency_code"
        case institutionName = "institution_name"
    }
}

struct BankTransaction: Identifiable, Codable {
    let transactionId: String
    let accountId: String?
    let name: String?
    let merchantName: String?
    let amount: Double?
    let date: String?
    let category: [String]?
    let pending: Bool?
    let isoCurrencyCode: String?

    var id: String { transactionId }

    var displayName: String {
        merchantName ?? name ?? "Transaction"
    }

    var primaryCategory: String? {
        category?.first
    }

    private enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case accountId = "account_id"
        case name
        case merchantName = "merchant_name"
        case amount, date, category, pending
        case isoCurrencyCode = "iso_currency_code"
    }
}

struct InvoiceExtraction: Codable {
    var vendorName: String?
    var invoiceNumber: String?
    var amount: Double?
    var date: String?
    var dueDate: String?
    var description: String?

    private enum CodingKeys: String, CodingKey {
        case vendorName = "vendor_name"
        case invoiceNumber = "invoice_number"
        case amount, date
        case dueDate = "due_date"
        case description
    }
}


// MARK: - Service

@Observable
class APIService {
    var token: String
    var refreshToken: String

    private let baseURL = "https://api.nobleledger.com/public/v1"
    private let decoder = JSONDecoder()

    init() {
        self.token = UserDefaults.standard.string(forKey: "authToken") ?? ""
        self.refreshToken = UserDefaults.standard.string(forKey: "refreshToken") ?? ""
    }

    // MARK: - Private request helper

    private func request(_ path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.serverError(statusCode: 0, message: "Invalid URL.")
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        if !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: req)

            guard let http = response as? HTTPURLResponse else {
                throw APIError.serverError(statusCode: 0, message: "Invalid server response.")
            }

            if http.statusCode == 401 {
                // Attempt token refresh, then retry once
                try await performTokenRefresh()
                return try await retryRequest(path, method: method, body: body)
            }

            guard (200..<300).contains(http.statusCode) else {
                let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                    .flatMap { $0["message"] as? String ?? $0["error"] as? String }
                    ?? "Server error (\(http.statusCode))."
                throw APIError.serverError(statusCode: http.statusCode, message: message)
            }

            return data
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func retryRequest(_ path: String, method: String, body: Data?) async throws -> Data {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.serverError(statusCode: 0, message: "Invalid URL.")
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.serverError(statusCode: 0, message: "Invalid server response.")
        }
        guard http.statusCode != 401 else {
            throw APIError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["message"] as? String ?? $0["error"] as? String }
                ?? "Server error (\(http.statusCode))."
            throw APIError.serverError(statusCode: http.statusCode, message: message)
        }
        return data
    }

    private func performTokenRefresh() async throws {
        guard !refreshToken.isEmpty else { throw APIError.unauthorized }

        guard let url = URL(string: "https://api.nobleledger.com/api/token/refresh") else {
            throw APIError.unauthorized
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["refreshToken": refreshToken])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.unauthorized
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newToken = json["idToken"] as? String else {
            throw APIError.unauthorized
        }

        token = newToken
        UserDefaults.standard.set(newToken, forKey: "authToken")

        if let newRefresh = json["refreshToken"] as? String {
            refreshToken = newRefresh
            UserDefaults.standard.set(newRefresh, forKey: "refreshToken")
        }
    }

    // MARK: - Endpoints

    func fetchJournalHeaders() async throws -> [JournalHeader] {
        let data = try await request("/read_journal_header")
        do {
            return try decoder.decode([JournalHeader].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchAccountList() async throws -> [Account] {
        let data = try await request("/account_list")
        do {
            return try decoder.decode([Account].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchPayments() async throws -> [Payment] {
        let data = try await request("/read_payments")
        do {
            return try decoder.decode([Payment].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchVendors() async throws -> [Vendor] {
        let data = try await request("/read_vendors")
        do {
            return try decoder.decode([Vendor].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func createPayment(_ params: CreatePaymentRequest) async throws {
        let body = try JSONEncoder().encode(params)
        _ = try await request("/create_payment", method: "POST", body: body)
    }

    // MARK: - Plaid / Banking

    func createLinkToken() async throws -> String {
        let data = try await request("/create_link_token", method: "POST")
        do {
            let response = try decoder.decode(LinkTokenResponse.self, from: data)
            return response.linkToken
        } catch {
            throw APIError.decodingFailed
        }
    }

    func exchangePublicToken(_ publicToken: String) async throws {
        let body = try JSONEncoder().encode(ExchangeTokenRequest(publicToken: publicToken))
        _ = try await request("/exchange_public_token", method: "POST", body: body)
    }

    func fetchBankAccounts() async throws -> [BankAccount] {
        let data = try await request("/bank_accounts")
        do {
            return try decoder.decode([BankAccount].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchBankTransactions() async throws -> [BankTransaction] {
        let data = try await request("/bank_transactions")
        do {
            return try decoder.decode([BankTransaction].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func analyzeInvoice(imageData: Data) async throws -> InvoiceExtraction {
        let base64Image = imageData.base64EncodedString()
        let body = try JSONSerialization.data(withJSONObject: [
            "image": base64Image,
            "media_type": "image/jpeg"
        ])
        let data = try await request("/analyze_invoice", method: "POST", body: body)
        do {
            return try decoder.decode(InvoiceExtraction.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }
}
