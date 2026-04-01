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
    let id: String
    let name: String
    let code: String?
    let type: String?
    let balance: Double?
    let currency: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, code, type, balance, currency
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Handle both Int and String IDs
        if let intId = try? c.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = try c.decode(String.self, forKey: .id)
        }
        name = try c.decode(String.self, forKey: .name)
        code = try? c.decode(String.self, forKey: .code)
        type = try? c.decode(String.self, forKey: .type)
        balance = try? c.decode(Double.self, forKey: .balance)
        currency = try? c.decode(String.self, forKey: .currency)
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

    func fetchAccountList() async throws -> [Account] {
        let data = try await request("/account_list")

        // Handle both a direct array and a wrapped {"accounts": [...]} response
        if let accounts = try? decoder.decode([Account].self, from: data) {
            return accounts
        }
        struct Wrapper: Decodable { let accounts: [Account] }
        if let wrapper = try? decoder.decode(Wrapper.self, from: data) {
            return wrapper.accounts
        }
        throw APIError.decodingFailed
    }
}
