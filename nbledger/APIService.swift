//
//  APIService.swift
//  nbledger
//
//  Created by Murray Toews on 3/31/26.
//

import Foundation

// MARK: - Decoding Helpers

/// Decodes a Double that may arrive as a JSON number or a JSON string (Go pgtype.Numeric).
extension KeyedDecodingContainer {
    func decodeFlexibleDouble(forKey key: Key) throws -> Double? {
        if let d = try? decode(Double.self, forKey: key) {
            return d
        }
        if let s = try? decode(String.self, forKey: key), let d = Double(s) {
            return d
        }
        return nil
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case unauthorized
    case serverError(statusCode: Int, message: String)
    case decodingFailed
    case networkError(Error)
    /// An optimistic-concurrency rejection: the row changed since the read
    /// that produced the edit. `currentUpdatedAt` is the row's present token,
    /// which the server returns so a client can re-read and retry.
    ///
    /// Distinct from `.serverError(409, …)` because the wire body carries only
    /// `"error": "stale"`, and showing the user the word "stale" tells them
    /// nothing about what to do. It is also NOT every 409: a lifecycle
    /// conflict from book_journal_entry stays a serverError with its own
    /// message.
    case conflict(currentUpdatedAt: String?)

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
        case .conflict:
            return "Someone else changed this record while you were editing. Reload to see the current values, then reapply your change."
        }
    }
}

// MARK: - Models

struct Account: Identifiable, Codable {
    let id: String
    let account: Int
    let child: Int
    let parentAccount: Bool?
    let acctType: String?
    // No sub_type: gl_accounts has no such column (gl_sub_type is a standalone
    // lookup with no link to an account), so /account_balances never sends one.
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

    private enum CodingKeys: String, CodingKey {
        case id, account, child
        case parentAccount = "parent_account"
        case acctType = "acct_type"
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
    // Only present on /read_journal_header responses.
    let evidenceCount: Int?

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
        case evidenceCount = "evidence_count"
    }
}

// MARK: - GL Journal Detail Models

struct JournalDetail: Identifiable, Codable {
    let journalId: Int?
    let journalSubid: Int?
    let account: Int?
    let child: Int?
    let childDesc: String?
    let subType: String?
    let description: String?
    let debit: Double?
    let credit: Double?
    let createDate: String?
    let createUser: String?
    let fund: String?
    let reference: String?
    let metaData: String?

    var id: String { "\(journalId ?? 0)-\(journalSubid ?? 0)" }

    private enum CodingKeys: String, CodingKey {
        case journalId = "journal_id"
        case journalSubid = "journal_subid"
        case account, child
        case childDesc = "child_desc"
        case subType = "sub_type"
        case description, debit, credit
        case createDate = "create_date"
        case createUser = "create_user"
        case fund, reference
        case metaData = "meta_data"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        journalId = try? c.decode(Int.self, forKey: .journalId)
        journalSubid = try? c.decode(Int.self, forKey: .journalSubid)
        account = try? c.decode(Int.self, forKey: .account)
        child = try? c.decode(Int.self, forKey: .child)
        childDesc = try? c.decode(String.self, forKey: .childDesc)
        subType = try? c.decode(String.self, forKey: .subType)
        description = try? c.decode(String.self, forKey: .description)
        debit = try c.decodeFlexibleDouble(forKey: .debit)
        credit = try c.decodeFlexibleDouble(forKey: .credit)
        createDate = try? c.decode(String.self, forKey: .createDate)
        createUser = try? c.decode(String.self, forKey: .createUser)
        fund = try? c.decode(String.self, forKey: .fund)
        reference = try? c.decode(String.self, forKey: .reference)
        metaData = try? c.decode(String.self, forKey: .metaData)
    }
}

struct JournalEntry: Identifiable, Codable {
    let journalId: Int?
    let description: String?
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
    let templateName: String?
    let templateRef: Int?
    let invoiceNo: String?
    let dueDate: String?
    let details: [JournalDetail]?

    var id: Int { journalId ?? 0 }

    var displayDescription: String {
        description ?? "Journal \(journalId ?? 0)"
    }

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
        case templateName = "template_name"
        case templateRef = "template_ref"
        case invoiceNo = "invoice_no"
        case dueDate = "due_date"
        case details
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        journalId = try? c.decode(Int.self, forKey: .journalId)
        description = try? c.decode(String.self, forKey: .description)
        booked = try? c.decode(Bool.self, forKey: .booked)
        bookedDate = try? c.decode(String.self, forKey: .bookedDate)
        bookedUser = try? c.decode(String.self, forKey: .bookedUser)
        createDate = try? c.decode(String.self, forKey: .createDate)
        createUser = try? c.decode(String.self, forKey: .createUser)
        period = try? c.decode(Int.self, forKey: .period)
        periodYear = try? c.decode(Int.self, forKey: .periodYear)
        transactionDate = try? c.decode(String.self, forKey: .transactionDate)
        status = try? c.decode(String.self, forKey: .status)
        type = try? c.decode(String.self, forKey: .type)
        amount = try c.decodeFlexibleDouble(forKey: .amount)
        subType = try? c.decode(String.self, forKey: .subType)
        partyId = try? c.decode(String.self, forKey: .partyId)
        templateName = try? c.decode(String.self, forKey: .templateName)
        templateRef = try? c.decode(Int.self, forKey: .templateRef)
        invoiceNo = try? c.decode(String.self, forKey: .invoiceNo)
        dueDate = try? c.decode(String.self, forKey: .dueDate)
        details = try? c.decode([JournalDetail].self, forKey: .details)
    }
}

struct GlEvidence: Identifiable, Codable {
    // gl_evidence.id is a Postgres uuid — decodes as a string.
    let id: String
    let journalId: Int?
    let reference: String?
    let description: String?
    let location: String?
    let userCreated: String?
    let dateCreated: String?
    let confirmed: Bool?

    private enum CodingKeys: String, CodingKey {
        case id
        case journalId = "journal_id"
        case reference, description, location
        case userCreated = "user_created"
        case dateCreated = "date_created"
        case confirmed
    }
}

struct JournalTemplate: Identifiable, Codable {
    let templateRef: Int
    let templateName: String?
    let description: String?
    let journalType: String?
    let createDate: String?
    let createUser: String?
    let details: [JournalTemplateDetail]?

    var id: Int { templateRef }

    var displayName: String {
        templateName ?? "Template \(templateRef)"
    }

    private enum CodingKeys: String, CodingKey {
        case templateRef = "template_ref"
        case templateName = "template_name"
        case description
        case journalType = "journal_type"
        case createDate = "create_date"
        case createUser = "create_user"
        case details
    }
}

struct JournalTemplateDetail: Identifiable, Codable {
    let templateRef: Int
    let journalSub: Int
    let description: String?
    let account: Int?
    let child: Int?
    let subType: String?
    let fund: String?
    let debit: Double?
    let credit: Double?

    var id: String { "\(templateRef)-\(journalSub)" }

    private enum CodingKeys: String, CodingKey {
        case templateRef = "template_ref"
        case journalSub = "journal_sub"
        case description, account, child
        case subType = "sub_type"
        case fund, debit, credit
    }
}

// MARK: - GL Journal Request Models

struct CreateJournalHeaderRequest: Codable {
    var description: String
    var transactionDate: String?
    var amount: Double?
    var type: String?
    var templateRef: Int?
    var partyId: String?
    var status: String?

    private enum CodingKeys: String, CodingKey {
        case description
        case transactionDate = "transaction_date"
        case amount, type
        case templateRef = "template_ref"
        case partyId = "party_id"
        case status
    }
}

struct CreateJournalDetailRequest: Codable {
    var journalId: Int
    var journalSubid: Int
    var account: Int?
    var child: Int?
    var subType: String?
    var description: String?
    var debit: Double?
    var credit: Double?
    var createDate: String?
    var createUser: String?
    var fund: String?
    var reference: String?
    var childDesc: String?
    var metaData: String?

    private enum CodingKeys: String, CodingKey {
        case journalId = "journal_id"
        case journalSubid = "journal_subid"
        case account, child
        case subType = "sub_type"
        case description, debit, credit
        case createDate = "create_date"
        case createUser = "create_user"
        case fund, reference
        case childDesc = "child_desc"
        case metaData = "meta_data"
    }
}

struct CreateFullJournalRequest: Codable {
    var journalId: Int?
    var description: String
    var bookedUser: String?
    var createUser: String?
    var period: Int?
    var periodYear: Int?
    var transactionDate: String?
    var type: String?
    var amount: Double?
    var subType: String?
    var partyId: String?
    var templateRef: Int?
    var invoiceNo: String?
    var dueDate: String?
    var details: [CreateJournalDetailRequest]?

    private enum CodingKeys: String, CodingKey {
        case journalId = "journal_id"
        case description
        case bookedUser = "booked_user"
        case createUser = "create_user"
        case period
        case periodYear = "period_year"
        case transactionDate = "transaction_date"
        case type, amount
        case subType = "sub_type"
        case partyId = "party_id"
        case templateRef = "template_ref"
        case invoiceNo = "invoice_no"
        case dueDate = "due_date"
        case details
    }
}

struct BookJournalRequest: Codable {
    var journalId: Int
    var userName: String
    var period: Int
    var year: Int

    private enum CodingKeys: String, CodingKey {
        case journalId = "journal_id"
        case userName = "user_name"
        case period, year
    }
}

struct CloseJournalRequest: Codable {
    var journalId: Int
    var bookedUser: String?

    private enum CodingKeys: String, CodingKey {
        case journalId = "journal_id"
        case bookedUser = "booked_user"
    }
}

struct JournalsByPeriodRequest: Codable {
    var period: Int
    var periodYear: Int

    private enum CodingKeys: String, CodingKey {
        case period
        case periodYear = "period_year"
    }
}

struct JournalsByDateRequest: Codable {
    var startDate: String
    var endDate: String

    private enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

struct TransactionsByAccountRequest: Codable {
    var child: Int
    var period: Int
    var periodYear: Int

    private enum CodingKeys: String, CodingKey {
        case child, period
        case periodYear = "period_year"
    }
}

struct DeleteJournalRequest: Codable {
    var journalId: Int

    private enum CodingKeys: String, CodingKey {
        case journalId = "journal_id"
    }
}

struct CloneJournalRequest: Codable {
    var journalId: Int
    var templateDescription: String

    private enum CodingKeys: String, CodingKey {
        case journalId = "journal_id"
        case templateDescription = "template_description"
    }
}

struct CreateEvidenceRequest: Codable {
    var journalId: Int?
    var reference: String?
    var description: String?
    var location: String?
    var userCreated: String?
    var dateCreated: String?
    var confirmed: Bool?

    private enum CodingKeys: String, CodingKey {
        case journalId = "journal_id"
        case reference, description, location
        case userCreated = "user_created"
        case dateCreated = "date_created"
        case confirmed
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

// MARK: - AP Vendor (Full)

struct ApVendor: Identifiable, Codable {
    let id: String
    let name: String
    let shortName: String?
    let address1: String?
    let address2: String?
    let address3: String?
    let postalCode: String?
    let phone: String?
    let fax: String?
    let account: Double?
    let child: Double?
    let vatAccount: Double?
    let vatChild: Double?
    let apAccount: Double?
    let apChild: Double?
    let description: String?
    let contact: String?
    let type: String?
    let status: String?
    let vendorTerms: Double?
    let createDate: String?
    let createUser: String?
    let updateDate: String?
    let updateUser: String?
    /// OCC token for `update_ap_vendor`. Distinct from `updateDate` (a date):
    /// this is the row's `updated_at` timestamp column.
    let updatedAt: String?

    var displayName: String { shortName ?? name }

    private enum CodingKeys: String, CodingKey {
        case id, name
        case updatedAt = "updated_at"
        case shortName = "short_name"
        case address1, address2, address3
        case postalCode = "postal_code"
        case phone, fax, account, child
        case vatAccount = "vat_account"
        case vatChild = "vat_child"
        case apAccount = "ap_account"
        case apChild = "ap_child"
        case description, contact, type, status
        case vendorTerms = "vendor_terms"
        case createDate = "create_date"
        case createUser = "create_user"
        case updateDate = "update_date"
        case updateUser = "update_user"
    }
}

struct CreateApVendorRequest: Codable {
    var name: String
    var shortName: String?
    var address1: String?
    var address2: String?
    var address3: String?
    var postalCode: String?
    var phone: String?
    var fax: String?
    var account: Double?
    var child: Double?
    var vatAccount: Double?
    var vatChild: Double?
    var apAccount: Double?
    var apChild: Double?
    var description: String?
    var contact: String?
    var type: String?
    var status: String?
    var vendorTerms: Double?
    var createDate: String?
    var createUser: String?

    private enum CodingKeys: String, CodingKey {
        case name
        case shortName = "short_name"
        case address1, address2, address3
        case postalCode = "postal_code"
        case phone, fax, account, child
        case vatAccount = "vat_account"
        case vatChild = "vat_child"
        case apAccount = "ap_account"
        case apChild = "ap_child"
        case description, contact, type, status
        case vendorTerms = "vendor_terms"
        case createDate = "create_date"
        case createUser = "create_user"
    }
}

struct UpdateApVendorRequest: Codable {
    var id: String
    var name: String
    var shortName: String?
    var address1: String?
    var address2: String?
    var address3: String?
    var postalCode: String?
    var phone: String?
    var fax: String?
    var account: Double?
    var child: Double?
    var vatAccount: Double?
    var vatChild: Double?
    var apAccount: Double?
    var apChild: Double?
    var description: String?
    var contact: String?
    var type: String?
    var status: String?
    var vendorTerms: Double?
    var updateDate: String?
    var updateUser: String?
    /// §22 OCC token: the row's `updated_at` from the read that produced this
    /// edit. Required — omitting it is a 400, and a mismatch is a 409.
    var expectedUpdatedAt: String

    private enum CodingKeys: String, CodingKey {
        case id, name
        case shortName = "short_name"
        case address1, address2, address3
        case postalCode = "postal_code"
        case phone, fax, account, child
        case vatAccount = "vat_account"
        case vatChild = "vat_child"
        case apAccount = "ap_account"
        case apChild = "ap_child"
        case description, contact, type, status
        case vendorTerms = "vendor_terms"
        case updateDate = "update_date"
        case updateUser = "update_user"
        case expectedUpdatedAt = "expected_updated_at"
    }
}

// MARK: - AR Customer

struct ArCustomer: Identifiable, Codable {
    let customerId: String
    let customerName: String
    let customerShortName: String?
    let customerAddress1: String?
    let customerAddress2: String?
    let customerAddress3: String?
    let customerPostalCode: String?
    let customerPhone: String?
    let customerFax: String?
    let customerAccount: Double?
    let customerChild: Double?
    let customerVatAccount: Double?
    let customerVatChild: Double?
    let customerApAccount: Double?
    let customerApChild: Double?
    let customerDescription: String?
    let customerContact: String?
    let customerType: String?
    let customerStatus: String?
    let customerTerms: Double?
    let createDate: String?
    let createUser: String?
    let updateDate: String?
    let updateUser: String?
    /// OCC token for `update_ar_customer` — the row's `updated_at` column.
    let updatedAt: String?

    var id: String { customerId }
    var displayName: String { customerShortName ?? customerName }

    private enum CodingKeys: String, CodingKey {
        case customerId = "customer_id"
        case customerName = "customer_name"
        case customerShortName = "customer_short_name"
        case customerAddress1 = "customer_address1"
        case customerAddress2 = "customer_address2"
        case customerAddress3 = "customer_address3"
        case customerPostalCode = "customer_postal_code"
        case customerPhone = "customer_phone"
        case customerFax = "customer_fax"
        case customerAccount = "customer_account"
        case customerChild = "customer_child"
        case customerVatAccount = "customer_vat_account"
        case customerVatChild = "customer_vat_child"
        case customerApAccount = "customer_ap_account"
        case customerApChild = "customer_ap_child"
        case customerDescription = "customer_description"
        case customerContact = "customer_contact"
        case customerType = "customer_type"
        case customerStatus = "customer_status"
        case customerTerms = "customer_terms"
        case createDate = "create_date"
        case createUser = "create_user"
        case updateDate = "update_date"
        case updateUser = "update_user"
        case updatedAt = "updated_at"
    }
}

struct CreateArCustomerRequest: Codable {
    var customerId: String
    var customerName: String
    var customerShortName: String?
    var customerAddress1: String?
    var customerAddress2: String?
    var customerAddress3: String?
    var customerPostalCode: String?
    var customerPhone: String?
    var customerFax: String?
    var customerAccount: Double?
    var customerChild: Double?
    var customerVatAccount: Double?
    var customerVatChild: Double?
    var customerApAccount: Double?
    var customerApChild: Double?
    var customerDescription: String?
    var customerContact: String?
    var customerType: String?
    var customerStatus: String?
    var customerTerms: Double?
    var createDate: String?
    var createUser: String?

    private enum CodingKeys: String, CodingKey {
        case customerId = "customer_id"
        case customerName = "customer_name"
        case customerShortName = "customer_short_name"
        case customerAddress1 = "customer_address1"
        case customerAddress2 = "customer_address2"
        case customerAddress3 = "customer_address3"
        case customerPostalCode = "customer_postal_code"
        case customerPhone = "customer_phone"
        case customerFax = "customer_fax"
        case customerAccount = "customer_account"
        case customerChild = "customer_child"
        case customerVatAccount = "customer_vat_account"
        case customerVatChild = "customer_vat_child"
        case customerApAccount = "customer_ap_account"
        case customerApChild = "customer_ap_child"
        case customerDescription = "customer_description"
        case customerContact = "customer_contact"
        case customerType = "customer_type"
        case customerStatus = "customer_status"
        case customerTerms = "customer_terms"
        case createDate = "create_date"
        case createUser = "create_user"
    }
}

struct UpdateArCustomerRequest: Codable {
    var customerId: String
    var customerName: String
    var customerShortName: String?
    var customerAddress1: String?
    var customerAddress2: String?
    var customerAddress3: String?
    var customerPostalCode: String?
    var customerPhone: String?
    var customerFax: String?
    var customerAccount: Double?
    var customerChild: Double?
    var customerVatAccount: Double?
    var customerVatChild: Double?
    var customerApAccount: Double?
    var customerApChild: Double?
    var customerDescription: String?
    var customerContact: String?
    var customerType: String?
    var customerStatus: String?
    var customerTerms: Double?
    var updateDate: String?
    var updateUser: String?
    /// §22 OCC token: the row's `updated_at` from the read that produced this
    /// edit. Required — omitting it is a 400, and a mismatch is a 409.
    var expectedUpdatedAt: String

    private enum CodingKeys: String, CodingKey {
        case customerId = "customer_id"
        case customerName = "customer_name"
        case customerShortName = "customer_short_name"
        case customerAddress1 = "customer_address1"
        case customerAddress2 = "customer_address2"
        case customerAddress3 = "customer_address3"
        case customerPostalCode = "customer_postal_code"
        case customerPhone = "customer_phone"
        case customerFax = "customer_fax"
        case customerAccount = "customer_account"
        case customerChild = "customer_child"
        case customerVatAccount = "customer_vat_account"
        case customerVatChild = "customer_vat_child"
        case customerApAccount = "customer_ap_account"
        case customerApChild = "customer_ap_child"
        case customerDescription = "customer_description"
        case customerContact = "customer_contact"
        case customerType = "customer_type"
        case customerStatus = "customer_status"
        case customerTerms = "customer_terms"
        case updateDate = "update_date"
        case updateUser = "update_user"
        case expectedUpdatedAt = "expected_updated_at"
    }
}








// MARK: - AR Models

struct ArTransaction: Identifiable, Codable {
    let id: String
    let customerId: String?
    let journalId: Double?
    let arCashChild: Double?
    let status: String?
    let arChild: Double?
    let transactionDate: String?
    let dueDate: String?
    let receiptNo: String?
    let reference: String?
    let description: String?
    let amount: Double?
    let amountReceived: Double?
    let datePaid: String?
    let adjustmentAmt: Double?
    let remainderAmt: Double?
    let receiptReq: Int?
    let createDate: String?
    let createUser: String?
    let updateDate: String?
    let updateUser: String?
    /// OCC token for the AR transaction writes — the row's `updated_at`.
    let updatedAt: String?

    var displayDescription: String {
        description ?? "AR Transaction"
    }

    var remainingBalance: Double {
        (amount ?? 0) - (amountReceived ?? 0)
    }

    private enum CodingKeys: String, CodingKey {
        case id, status, reference, description, amount
        case customerId = "customer_id"
        case journalId = "journal_id"
        case arCashChild = "ar_cash_child"
        case arChild = "ar_child"
        case transactionDate = "transaction_date"
        case dueDate = "due_date"
        case receiptNo = "receipt_no"
        case amountReceived = "amount_received"
        case datePaid = "date_paid"
        case adjustmentAmt = "adjustment_amt"
        case remainderAmt = "remainder_amt"
        case receiptReq = "receipt_req"
        case createDate = "create_date"
        case createUser = "create_user"
        case updateDate = "update_date"
        case updateUser = "update_user"
        case updatedAt = "updated_at"
    }
}

struct ArTransactionDetail: Identifiable, Codable {
    let transactionId: String
    let transactionItemId: Int
    let account: Int?
    let child: Int?
    let `class`: String?
    let description: String?
    let fund: String?
    let reference: String?
    let debit: Double?
    let credit: Double?
    let amountReceived: Double?
    let remainder: Double?
    let createDate: String?
    let createUser: String?

    var id: String { "\(transactionId)-\(transactionItemId)" }

    private enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case transactionItemId = "transaction_item_id"
        case account, child, `class`, description, fund, reference, debit, credit
        case amountReceived = "amount_received"
        case remainder
        case createDate = "create_date"
        case createUser = "create_user"
    }
}

struct CreateArTransactionRequest: Codable {
    var customerId: String?
    var status: String?
    var transactionDate: String?
    var dueDate: String?
    var receiptNo: String?
    var reference: String?
    var description: String?
    var amount: Double?
    var createDate: String?
    var createUser: String?

    private enum CodingKeys: String, CodingKey {
        case customerId = "customer_id"
        case status
        case transactionDate = "transaction_date"
        case dueDate = "due_date"
        case receiptNo = "receipt_no"
        case reference, description, amount
        case createDate = "create_date"
        case createUser = "create_user"
    }
}

struct UpdateArAmountReceivedRequest: Codable {
    var id: String
    var amountReceived: Double?
    var datePaid: String?
    var updateUser: String?
    /// §22 OCC token: the row's `updated_at` from the read that produced this
    /// edit. Required — omitting it is a 400, and a mismatch is a 409.
    var expectedUpdatedAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case amountReceived = "amount_received"
        case datePaid = "date_paid"
        case updateUser = "update_user"
        case expectedUpdatedAt = "expected_updated_at"
    }
}

struct UpdateArStatusRequest: Codable {
    var id: String
    var status: String?
    var updateUser: String?
    /// §22 OCC token: the row's `updated_at` from the read that produced this
    /// edit. Required — omitting it is a 400, and a mismatch is a 409.
    var expectedUpdatedAt: String

    private enum CodingKeys: String, CodingKey {
        case id, status
        case updateUser = "update_user"
        case expectedUpdatedAt = "expected_updated_at"
    }
}

// MARK: - Operating statement

/// One account/period cell of `comparison_trial_balance_by_fund`.
///
/// The server emits a dense 1..12 grid per leaf account, so an account with no
/// activity still has twelve rows. `opening` is carried onto every row;
/// `actual` and `budget` are that PERIOD's amounts, while `closing` is
/// cumulative (`opening + running sum of actual`). Every field is non-nullable
/// on the wire (`api/account_amts.go` builds plain float64/int32/string), so
/// there is nothing optional to guard here.
///
/// Amounts are in BOOK sign: debits positive. Expenses come back positive and
/// revenue negative — `OperatingStatementRow` flips revenue for display.
struct ComparisonTrialBalanceRow: Codable {
    let account: Int
    let child: Int
    let description: String
    let acctType: String
    let period: Int
    let opening: Double
    let actual: Double
    let budget: Double
    let closing: Double

    private enum CodingKeys: String, CodingKey {
        case account, child, description, period, opening, actual, budget, closing
        case acctType = "acct_type"
    }
}

/// Board-set target balance for one fund, from `fund_targets_list`.
///
/// Read straight off the sqlc row, so the nullable columns arrive as
/// `pgtype` JSON: `notes` and `updated_by` are string-or-null, `as_of_date`
/// is a bare `yyyy-MM-dd` and NOT RFC3339 — it must not go through
/// `parseTimestamp`. `target_balance` is `pgtype.Numeric`, which pgx
/// renders as an unquoted decimal today; `decodeFlexibleDouble` accepts the
/// string form too, per the convention for every numeric on this API.
struct FundTarget: Codable, Identifiable {
    let id: String
    let fund: String
    let targetBalance: Double
    let notes: String?
    let asOfDate: String?
    let updatedBy: String?

    private enum CodingKeys: String, CodingKey {
        case id, fund, notes
        case targetBalance = "target_balance"
        case asOfDate = "as_of_date"
        case updatedBy = "updated_by"
    }

    // Declaring init(from:) suppresses the memberwise one, which the report
    // tests need in order to build targets without round-tripping JSON.
    init(id: String, fund: String, targetBalance: Double, notes: String? = nil,
         asOfDate: String? = nil, updatedBy: String? = nil) {
        self.id = id
        self.fund = fund
        self.targetBalance = targetBalance
        self.notes = notes
        self.asOfDate = asOfDate
        self.updatedBy = updatedBy
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        fund = try c.decode(String.self, forKey: .fund)
        targetBalance = try c.decodeFlexibleDouble(forKey: .targetBalance) ?? 0
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        asOfDate = try c.decodeIfPresent(String.self, forKey: .asOfDate)
        updatedBy = try c.decodeIfPresent(String.self, forKey: .updatedBy)
    }
}

// MARK: - Bank Models

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

/// A linked bank account, from `GET list_bank_accounts` — a tenant-scoped
/// `bank_account` row, not Plaid's `AccountBase`.
struct BankAccount: Identifiable, Codable {
    let id: String
    let name: String
    /// GL posting key — matches `gl_journal_detail.child`. **Nullable**: a
    /// freshly linked account has no mapping until someone PUTs one via
    /// `api/accounts/{id}`, and an unmapped account is a normal state rather
    /// than an error. The OpenAPI schema lists `gl_child` as required, but the
    /// row is `pgtype.Int4` (`db/sqlc/bank_accounts.sql.go:225`) — decoding it
    /// as non-optional threw on any unmapped account and blanked the tab.
    let glChild: Int?
    /// Whether the account is currently linked and syncing.
    let active: Bool
    let currency: String?
    let fund: String?
    let institutionName: String?
    let mask: String?
    let plaidAccountId: String?
    let plaidItemId: String?
    let subtype: String?
    /// Balances as last synced from Plaid (`api/plaid_store.go` upserts them on
    /// every account sync). Absent from the OpenAPI `BankAccount` schema,
    /// which is why an earlier pass concluded the API carried no balance at
    /// all — the row has carried them all along.
    let balanceCurrent: Double?
    let balanceAvailable: Double?
    let balanceAsOf: String?

    var displayName: String {
        name.isEmpty ? "Account ••\(mask ?? "")" : name
    }

    /// Usable as a payment source only once it is mapped to a GL account.
    var isMapped: Bool { glChild != nil }

    private enum CodingKeys: String, CodingKey {
        case id, name, active, currency, fund, mask, subtype
        case glChild = "gl_child"
        case institutionName = "institution_name"
        case plaidAccountId = "plaid_account_id"
        case plaidItemId = "plaid_item_id"
        case balanceCurrent = "balance_current"
        case balanceAvailable = "balance_available"
        case balanceAsOf = "balance_as_of"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        glChild = try? c.decode(Int.self, forKey: .glChild)
        active = (try? c.decode(Bool.self, forKey: .active)) ?? false
        currency = try? c.decode(String.self, forKey: .currency)
        fund = try? c.decode(String.self, forKey: .fund)
        institutionName = try? c.decode(String.self, forKey: .institutionName)
        mask = try? c.decode(String.self, forKey: .mask)
        plaidAccountId = try? c.decode(String.self, forKey: .plaidAccountId)
        plaidItemId = try? c.decode(String.self, forKey: .plaidItemId)
        subtype = try? c.decode(String.self, forKey: .subtype)
        // pgtype.Numeric can arrive as a JSON string or a number.
        balanceCurrent = try c.decodeFlexibleDouble(forKey: .balanceCurrent)
        balanceAvailable = try c.decodeFlexibleDouble(forKey: .balanceAvailable)
        balanceAsOf = try? c.decode(String.self, forKey: .balanceAsOf)
    }
}

/// One row of the `cash_movements` audit log, from
/// `GET cash_movements/by_account/{bank_account_id}`.
///
/// Provider-agnostic: every payment out and receipt in lands here whatever its
/// origin (Plaid, manual entry, QBO sync), which is why this replaced the
/// Plaid-shaped transaction list.
struct CashMovement: Identifiable, Codable {
    let id: String
    let bankAccountId: String
    /// Signed in `currency`: **`+` is an inflow, `-` an outflow**. Note this is
    /// the opposite of Plaid's convention, which the old row rendering assumed.
    let amount: Double
    let currency: String
    /// `cash_movements.created_at::date` — when the row entered our system,
    /// which may lag the actual bank movement.
    let date: String
    let status: String
    /// From the reconciled journal's description; nil while outstanding.
    let description: String?
    /// From the reconciled journal's `invoice_no` (cheque #, vendor invoice);
    /// nil while outstanding.
    let reference: String?
    let journalId: Int?
    let partyId: String?
    let updatedAt: String?

    /// `journal_id IS NULL` is the reconciliation-status source of truth —
    /// there is no separate flag.
    var isOutstanding: Bool { journalId == nil }

    var isMoneyIn: Bool { amount > 0 }

    var displayName: String {
        [description, reference].compactMap(\.self).first { !$0.isEmpty }
            ?? (isMoneyIn ? "Deposit" : "Withdrawal")
    }

    private enum CodingKeys: String, CodingKey {
        case id, amount, currency, date, status, description, reference
        case bankAccountId = "bank_account_id"
        case journalId = "journal_id"
        case partyId = "party_id"
        case updatedAt = "updated_at"
    }
}


// MARK: - AI Agent Models

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: String
    let content: String

    init(role: String, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
    }
}

struct AgentRequest: Codable {
    let messages: [ChatMessage]
}

struct AgentResponse: Codable {
    let message: String
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


// MARK: - Approval Workflow Models

struct AgingBillFund: Codable {
    let fund: String
    let amount: Double
    let amountPaid: Double
    let remainder: Double

    private enum CodingKeys: String, CodingKey {
        case fund, amount
        case amountPaid = "amount_paid"
        case remainder
    }
}

struct AgingBill: Identifiable, Codable {
    let journalId: Int
    let vendorId: String
    let invoiceNumber: String
    let description: String
    let transactionDate: String
    let dueDate: String
    let amount: Double
    let amountPaid: Double
    let remainder: Double
    /// The BILL's settlement state — OPEN = unpaid, CLOSED = paid (and back to
    /// OPEN on a payment reversal). Not the journal's lifecycle.
    let status: String
    let funds: [AgingBillFund]
    /// The bill's GL journal lifecycle — OPEN = draft, CLOSED = posted,
    /// CANCELLED = voided. This replaced `booked`, which was a redundant
    /// mirror of `journal_status == "CLOSED"` and is no longer sent: decoding
    /// it as a non-optional `Bool` made every aging-bills read fail.
    let journalStatus: String
    let approvalStatus: String
    /// `gl_journal_header.updated_at` — the OCC token for bill writes.
    let updateDate: String?

    var id: Int { journalId }

    /// Posted to the ledger. The question `booked` used to answer.
    var isPosted: Bool { journalStatus == "CLOSED" }
    var isDraft: Bool { journalStatus == "OPEN" }
    var isPaid: Bool { status == "CLOSED" }

    private enum CodingKeys: String, CodingKey {
        case journalId = "journal_id"
        case vendorId = "vendor_id"
        case invoiceNumber = "invoice_number"
        case description
        case transactionDate = "transaction_date"
        case dueDate = "due_date"
        case amount
        case amountPaid = "amount_paid"
        case remainder, status, funds
        case journalStatus = "journal_status"
        case approvalStatus = "approval_status"
        case updateDate = "update_date"
    }
}

/// One payment applied to a bill, from `read_payments_for_bill`.
struct BillPayment: Identifiable, Codable {
    let paymentTransactionId: String?
    let paymentDate: String?
    let appliedAmount: Double?
    let applyLines: Int?

    var id: String { paymentTransactionId ?? "\(paymentDate ?? "")-\(appliedAmount ?? 0)" }

    private enum CodingKeys: String, CodingKey {
        case paymentTransactionId = "payment_transaction_id"
        case paymentDate = "payment_date"
        case appliedAmount = "applied_amount"
        case applyLines = "apply_lines"
    }
}

/// A future-dated payment booked against a bill, from
/// `read_scheduled_payments_for_bill` / `schedule_bill_payment`.
struct BillPaymentSchedule: Identifiable, Codable {
    let id: Int
    let billJournalId: Int?
    let amount: Double?
    let scheduledFor: String?
    let method: String?
    let status: String?
    let sourceAccount: Int?
    let sourceChild: Int?
    let postedJournalId: Int?
    let cancelDate: String?
    let createDate: String?

    var isCancelled: Bool { cancelDate != nil || status == "CANCELLED" }
    var isPosted: Bool { postedJournalId != nil }

    private enum CodingKeys: String, CodingKey {
        case id, amount, method, status
        case billJournalId = "bill_journal_id"
        case scheduledFor = "scheduled_for"
        case sourceAccount = "source_account"
        case sourceChild = "source_child"
        case postedJournalId = "posted_journal_id"
        case cancelDate = "cancel_date"
        case createDate = "create_date"
    }
}

private struct ScheduledPaymentsResponse: Codable {
    let billJournalId: Int
    let schedules: [BillPaymentSchedule]

    private enum CodingKeys: String, CodingKey {
        case billJournalId = "bill_journal_id"
        case schedules
    }
}


// MARK: - AP payment recording (create_payment → txn details → applies → post)


/// The payment header as returned by `create_payment` — the receipts-table
/// shape, NOT the retired `ap_transactions` one the OpenAPI schema still
/// documents for this family (see noble-go-server#217).
struct PaymentRecord: Codable {
    let id: Int
    let kind: String?
    let partyId: String?
    let approvalState: String?
    let postedJournalId: Int?
    let reversed: Bool?

    private enum CodingKeys: String, CodingKey {
        case id, kind, reversed
        case partyId = "party_id"
        case approvalState = "approval_state"
        case postedJournalId = "posted_journal_id"
    }
}



// MARK: - AP payments awaiting confirmation

/// A payment header from the receipts-shaped `payments` table.
///
/// Built on the web — bank linking, the GL lines and the apply lines are all
/// web-side setup, behind that flow's separation of duties. iOS only confirms.
/// Modelled from `db/sqlc/models.go:3241`, not the OpenAPI schema, which still
/// documents the retired `ap_transactions` shape for this family
/// (noble-go-server#217).
struct APPayment: Identifiable, Codable {
    let id: Int
    let kind: String?
    let partyId: String?
    let partyName: String?
    let receiptNo: String?
    let reference: String?
    let receiptDate: String?
    let amount: Double?
    let currency: String?
    let method: String?
    let depositAccount: String?
    let depositAccountDesc: String?
    let memo: String?
    let approvalState: String?
    /// Set once posted. `nil` is what "awaiting confirmation" means.
    let postedJournalId: Int?
    let reversed: Bool?

    /// Unposted, unreversed AP — the set iOS can confirm.
    var awaitsConfirmation: Bool {
        (kind ?? "") == "AP" && postedJournalId == nil && reversed != true
    }

    var displayParty: String {
        for candidate in [partyName, partyId] where !(candidate ?? "").isEmpty { return candidate! }
        return "Payment \(id)"
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, amount, currency, method, memo, reference, reversed
        case partyId = "party_id"
        case partyName = "party_name"
        case receiptNo = "receipt_no"
        case receiptDate = "receipt_date"
        case depositAccount = "deposit_account"
        case depositAccountDesc = "deposit_account_desc"
        case approvalState = "approval_state"
        case postedJournalId = "posted_journal_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        kind = try? c.decode(String.self, forKey: .kind)
        partyId = try? c.decode(String.self, forKey: .partyId)
        partyName = try? c.decode(String.self, forKey: .partyName)
        receiptNo = try? c.decode(String.self, forKey: .receiptNo)
        reference = try? c.decode(String.self, forKey: .reference)
        receiptDate = try? c.decode(String.self, forKey: .receiptDate)
        // pgtype.Numeric: string or number on the wire.
        amount = try c.decodeFlexibleDouble(forKey: .amount)
        currency = try? c.decode(String.self, forKey: .currency)
        method = try? c.decode(String.self, forKey: .method)
        depositAccount = try? c.decode(String.self, forKey: .depositAccount)
        depositAccountDesc = try? c.decode(String.self, forKey: .depositAccountDesc)
        memo = try? c.decode(String.self, forKey: .memo)
        approvalState = try? c.decode(String.self, forKey: .approvalState)
        postedJournalId = try? c.decode(Int.self, forKey: .postedJournalId)
        reversed = try? c.decode(Bool.self, forKey: .reversed)
    }
}

/// One GL line of a payment, from `read_payment_txn_details/{id}`
/// (`db.PaymentTxnDetail`). The web builds these; `post_payment` refuses
/// unless they balance.
struct PaymentTxnLine: Identifiable, Codable {
    let id: Int
    let transactionId: Int?
    let accountCode: String?
    let accountName: String?
    let description: String?
    let fund: String?
    let debit: Double?
    let credit: Double?

    private enum CodingKeys: String, CodingKey {
        case id, description, fund, debit, credit
        case transactionId = "transaction_id"
        case accountCode = "account_code"
        case accountName = "account_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        transactionId = try? c.decode(Int.self, forKey: .transactionId)
        accountCode = try? c.decode(String.self, forKey: .accountCode)
        accountName = try? c.decode(String.self, forKey: .accountName)
        description = try? c.decode(String.self, forKey: .description)
        fund = try? c.decode(String.self, forKey: .fund)
        debit = try c.decodeFlexibleDouble(forKey: .debit)
        credit = try c.decodeFlexibleDouble(forKey: .credit)
    }
}

/// One apply line — which charge a payment settles, from
/// `read_payment_details/{id}` (`db.PaymentDetail`). `charge_id` carries the
/// bill's journal id.
struct PaymentApplyLine: Identifiable, Codable {
    let id: Int
    let chargeId: String?
    let chargeNo: String?
    let chargeDescription: String?
    let fund: String?
    let applyAmount: Double?
    let outstandingAmount: Double?

    /// The bill this settles, when the charge is a GL bill.
    var billJournalId: Int? { Int(chargeId ?? "") }

    private enum CodingKeys: String, CodingKey {
        case id, fund
        case chargeId = "charge_id"
        case chargeNo = "charge_no"
        case chargeDescription = "charge_description"
        case applyAmount = "apply_amount"
        case outstandingAmount = "outstanding_amount"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        chargeId = try? c.decode(String.self, forKey: .chargeId)
        chargeNo = try? c.decode(String.self, forKey: .chargeNo)
        chargeDescription = try? c.decode(String.self, forKey: .chargeDescription)
        fund = try? c.decode(String.self, forKey: .fund)
        applyAmount = try c.decodeFlexibleDouble(forKey: .applyAmount)
        outstandingAmount = try c.decodeFlexibleDouble(forKey: .outstandingAmount)
    }
}

private struct ReadPaymentsByDateRequest: Codable {
    let fromDate: String
    let toDate: String

    private enum CodingKeys: String, CodingKey {
        case fromDate = "from_date"
        case toDate = "to_date"
    }
}

struct PostPaymentRequest: Codable {
    let id: Int
    let period: Int
    let periodYear: Int
    /// Max 200 characters.
    let description: String

    private enum CodingKeys: String, CodingKey {
        case id, period, description
        case periodYear = "period_year"
    }
}

struct PostPaymentResponse: Codable {
    let journalId: Int?
    let paymentId: Int?

    private enum CodingKeys: String, CodingKey {
        case journalId = "journal_id"
        case paymentId = "payment_id"
    }
}



struct UpdateBillApprovalRequest: Codable {
    let journalId: Int
    let approvalStatus: String

    private enum CodingKeys: String, CodingKey {
        case journalId = "journal_id"
        case approvalStatus = "approval_status"
    }
}

struct BillApprovalResponse: Codable {
    let journalId: Int
    let approvalStatus: String
    let updateDate: String?

    private enum CodingKeys: String, CodingKey {
        case journalId = "journal_id"
        case approvalStatus = "approval_status"
        case updateDate = "update_date"
    }
}

struct ApprovalEvent: Identifiable, Codable {
    let id: Int
    let occurredAt: String?
    let actorUserId: String?
    let actorDisplayName: String?
    let actorEmail: String?
    let action: String?
    let priorState: String?
    let newState: String?
    let rejectionReason: String?
    let note: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case occurredAt = "occurred_at"
        case actorUserId = "actor_user_id"
        case actorDisplayName = "actor_display_name"
        case actorEmail = "actor_email"
        case action
        case priorState = "prior_state"
        case newState = "new_state"
        case rejectionReason = "rejection_reason"
        case note
    }
}

struct ApprovalHistory: Codable {
    let journalId: Int
    let journalType: String?
    let events: [ApprovalEvent]

    private enum CodingKeys: String, CodingKey {
        case journalId = "journal_id"
        case journalType = "journal_type"
        case events
    }
}

struct BulkJournalResult: Identifiable, Codable {
    let journalId: Int
    let ok: Bool
    let status: String?
    let error: String?

    var id: Int { journalId }

    private enum CodingKeys: String, CodingKey {
        case journalId = "journal_id"
        case ok, status, error
    }
}

struct BulkJournalResponse: Codable {
    let operation: String
    let total: Int
    let succeeded: Int
    let failed: Int
    let results: [BulkJournalResult]
}

struct CurrentPeriod: Codable {
    let periodId: Int
    let periodYear: Int
    let description: String?

    private enum CodingKeys: String, CodingKey {
        case periodId = "period_id"
        case periodYear = "period_year"
        case description
    }
}

struct UserProfile: Codable {
    let uid: String?
    let userName: String?
    let name: String?
    let email: String?
    /// Display name of the tenant. The session login response carries no
    /// company name, so this read is where the app learns it.
    let company: String?
    let role: String?
    let title: String?

    /// Best available human name: the profile's display name, else the login
    /// handle, else the email local part.
    var bestDisplayName: String {
        [name, userName].compactMap(\.self).first { !$0.isEmpty }
            ?? (email ?? "").split(separator: "@").first.map(String.init)
            ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case uid
        case userName = "user_name"
        case name, email, company, role, title
    }
}

// MARK: - Service

@Observable
class APIService {
    var token: String
    var tenant: String
    var onUnauthorized: (() -> Void)?
    var onSessionExpired: (() -> Void)?

    /// When the session token stops being accepted. Informational — the server
    /// is the authority, and a 401 is what actually drives a refresh.
    var sessionExpiresAt: Date?

    /// When the refresh credential stops being accepted. This is the client's
    /// only visibility into it: the refresh token is delivered as an HttpOnly
    /// cookie and is unreadable here by design, so the expiry handed back at
    /// login is how we decide whether a refresh is still worth attempting.
    var refreshExpiresAt: Date?

    private let host = "https://api.nobleledger.com"
    // private let host = "http://localhost:8080"

    private var baseURL: String {
        "\(host)/\(tenant)/v1"
    }

    /// Builds a tenant-scoped URL, refusing the cases the server refuses.
    ///
    /// There used to be a `tenant.isEmpty ? "public"` fallback here. `public`
    /// is the template schema every tenant is cloned FROM, and the server now
    /// rejects it on every request path — reads served the seed ledger and a
    /// write would have contaminated every tenant provisioned afterwards. An
    /// absent tenant means there is no session, so say that instead of
    /// quietly addressing the template.
    private func tenantURL(_ path: String) throws -> URL {
        guard !tenant.isEmpty else { throw APIError.unauthorized }
        guard let url = URL(string: baseURL + path) else {
            throw APIError.serverError(statusCode: 0, message: "Invalid URL.")
        }
        return url
    }

    /// Schemas a request may never be scoped to, mirroring the server's
    /// `isReservedSchema`. Checked at login so the user gets an actionable
    /// message instead of a round trip that always fails.
    static func isReservedTenant(_ candidate: String) -> Bool {
        let name = candidate.lowercased()
        return name == "public" || name == "information_schema" || name.hasPrefix("pg_")
    }

    /// Session auth sits OUTSIDE the tenant group: the tenant travels in the
    /// login body and comes from the session row on every call after that.
    private func authURL(_ path: String) -> URL? {
        URL(string: host + path)
    }

    let decoder = JSONDecoder()

    /// URLSession used for API traffic. Injectable so tests can install a
    /// stubbed URLProtocol; production callers use the default.
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        self.token = UserDefaults.standard.string(forKey: "authToken") ?? ""
        self.tenant = UserDefaults.standard.string(forKey: "tenant") ?? ""
        self.sessionExpiresAt = UserDefaults.standard.object(forKey: "sessionExpiresAt") as? Date
        self.refreshExpiresAt = UserDefaults.standard.object(forKey: "refreshExpiresAt") as? Date
    }

    /// Whether rotating the session is still worth a round trip. False once the
    /// refresh cookie's advertised lifetime has run out, which is the signal to
    /// demand a full login instead of locking to the biometric screen.
    var canAttemptRefresh: Bool {
        guard let refreshExpiresAt else { return false }
        return refreshExpiresAt > Date()
    }

    private func handleUnauthorized() {
        token = ""
        UserDefaults.standard.removeObject(forKey: "authToken")

        if canAttemptRefresh {
            // The refresh cookie should still be good — lock the session so the
            // user can unlock with biometrics and retry the refresh.
            onSessionExpired?()
        } else {
            clearSession()
            onUnauthorized?()
        }
    }

    /// Drops every trace of the session held on this device. The refresh token
    /// is HttpOnly, so the cookie sweep is the only way to discard it locally.
    func clearSession() {
        token = ""
        sessionExpiresAt = nil
        refreshExpiresAt = nil
        // "refreshToken" is the retired Firebase credential — swept so an
        // upgrade from a pre-session build leaves nothing behind.
        for key in ["authToken", "sessionExpiresAt", "refreshExpiresAt", "refreshToken"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        if let storage = session.configuration.httpCookieStorage,
           let url = authURL(Self.refreshPath) {
            storage.cookies(for: url)?.forEach(storage.deleteCookie)
        }
    }

    // MARK: - Request helper (internal so endpoint extensions can use it)

    func request(_ path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        let url = try tenantURL(path)

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        if !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: req)

            guard let http = response as? HTTPURLResponse else {
                throw APIError.serverError(statusCode: 0, message: "Invalid server response.")
            }

            if http.statusCode == 401 {
                do {
                    try await performTokenRefresh()
                    return try await retryRequest(path, method: method, body: body)
                } catch {
                    handleUnauthorized()
                    throw APIError.unauthorized
                }
            }

            guard (200..<300).contains(http.statusCode) else {
                throw Self.failure(status: http.statusCode, body: data)
            }

            return data
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    /// Maps a non-2xx body to an error, singling out the OCC conflict shape
    /// (`{"error":"stale","current_updated_at":…}`, api/occ_helpers.go) so
    /// callers can offer a reload instead of showing the user "stale".
    private static func failure(status: Int, body: Data) -> APIError {
        let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        if status == 409, let json,
           json["error"] as? String == "stale" || json["current_updated_at"] != nil {
            return .conflict(currentUpdatedAt: json["current_updated_at"] as? String)
        }
        let message = json.flatMap { $0["message"] as? String ?? $0["error"] as? String }
            ?? "Server error (\(status))."
        return .serverError(statusCode: status, message: message)
    }

    /// Resolves the OCC token for a guarded write, re-reading the row when the
    /// caller has none in hand.
    ///
    /// It never synthesises one. Sending `now()` or an empty string would
    /// either 400 or — worse, if the server ever relaxed — reopen the
    /// lost-update hole the token exists to close.
    private func resolvedOCCToken(
        _ provided: String,
        reread: () async throws -> String?
    ) async throws -> String {
        if !provided.isEmpty { return provided }
        guard let token = try await reread(), !token.isEmpty else {
            throw APIError.serverError(
                statusCode: 0,
                message: "Could not determine this record's version. Reload and try again."
            )
        }
        return token
    }

    private func retryRequest(_ path: String, method: String, body: Data?) async throws -> Data {
        let url = try tenantURL(path)

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.serverError(statusCode: 0, message: "Invalid server response.")
        }
        guard http.statusCode != 401 else {
            handleUnauthorized()
            throw APIError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            throw Self.failure(status: http.statusCode, body: data)
        }
        return data
    }

    // MARK: - Session auth (/v1/auth)

    private static let loginPath = "/v1/auth/login"
    private static let refreshPath = "/v1/auth/refresh"
    private static let logoutPath = "/v1/auth/logout"

    /// One confirmed second factor, as offered by an MFA challenge.
    struct MFAFactor: Decodable, Identifiable {
        let id: String
        let type: String
        let hint: String?
    }

    /// What `POST /v1/auth/login` answered.
    enum LoginOutcome {
        /// A session was issued and is now installed on this client.
        case session
        /// The account has confirmed factors, so the server issued a challenge
        /// instead of a session. Completing it needs /v1/auth/mfa/select and
        /// /mfa/verify, which this app does not implement yet.
        case mfaRequired(challengeID: String, factors: [MFAFactor])
    }

    /// Shared by login and refresh — the server returns the same object for
    /// both. `refresh_token` is deliberately absent: the server blanks it out
    /// of the body and sets it as an HttpOnly cookie instead.
    private struct SessionResponse: Decodable {
        let sessionToken: String?
        let expiresAt: String?
        let refreshExpiresAt: String?
        let scope: String?
        let mfaRequired: Bool?
        let challengeID: String?
        let factors: [MFAFactor]?

        private enum CodingKeys: String, CodingKey {
            case sessionToken = "session_token"
            case expiresAt = "expires_at"
            case refreshExpiresAt = "refresh_expires_at"
            case scope
            case mfaRequired = "mfa_required"
            case challengeID = "challenge_id"
            case factors
        }
    }

    /// Go's `time.Time` marshals RFC3339 **with** fractional seconds, which the
    /// plain `.iso8601` strategy rejects — so try both spellings rather than
    /// silently losing the expiry and forcing a full login every 15 minutes.
    private static func parseTimestamp(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    /// Logs in against the session contract. The tenant travels in the body,
    /// not the URL, and is only adopted as this client's tenant once the
    /// server has accepted it — a rejected login must not repoint the app.
    func logIn(tenant loginTenant: String, email: String, password: String) async throws -> LoginOutcome {
        guard !Self.isReservedTenant(loginTenant) else {
            throw APIError.serverError(
                statusCode: 400,
                message: "\"\(loginTenant)\" is not a workspace. Enter your company's workspace name."
            )
        }
        guard let url = authURL(Self.loginPath) else {
            throw APIError.serverError(statusCode: 0, message: "Invalid server URL.")
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "tenant": loginTenant,
            "email": email,
            "password": password,
        ])

        let data = try await sendAuthRequest(req)
        guard let decoded = try? decoder.decode(SessionResponse.self, from: data) else {
            throw APIError.decodingFailed
        }

        if decoded.mfaRequired == true {
            return .mfaRequired(
                challengeID: decoded.challengeID ?? "",
                factors: decoded.factors ?? []
            )
        }

        guard let sessionToken = decoded.sessionToken, !sessionToken.isEmpty else {
            throw APIError.serverError(statusCode: 0, message: "Login returned no session token.")
        }

        // A platform session authenticates /admin/v1 only and is refused by
        // every tenant route, so accepting it would hand the user an app in
        // which nothing loads and every screen shows a permission error.
        if decoded.scope == "platform" {
            throw APIError.serverError(
                statusCode: 403,
                message: "This account is a platform operator with no access to \"\(loginTenant)\"."
            )
        }

        tenant = loginTenant
        UserDefaults.standard.set(loginTenant, forKey: "tenant")
        applySession(decoded, token: sessionToken)
        return .session
    }

    /// Revokes the session server-side, then clears the local copy. Best
    /// effort on the network half: a failed call still drops the credentials
    /// held here, because the alternative is a device that thinks it is still
    /// signed in.
    func logOut() async {
        if !token.isEmpty, let url = authURL(Self.logoutPath) {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await session.data(for: req)
        }
        clearSession()
    }

    /// Public entry point for re-authenticating after session expiry.
    func refreshAccessToken() async throws {
        try await performTokenRefresh()
    }

    private var refreshTask: Task<Void, Error>?

    /// Rotates the session token, single-flight.
    ///
    /// The server revokes the refresh token it was handed and treats a second
    /// presentation of the same one as theft — burning every session the user
    /// has, once a 30-second grace window passes. Session tokens last 15
    /// minutes, so any screen that fires several reads at once (the dashboard
    /// fires six) would otherwise 401 in parallel and refresh in parallel.
    /// Collapsing those into one rotation is what keeps that from logging the
    /// user out of every device.
    private func performTokenRefresh() async throws {
        if let inFlight = refreshTask {
            try await inFlight.value
            return
        }

        let task = Task { try await rotateSession() }
        refreshTask = task
        do {
            try await task.value
            refreshTask = nil
        } catch {
            refreshTask = nil
            throw error
        }
    }

    private func rotateSession() async throws {
        guard canAttemptRefresh, let url = authURL(Self.refreshPath) else {
            throw APIError.unauthorized
        }

        // No body and no bearer: the credential is the HttpOnly refresh cookie,
        // which URLSession stored from the login response and sends only to
        // this path.
        var req = URLRequest(url: url)
        req.httpMethod = "POST"

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let decoded = try? decoder.decode(SessionResponse.self, from: data),
              let sessionToken = decoded.sessionToken, !sessionToken.isEmpty else {
            throw APIError.unauthorized
        }

        applySession(decoded, token: sessionToken)
    }

    private func applySession(_ response: SessionResponse, token newToken: String) {
        token = newToken
        UserDefaults.standard.set(newToken, forKey: "authToken")

        sessionExpiresAt = Self.parseTimestamp(response.expiresAt)
        if let sessionExpiresAt {
            UserDefaults.standard.set(sessionExpiresAt, forKey: "sessionExpiresAt")
        } else {
            UserDefaults.standard.removeObject(forKey: "sessionExpiresAt")
        }

        // Only ever extended, never cleared: a rotation response that omits the
        // refresh expiry must not shorten the credential we still hold.
        if let newRefreshExpiry = Self.parseTimestamp(response.refreshExpiresAt) {
            refreshExpiresAt = newRefreshExpiry
            UserDefaults.standard.set(newRefreshExpiry, forKey: "refreshExpiresAt")
        }
    }

    /// Runs an unauthenticated /v1/auth request and surfaces the server's own
    /// message on failure. Never routes through the 401 → refresh path: these
    /// endpoints are how a session is obtained in the first place.
    private func sendAuthRequest(_ req: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.serverError(statusCode: 0, message: "Invalid server response.")
            }
            guard (200..<300).contains(http.statusCode) else {
                throw Self.failure(status: http.statusCode, body: data)
            }
            return data
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
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

    /// Chart of accounts with real balances. Uses `/account_balances`, which
    /// aggregates the authoritative gl_account_amts store across all funds for
    /// the current fiscal year — `/account_list` is the bare catalog whose
    /// balance/period columns are always 0.
    func fetchAccountList() async throws -> [Account] {
        let data = try await request("/account_balances")
        do {
            return try decoder.decode([Account].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    // MARK: - GL Journal Operations

    func fetchJournalHeaderById(_ id: Int) async throws -> JournalHeader {
        let data = try await request("/read_journal_header_by_id/\(id)")
        do {
            return try decoder.decode(JournalHeader.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchJournalDetails(journalId: Int) async throws -> [JournalDetail] {
        let data = try await request("/get_journal_detail/\(journalId)")
        do {
            return try decoder.decode([JournalDetail].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchOpenJournalDetails() async throws -> [JournalDetail] {
        let data = try await request("/read_journal_details")
        do {
            return try decoder.decode([JournalDetail].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchLatestJournal() async throws -> JournalEntry {
        let data = try await request("/get_latest_journal")
        do {
            return try decoder.decode(JournalEntry.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchLastJournalNumber() async throws -> Int {
        let data = try await request("/read_last_journal_no")
        do {
            // Server responds with a bare JSON integer (e.g. `1234`).
            return try decoder.decode(Int.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func createJournalHeader(_ params: CreateJournalHeaderRequest) async throws -> Int {
        let body = try JSONEncoder().encode(params)
        let data = try await request("/create_journal_header", method: "POST", body: body)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let journalId = json["journal_id"] as? Int {
            return journalId
        }
        return 0
    }

    func createFullJournal(_ params: CreateFullJournalRequest) async throws {
        let body = try JSONEncoder().encode(params)
        _ = try await request("/create_journal", method: "POST", body: body)
    }

    func updateJournalEntry(_ params: CreateFullJournalRequest) async throws {
        let body = try JSONEncoder().encode(params)
        _ = try await request("/update_journal", method: "POST", body: body)
    }

    func createJournalDetail(_ params: CreateJournalDetailRequest) async throws {
        let body = try JSONEncoder().encode(params)
        _ = try await request("/create_journal_detail", method: "POST", body: body)
    }

    func bookJournalEntry(_ params: BookJournalRequest) async throws {
        let body = try JSONEncoder().encode(params)
        _ = try await request("/book_journal_entry", method: "POST", body: body)
    }

    func closeJournalEntry(_ params: CloseJournalRequest) async throws {
        let body = try JSONEncoder().encode(params)
        _ = try await request("/close_journal_entry", method: "POST", body: body)
    }

    func deleteJournalEntry(_ params: DeleteJournalRequest) async throws {
        let body = try JSONEncoder().encode(params)
        _ = try await request("/delete_journal_entry", method: "POST", body: body)
    }

    func cloneJournalEntry(_ params: CloneJournalRequest) async throws {
        let body = try JSONEncoder().encode(params)
        _ = try await request("/clone_journal_entry", method: "POST", body: body)
    }

    func fetchJournalsByPeriod(_ params: JournalsByPeriodRequest) async throws -> [JournalHeader] {
        let body = try JSONEncoder().encode(params)
        let data = try await request("/read_journal_header_by_period", method: "POST", body: body)
        do {
            return try decoder.decode([JournalHeader].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchJournalsByDate(_ params: JournalsByDateRequest) async throws -> [JournalHeader] {
        let body = try JSONEncoder().encode(params)
        let data = try await request("/read_journal_list", method: "POST", body: body)
        do {
            return try decoder.decode([JournalHeader].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchTransactionsByAccount(_ params: TransactionsByAccountRequest) async throws -> [JournalDetail] {
        let body = try JSONEncoder().encode(params)
        let data = try await request("/read_transaction_by_account", method: "POST", body: body)
        do {
            return try decoder.decode([JournalDetail].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchJournalById(_ journalId: Int) async throws -> JournalEntry {
        let body = try JSONEncoder().encode(DeleteJournalRequest(journalId: journalId))
        let data = try await request("/read_jrn_by_id", method: "POST", body: body)
        do {
            let entries = try decoder.decode([JournalEntry].self, from: data)
            guard let entry = entries.first else {
                throw APIError.serverError(statusCode: 404, message: "Journal not found.")
            }
            return entry
        } catch let error as APIError {
            throw error
        } catch {
            // Debug prints that dumped the raw journal response to the device
            // console were removed: they logged ledger rows in a shipping
            // build, and the decode failure is already reported as such.
            throw APIError.decodingFailed
        }
    }

    // MARK: - Templates

    func fetchTemplates() async throws -> [JournalTemplate] {
        let data = try await request("/read_templates")
        do {
            return try decoder.decode([JournalTemplate].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchTemplate(reference: Int) async throws -> JournalTemplate {
        let data = try await request("/read_template_details/\(reference)")
        do {
            return try decoder.decode(JournalTemplate.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    // MARK: - Evidence

    func fetchEvidenceByJournal(_ journalId: Int) async throws -> [GlEvidence] {
        let data = try await request("/read_evidence_by_journal/\(journalId)")
        do {
            return try decoder.decode([GlEvidence].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func createEvidence(_ params: CreateEvidenceRequest) async throws {
        let body = try JSONEncoder().encode(params)
        _ = try await request("/create_evidence", method: "POST", body: body)
    }


    func fetchVendors() async throws -> [Vendor] {
        let data = try await request("/read_vendors")
        do {
            return try decoder.decode([Vendor].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    // MARK: - AP Vendors

    func fetchApVendors() async throws -> [ApVendor] {
        let data = try await request("/list_ap_vendors")
        do {
            return try decoder.decode([ApVendor].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchApVendor(id: String) async throws -> ApVendor {
        let data = try await request("/get_ap_vendor/\(id)")
        do {
            return try decoder.decode(ApVendor.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchApVendorsByStatus(_ status: String) async throws -> [ApVendor] {
        let data = try await request("/list_ap_vendors_by_status/\(status)")
        do {
            return try decoder.decode([ApVendor].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func createApVendor(_ params: CreateApVendorRequest) async throws {
        let body = try JSONEncoder().encode(params)
        _ = try await request("/create_ap_vendor", method: "POST", body: body)
    }

    func updateApVendor(_ params: UpdateApVendorRequest) async throws {
        var updated = params
        updated.expectedUpdatedAt = try await resolvedOCCToken(params.expectedUpdatedAt) {
            try await fetchApVendor(id: params.id).updatedAt
        }
        let body = try JSONEncoder().encode(updated)
        _ = try await request("/update_ap_vendor", method: "POST", body: body)
    }

    func deleteApVendor(id: String) async throws {
        _ = try await request("/delete_ap_vendor/\(id)", method: "DELETE")
    }

    // MARK: - AR Customers

    func fetchArCustomers() async throws -> [ArCustomer] {
        let data = try await request("/list_ar_customers")
        do {
            return try decoder.decode([ArCustomer].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchArCustomer(id: String) async throws -> ArCustomer {
        let data = try await request("/get_ar_customer/\(id)")
        do {
            return try decoder.decode(ArCustomer.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchArCustomersByStatus(_ status: String) async throws -> [ArCustomer] {
        let data = try await request("/list_ar_customers_by_status/\(status)")
        do {
            return try decoder.decode([ArCustomer].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func createArCustomer(_ params: CreateArCustomerRequest) async throws {
        let body = try JSONEncoder().encode(params)
        _ = try await request("/create_ar_customer", method: "POST", body: body)
    }

    func updateArCustomer(_ params: UpdateArCustomerRequest) async throws {
        var updated = params
        updated.expectedUpdatedAt = try await resolvedOCCToken(params.expectedUpdatedAt) {
            try await fetchArCustomer(id: params.customerId).updatedAt
        }
        let body = try JSONEncoder().encode(updated)
        _ = try await request("/update_ar_customer", method: "POST", body: body)
    }

    func deleteArCustomer(id: String) async throws {
        _ = try await request("/delete_ar_customer/\(id)", method: "DELETE")
    }






    // MARK: - Payment Events


    // MARK: - Payment Details


    // MARK: - Payment Transaction Details


    // MARK: - Plaid / Banking

    /// Mints a Plaid Link token. Pass `itemID` to re-link an existing Item
    /// (Plaid "update mode"); omit it for a new connection.
    func createLinkToken(itemID: String? = nil) async throws -> String {
        var body: Data?
        if let itemID, !itemID.isEmpty {
            body = try JSONEncoder().encode(["item_id": itemID])
        }
        let data = try await request("/plaid_link_token", method: "POST", body: body)
        do {
            return try decoder.decode(LinkTokenResponse.self, from: data).linkToken
        } catch {
            throw APIError.decodingFailed
        }
    }

    /// Exchanges Plaid Link's `public_token`. The access token is stored
    /// server-side encrypted and never crosses the wire.
    func exchangePublicToken(_ publicToken: String) async throws {
        let body = try JSONEncoder().encode(ExchangeTokenRequest(publicToken: publicToken))
        _ = try await request("/get_access_token", method: "POST", body: body)
    }

    func fetchBankAccounts() async throws -> [BankAccount] {
        let data = try await request("/list_bank_accounts")
        do {
            return try decoder.decode([BankAccount].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    /// Cash movements for one bank account. `from`/`to` are required by the
    /// server, so the caller must choose a window rather than getting an
    /// unbounded "recent" list.
    func fetchCashMovements(
        bankAccountID: String,
        from: Date,
        to: Date,
        outstandingOnly: Bool = false
    ) async throws -> [CashMovement] {
        var path = "/cash_movements/by_account/\(escapePathComponent(bankAccountID))"
            + "?dateFrom=\(Self.dateOnly(from))&dateTo=\(Self.dateOnly(to))"
        if outstandingOnly { path += "&outstanding=true" }
        let data = try await request(path)
        do {
            return try decoder.decode([CashMovement].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    /// Manual "sync now". Ingest is normally webhook-driven; this is the only
    /// path for an Item whose webhook Plaid cannot reach, so it is an explicit
    /// user action rather than something a screen calls on appear.
    func syncBankTransactions(itemID: String? = nil) async throws {
        var path = "/api/transactions"
        if let itemID, !itemID.isEmpty {
            path += "?item_id=\(escapeQueryValue(itemID))"
        }
        _ = try await request(path, method: "POST")
    }

    private static func dateOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - AI Agent

    /// Sends a chat message and collects the full SSE-streamed response.
    func sendAgentMessage(messages: [ChatMessage]) async throws -> String {
        let url = try tenantURL("/agent/chat")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(AgentRequest(messages: messages))

        let (bytes, response) = try await URLSession.shared.bytes(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.serverError(statusCode: 0, message: "Invalid server response.")
        }

        if http.statusCode == 401 {
            try await performTokenRefresh()
            return try await sendAgentMessage(messages: messages)
        }

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.serverError(statusCode: http.statusCode, message: "Server error (\(http.statusCode)).")
        }

        var result = ""
        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("data: ") else { continue }
            let jsonStr = String(trimmed.dropFirst(6))
            guard let jsonData = jsonStr.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let type = event["type"] as? String else { continue }

            switch type {
            case "text":
                if let content = event["content"] as? String {
                    result += content
                }
            case "error":
                let content = event["content"] as? String ?? "Unknown error"
                throw APIError.serverError(statusCode: 0, message: content)
            case "done":
                break
            default:
                break
            }
        }
        return result
    }

    /// Sends a chat message and streams text chunks via an AsyncStream.
    func streamAgentMessage(messages: [ChatMessage]) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                do {
                    guard let url = URL(string: baseURL + "/agent/chat") else {
                        continuation.finish()
                        return
                    }

                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    req.httpBody = try JSONEncoder().encode(AgentRequest(messages: messages))

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)

                    guard let http = response as? HTTPURLResponse,
                          (200..<300).contains(http.statusCode) else {
                        continuation.finish()
                        return
                    }

                    for try await line in bytes.lines {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        guard trimmed.hasPrefix("data: ") else { continue }
                        let jsonStr = String(trimmed.dropFirst(6))
                        guard let jsonData = jsonStr.data(using: .utf8),
                              let event = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                              let type = event["type"] as? String else { continue }

                        switch type {
                        case "text":
                            if let content = event["content"] as? String {
                                continuation.yield(content)
                            }
                        case "done", "error":
                            continuation.finish()
                            return
                        default:
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
        }
    }

    func analyzeInvoice(imageData: Data, mediaType: String = "image/jpeg") async throws -> InvoiceExtraction {
        let base64Image = imageData.base64EncodedString()
        let body = try JSONSerialization.data(withJSONObject: [
            "image": base64Image,
            "media_type": mediaType
        ])
        let data = try await request("/agent/analyze-invoice", method: "POST", body: body)
        do {
            return try decoder.decode(InvoiceExtraction.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    // MARK: - AR Transactions

    func fetchArTransactions() async throws -> [ArTransaction] {
        let data = try await request("/list_ar_transactions")
        do {
            return try decoder.decode([ArTransaction].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchArTransaction(id: String) async throws -> ArTransaction {
        let data = try await request("/get_ar_transaction/\(id)")
        do {
            return try decoder.decode(ArTransaction.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchArTransactionsByStatus(_ status: String) async throws -> [ArTransaction] {
        let data = try await request("/list_ar_transactions_by_status/\(status)")
        do {
            return try decoder.decode([ArTransaction].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchOverdueArTransactions() async throws -> [ArTransaction] {
        let data = try await request("/list_overdue_ar_transactions")
        do {
            return try decoder.decode([ArTransaction].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func createArTransaction(_ params: CreateArTransactionRequest) async throws {
        let body = try JSONEncoder().encode(params)
        _ = try await request("/create_ar_transaction", method: "POST", body: body)
    }

    func updateArTransactionAmountReceived(_ params: UpdateArAmountReceivedRequest) async throws {
        var updated = params
        updated.expectedUpdatedAt = try await resolvedOCCToken(params.expectedUpdatedAt) {
            try await fetchArTransaction(id: params.id).updatedAt
        }
        let body = try JSONEncoder().encode(updated)
        _ = try await request("/update_ar_transaction_amount_received", method: "POST", body: body)
    }

    func updateArTransactionStatus(_ params: UpdateArStatusRequest) async throws {
        var updated = params
        updated.expectedUpdatedAt = try await resolvedOCCToken(params.expectedUpdatedAt) {
            try await fetchArTransaction(id: params.id).updatedAt
        }
        let body = try JSONEncoder().encode(updated)
        _ = try await request("/update_ar_transaction_status", method: "POST", body: body)
    }

    func deleteArTransaction(id: String) async throws {
        _ = try await request("/delete_ar_transaction/\(id)", method: "DELETE")
    }

    // MARK: - AR Transaction Details

    func fetchArTransactionDetails(transactionId: String) async throws -> [ArTransactionDetail] {
        let data = try await request("/list_ar_transaction_details_by_txn/\(transactionId)")
        do {
            return try decoder.decode([ArTransactionDetail].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    // MARK: - Approval Workflow (Payment Sign-Off & Journal Booking)

    func fetchAgingBills(periodYear: Int, periodFrom: Int = 1, periodTo: Int = 12, status: String = "ALL") async throws -> [AgingBill] {
        let path = "/read_aging_bills_by_period?period_year=\(periodYear)&period_from=\(periodFrom)&period_to=\(periodTo)&status=\(status)"
        let data = try await request(path)
        do {
            return try decoder.decode([AgingBill].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    /// Per-period comparison trial balance for one fund and year — actual,
    /// budget, opening and closing per account per period.
    ///
    /// The whole operating statement comes from this one call: the month is
    /// the selected period's row, year-to-date is the sum of periods 1...n.
    /// Budget is read here rather than from `read_budget_amt`, whose
    /// `gl_budget_amt` table is empty — the live budget lives on
    /// `gl_account_amts` as `amount_type = 'BUDGET'`.
    func fetchComparisonTrialBalance(fund: String, year: Int) async throws -> [ComparisonTrialBalanceRow] {
        let path = "/comparison_trial_balance_by_fund?fund=\(escapeQueryValue(fund))&year=\(year)"
        let data = try await request(path)
        do {
            return try decoder.decode([ComparisonTrialBalanceRow].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    /// Board-set targets, one row per fund that has one. Funds without a target
    /// are simply absent — the caller must not read absence as a target of zero.
    func fetchFundTargets() async throws -> [FundTarget] {
        let data = try await request("/fund_targets_list")
        do {
            return try decoder.decode([FundTarget].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    // MARK: - Confirming an AP payment

    /// AP payments the web has built but not yet posted.
    ///
    /// `post_payment` is the only route that flips `approval_state` to
    /// APPROVED — `SetPaymentApprovalState` exists in SQL but is exposed on no
    /// route — so confirming and posting are the same act.
    func fetchPaymentsAwaitingConfirmation(from: Date, to: Date) async throws -> [APPayment] {
        let body = try JSONEncoder().encode(ReadPaymentsByDateRequest(
            fromDate: Self.dateOnly(from),
            toDate: Self.dateOnly(to)
        ))
        let data = try await request("/read_payments_by_date", method: "POST", body: body)
        do {
            return try decoder.decode([APPayment].self, from: data)
                .filter(\.awaitsConfirmation)
                .sorted { ($0.receiptDate ?? "") > ($1.receiptDate ?? "") }
        } catch {
            throw APIError.decodingFailed
        }
    }

    /// The GL lines the web built for this payment.
    func fetchPaymentTxnLines(paymentId: Int) async throws -> [PaymentTxnLine] {
        let data = try await request("/read_payment_txn_details/\(paymentId)")
        do {
            return try decoder.decode([PaymentTxnLine].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    /// Which charges this payment settles.
    func fetchPaymentApplyLines(paymentId: Int) async throws -> [PaymentApplyLine] {
        let data = try await request("/read_payment_details/\(paymentId)")
        do {
            return try decoder.decode([PaymentApplyLine].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func postPayment(_ params: PostPaymentRequest) async throws -> PostPaymentResponse {
        let body = try JSONEncoder().encode(params)
        let data = try await request("/post_payment", method: "POST", body: body)
        do {
            return try decoder.decode(PostPaymentResponse.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }


    /// Payments already applied to a bill.
    func fetchBillPayments(billJournalId: Int) async throws -> [BillPayment] {
        let data = try await request("/read_payments_for_bill/\(billJournalId)")
        do {
            return try decoder.decode([BillPayment].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    /// Payments scheduled against a bill but not yet posted.
    func fetchBillPaymentSchedules(billJournalId: Int) async throws -> [BillPaymentSchedule] {
        let data = try await request("/read_scheduled_payments_for_bill/\(billJournalId)")
        do {
            return try decoder.decode(ScheduledPaymentsResponse.self, from: data).schedules
        } catch {
            throw APIError.decodingFailed
        }
    }



    /// Transition an AP bill's approval state (PENDING/REVIEW/APPROVED/DENIED).
    /// The server enforces role permissions and forbids self-sign-off.
    func updateBillApproval(journalId: Int, approvalStatus: String) async throws -> BillApprovalResponse {
        let body = try JSONEncoder().encode(UpdateBillApprovalRequest(journalId: journalId, approvalStatus: approvalStatus))
        let data = try await request("/update_bill_approval", method: "POST", body: body)
        do {
            return try decoder.decode(BillApprovalResponse.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchJournalApprovalHistory(journalId: Int) async throws -> ApprovalHistory {
        let data = try await request("/read_journal_approval_history/\(journalId)")
        do {
            return try decoder.decode(ApprovalHistory.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    /// Close up to 200 journals; per-row results (already-closed counts as success).
    func bulkCloseJournalEntries(journalIds: [Int]) async throws -> BulkJournalResponse {
        let body = try JSONSerialization.data(withJSONObject: ["journal_ids": journalIds])
        let data = try await request("/bulk_close_journal_entries", method: "POST", body: body)
        do {
            return try decoder.decode(BulkJournalResponse.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    /// Book up to 200 journals into a period: flips booked=true and updates
    /// account balances server-side. Per-row separation-of-duties results.
    func bulkBookJournalEntries(journalIds: [Int], period: Int, periodYear: Int) async throws -> BulkJournalResponse {
        let body = try JSONSerialization.data(withJSONObject: [
            "journal_ids": journalIds,
            "period": period,
            "period_year": periodYear
        ])
        let data = try await request("/bulk_book_journal_entries", method: "POST", body: body)
        do {
            return try decoder.decode(BulkJournalResponse.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchCurrentActivePeriod() async throws -> CurrentPeriod {
        let data = try await request("/get_current_active_period")
        do {
            return try decoder.decode(CurrentPeriod.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchMyProfile() async throws -> UserProfile {
        let data = try await request("/profile")
        do {
            return try decoder.decode(UserProfile.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }
}
