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

struct InvoiceExtraction: Codable {
    var vendorName: String?
    var invoiceNumber: String?
    var amount: Double?
    var date: String?
    var dueDate: String?
    var description: String?
}

// MARK: - Config

enum AppConfig {
    static var anthropicAPIKey: String {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key = dict["AnthropicAPIKey"] as? String else {
            return ""
        }
        return key
    }
}

// MARK: - Service

@Observable
class APIService {
    var token: String
    var refreshToken: String

    private let baseURL = "https://api.nobleledger.com/public/api"
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

    func analyzeInvoice(imageData: Data) async throws -> InvoiceExtraction {
        let apiKey = AppConfig.anthropicAPIKey
        guard !apiKey.isEmpty else {
            throw APIError.serverError(statusCode: 0, message: "Anthropic API key not configured.")
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw APIError.serverError(statusCode: 0, message: "Invalid Anthropic API URL.")
        }

        let base64Image = imageData.base64EncodedString()

        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": """
                            Analyze this invoice image and extract the following fields. \
                            Return ONLY a JSON object with these keys: \
                            vendor_name, invoice_number, amount (as a number), \
                            date (YYYY-MM-DD), due_date (YYYY-MM-DD), description. \
                            If a field cannot be determined, use null.
                            """
                        ]
                    ]
                ]
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.serverError(statusCode: 0, message: "Failed to analyze invoice.")
        }

        // Parse the Claude response to extract the JSON content
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let textBlock = content.first(where: { $0["type"] as? String == "text" }),
              let text = textBlock["text"] as? String else {
            throw APIError.decodingFailed
        }

        // Extract JSON from the response text (may be wrapped in ```json ... ```)
        let jsonText = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let extractedData = jsonText.data(using: .utf8),
              let extracted = try? JSONSerialization.jsonObject(with: extractedData) as? [String: Any] else {
            throw APIError.decodingFailed
        }

        return InvoiceExtraction(
            vendorName: extracted["vendor_name"] as? String,
            invoiceNumber: extracted["invoice_number"] as? String,
            amount: extracted["amount"] as? Double,
            date: extracted["date"] as? String,
            dueDate: extracted["due_date"] as? String,
            description: extracted["description"] as? String
        )
    }
}
