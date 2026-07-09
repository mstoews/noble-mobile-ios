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
    let id: Int
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

    var displayName: String { shortName ?? name }

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
    }
}

/// Request body for the legacy uuid-keyed AP transaction create endpoint
/// (`/create_ap_transaction`). Amounts are decimal strings and dates are
/// RFC3339 timestamps, per the Go server's `createAPTransactionReq`.
struct CreateApTransactionRequest: Codable {
    var vendorId: String
    var transactionDate: String
    var amount: String
    var description: String
    var status: String? = nil
    var invoiceId: String? = nil
    var orderNo: String? = nil
    var reference: String? = nil
    var dueDate: String? = nil

    private enum CodingKeys: String, CodingKey {
        case vendorId = "vendor_id"
        case transactionDate = "transaction_date"
        case amount, description, status
        case invoiceId = "invoice_id"
        case orderNo = "order_no"
        case reference
        case dueDate = "due_date"
    }
}

struct Payment: Identifiable, Codable {
    let transactionId: String
    let status: String?
    let cashChild: Double?
    let payableChild: Double?
    let vendorId: String?
    let invoiceId: String?
    let description: String?
    let amount: Double?
    let amountPaid: Double?
    let payment: Double?
    let transactionDate: String?
    let dueDate: String?
    let datePaid: String?
    let orderNo: String?
    let paymentReference: String?
    let reference: String?
    let gstAmount: Double?
    let pstAmount: Double?
    let adjustmentAmt: Double?
    let rebateAmt: Double?
    let remainderAmt: Double?
    let createDate: String?
    let createUser: String?
    let updateDate: String?
    let updateUser: String?

    var id: String { transactionId }

    var displayDescription: String {
        description ?? "Payment"
    }

    var remainingBalance: Double {
        (amount ?? 0) - (amountPaid ?? 0)
    }

    private enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case status
        case cashChild = "cash_child"
        case payableChild = "payable_child"
        case vendorId = "vendor_id"
        case invoiceId = "invoice_id"
        case description, amount, payment
        case amountPaid = "amount_paid"
        case transactionDate = "transaction_date"
        case dueDate = "due_date"
        case datePaid = "date_paid"
        case orderNo = "order_no"
        case paymentReference = "payment_reference"
        case reference
        case gstAmount = "gst_amount"
        case pstAmount = "pst_amount"
        case adjustmentAmt = "adjustment_amt"
        case rebateAmt = "rebate_amt"
        case remainderAmt = "remainder_amt"
        case createDate = "create_date"
        case createUser = "create_user"
        case updateDate = "update_date"
        case updateUser = "update_user"
    }
}

struct PaymentEvent: Identifiable, Codable {
    let transactionId: String
    let transactionEventId: Int
    let transactionType: String?
    let createDate: String?
    let createUser: String?
    let updateDate: String?
    let updateUser: String?

    var id: String { "\(transactionId)-\(transactionEventId)" }

    private enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case transactionEventId = "transaction_event_id"
        case transactionType = "transaction_type"
        case createDate = "create_date"
        case createUser = "create_user"
        case updateDate = "update_date"
        case updateUser = "update_user"
    }
}

struct PaymentDetail: Identifiable, Codable {
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
    let createDate: String?
    let createUser: String?

    var id: String { "\(transactionId)-\(transactionItemId)" }

    private enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case transactionItemId = "transaction_item_id"
        case account, child, `class`, description, fund, reference, debit, credit
        case createDate = "create_date"
        case createUser = "create_user"
    }
}

struct PaymentTxnDetail: Identifiable, Codable {
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
    let createDate: String?
    let createUser: String?

    var id: String { "\(transactionId)-\(transactionItemId)" }

    private enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case transactionItemId = "transaction_item_id"
        case account, child, `class`, description, fund, reference, debit, credit
        case createDate = "create_date"
        case createUser = "create_user"
    }
}

/// Request body for recording a payment against a legacy AP transaction
/// (`/update_ap_transaction_amount_paid`). `amountPaid` is the new running
/// total paid (decimal string); `datePaid` is an RFC3339 timestamp.
struct UpdateApTransactionAmountPaidRequest: Codable {
    var id: String
    var amountPaid: String
    var datePaid: String

    private enum CodingKeys: String, CodingKey {
        case id
        case amountPaid = "amount_paid"
        case datePaid = "date_paid"
    }
}

struct ReadPaymentsByDateRequest: Codable {
    var transactionDate: String
    var transactionDate2: String

    private enum CodingKeys: String, CodingKey {
        case transactionDate = "transaction_date"
        case transactionDate2 = "transaction_date_2"
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
    let updatedAt: String?

    var id: String { "\(transactionId)-\(transactionItemId)" }

    private enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case transactionItemId = "transaction_item_id"
        case account, child, `class`, description, fund, reference, debit, credit
        case amountReceived = "amount_received"
        case remainder
        case createDate = "create_date"
        case createUser = "create_user"
        case updatedAt = "updated_at"
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

    private enum CodingKeys: String, CodingKey {
        case id
        case amountReceived = "amount_received"
        case datePaid = "date_paid"
        case updateUser = "update_user"
    }
}

struct UpdateArStatusRequest: Codable {
    var id: String
    var status: String?
    var updateUser: String?

    private enum CodingKeys: String, CodingKey {
        case id, status
        case updateUser = "update_user"
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
    let balances: Balances?

    /// Nested balance object as returned by Plaid's `AccountBase.balances`.
    struct Balances: Codable {
        let available: Double?
        let current: Double?
        let limit: Double?
        let isoCurrencyCode: String?

        private enum CodingKeys: String, CodingKey {
            case available, current, limit
            case isoCurrencyCode = "iso_currency_code"
        }
    }

    var id: String { accountId }

    // Convenience accessors flattening the nested Plaid balance object.
    var currentBalance: Double? { balances?.current }
    var availableBalance: Double? { balances?.available }
    var isoCurrencyCode: String? { balances?.isoCurrencyCode }
    /// Not provided by the Plaid `/api/accounts` payload.
    var institutionName: String? { nil }

    var displayName: String {
        officialName ?? name ?? "Account ••\(mask ?? "")"
    }

    private enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case name
        case officialName = "official_name"
        case type, subtype, mask, balances
    }
}

/// Wrapper for the Plaid `/api/accounts` response: `{ "accounts": [...] }`.
private struct BankAccountsResponse: Codable {
    let accounts: [BankAccount]
}

/// Wrapper for the Plaid `/api/transactions` response: `{ "latest_transactions": [...] }`.
private struct BankTransactionsResponse: Codable {
    let latestTransactions: [BankTransaction]

    private enum CodingKeys: String, CodingKey {
        case latestTransactions = "latest_transactions"
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
    let status: String
    let funds: [AgingBillFund]
    let booked: Bool
    let approvalStatus: String
    let updateDate: String?

    var id: Int { journalId }

    private enum CodingKeys: String, CodingKey {
        case journalId = "journal_id"
        case vendorId = "vendor_id"
        case invoiceNumber = "invoice_number"
        case description
        case transactionDate = "transaction_date"
        case dueDate = "due_date"
        case amount
        case amountPaid = "amount_paid"
        case remainder, status, funds, booked
        case approvalStatus = "approval_status"
        case updateDate = "update_date"
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
    let name: String?
    let email: String?
    let role: String?
    let title: String?

    private enum CodingKeys: String, CodingKey {
        case uid, name, email, role, title
    }
}

// MARK: - Service

@Observable
class APIService {
    var token: String
    var refreshToken: String
    var tenant: String
    var onUnauthorized: (() -> Void)?
    var onSessionExpired: (() -> Void)?

    private let host = "https://api.nobleledger.com"
    // private let host = "http://localhost:8080"

    private var baseURL: String {
        let slug = tenant.isEmpty ? "public" : tenant
        return "\(host)/\(slug)/v1"
    }

    let decoder = JSONDecoder()

    /// URLSession used for API traffic. Injectable so tests can install a
    /// stubbed URLProtocol; production callers use the default.
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        self.token = UserDefaults.standard.string(forKey: "authToken") ?? ""
        self.refreshToken = UserDefaults.standard.string(forKey: "refreshToken") ?? ""
        self.tenant = UserDefaults.standard.string(forKey: "tenant") ?? ""
    }

    private func handleUnauthorized() {
        let hadRefreshToken = !refreshToken.isEmpty
        token = ""
        UserDefaults.standard.removeObject(forKey: "authToken")

        if hadRefreshToken {
            // Refresh token may still be valid — lock the session so the user
            // can re-authenticate with biometrics and retry the refresh.
            onSessionExpired?()
        } else {
            // No refresh token — full logout required
            refreshToken = ""
            UserDefaults.standard.removeObject(forKey: "refreshToken")
            onUnauthorized?()
        }
    }

    // MARK: - Request helper (internal so endpoint extensions can use it)

    func request(_ path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
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

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.serverError(statusCode: 0, message: "Invalid server response.")
        }
        guard http.statusCode != 401 else {
            handleUnauthorized()
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

    /// Public entry point for re-authenticating after session expiry.
    func refreshAccessToken() async throws {
        try await performTokenRefresh()
    }

    /// Public Firebase web API key — the same key the server's /api/login
    /// proxies through. Firebase API keys identify the project and are not
    /// secrets; access control happens on the tokens themselves.
    private static let firebaseAPIKey = "AIzaSyBna-NbuCBVnO8xN0n8np4jpBt2FxaYGoQ"

    private func performTokenRefresh() async throws {
        guard !refreshToken.isEmpty else { throw APIError.unauthorized }

        // Login (email/password and Apple) issues Firebase tokens, which are
        // refreshed against Google's secure token service. The Noble server
        // has no refresh route for them — its /v1/auth/refresh rotates the
        // SPA's opaque session tokens, a different credential type.
        guard let url = URL(string: "https://securetoken.googleapis.com/v1/token?key=\(Self.firebaseAPIKey)") else {
            throw APIError.unauthorized
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
        ]
        req.httpBody = form.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.unauthorized
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newToken = json["id_token"] as? String else {
            throw APIError.unauthorized
        }

        token = newToken
        UserDefaults.standard.set(newToken, forKey: "authToken")

        if let newRefresh = json["refresh_token"] as? String {
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
            print("fetchJournalById decode error: \(error)")
            if let raw = String(data: data, encoding: .utf8) {
                print("fetchJournalById raw response (first 500): \(String(raw.prefix(500)))")
            }
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

    func fetchApTransactions() async throws -> [Payment] {
        let data = try await request("/read_ap_transactions")
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
        let body = try JSONEncoder().encode(params)
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
        let body = try JSONEncoder().encode(params)
        _ = try await request("/update_ar_customer", method: "POST", body: body)
    }

    func deleteArCustomer(id: String) async throws {
        _ = try await request("/delete_ar_customer/\(id)", method: "DELETE")
    }

    func createPayment(_ params: CreateApTransactionRequest) async throws {
        let body = try JSONEncoder().encode(params)
        _ = try await request("/create_ap_transaction", method: "POST", body: body)
    }

    func fetchPaymentById(_ id: String) async throws -> Payment {
        let data = try await request("/read_payment/\(id)")
        do {
            return try decoder.decode(Payment.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func updatePayment(_ params: UpdateApTransactionAmountPaidRequest) async throws {
        let body = try JSONEncoder().encode(params)
        _ = try await request("/update_ap_transaction_amount_paid", method: "POST", body: body)
    }

    func deletePayment(id: String) async throws {
        _ = try await request("/delete_ap_transaction/\(id)", method: "DELETE")
    }

    func fetchPaymentsByDate(from: String, to: String) async throws -> [Payment] {
        let params = ReadPaymentsByDateRequest(transactionDate: from, transactionDate2: to)
        let body = try JSONEncoder().encode(params)
        let data = try await request("/read_payments_by_date", method: "POST", body: body)
        do {
            return try decoder.decode([Payment].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    // MARK: - Payment Events

    func fetchPaymentEvents(transactionId: String) async throws -> [PaymentEvent] {
        let data = try await request("/read_payment_events/\(transactionId)")
        do {
            return try decoder.decode([PaymentEvent].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    // MARK: - Payment Details

    func fetchPaymentDetails(transactionId: String) async throws -> [PaymentDetail] {
        let data = try await request("/read_payment_details/\(transactionId)")
        do {
            return try decoder.decode([PaymentDetail].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    // MARK: - Payment Transaction Details

    func fetchPaymentTxnDetails(transactionId: String) async throws -> [PaymentTxnDetail] {
        let data = try await request("/read_payment_txn_details/\(transactionId)")
        do {
            return try decoder.decode([PaymentTxnDetail].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    // MARK: - Plaid / Banking

    func createLinkToken() async throws -> String {
        let data = try await request("/api/create_link_token", method: "POST")
        do {
            let response = try decoder.decode(LinkTokenResponse.self, from: data)
            return response.linkToken
        } catch {
            throw APIError.decodingFailed
        }
    }

    func exchangePublicToken(_ publicToken: String) async throws {
        let body = try JSONEncoder().encode(ExchangeTokenRequest(publicToken: publicToken))
        _ = try await request("/get_access_token", method: "POST", body: body)
    }

    func fetchBankAccounts() async throws -> [BankAccount] {
        let data = try await request("/api/accounts")
        do {
            return try decoder.decode(BankAccountsResponse.self, from: data).accounts
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchBankTransactions() async throws -> [BankTransaction] {
        let data = try await request("/api/transactions")
        do {
            return try decoder.decode(BankTransactionsResponse.self, from: data).latestTransactions
        } catch {
            throw APIError.decodingFailed
        }
    }

    // MARK: - AI Agent

    /// Sends a chat message and collects the full SSE-streamed response.
    func sendAgentMessage(messages: [ChatMessage]) async throws -> String {
        guard let url = URL(string: baseURL + "/agent/chat") else {
            throw APIError.serverError(statusCode: 0, message: "Invalid URL.")
        }

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
        let body = try JSONEncoder().encode(params)
        _ = try await request("/update_ar_transaction_amount_received", method: "POST", body: body)
    }

    func updateArTransactionStatus(_ params: UpdateArStatusRequest) async throws {
        let body = try JSONEncoder().encode(params)
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
