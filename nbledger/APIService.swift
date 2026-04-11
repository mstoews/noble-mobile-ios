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
    var transactionDate: String
    var transactionDate2: String

    private enum CodingKeys: String, CodingKey {
        case transactionDate = "transaction_date"
        case transactionDate2 = "transaction_date_2"
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

struct UpdatePaymentRequest: Codable {
    var transactionId: String
    var status: String?
    var cashChild: Double?
    var payableChild: Double?
    var vendorId: String?
    var invoiceId: String?
    var description: String?
    var amount: Double?
    var amountPaid: Double?
    var payment: Double?
    var transactionDate: String?
    var dueDate: String?
    var datePaid: String?
    var orderNo: String?
    var paymentReference: String?
    var reference: String?
    var gstAmount: Double?
    var pstAmount: Double?
    var adjustmentAmt: Double?
    var rebateAmt: Double?
    var remainderAmt: Double?
    var updateDate: String?
    var updateUser: String?

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
        case updateDate = "update_date"
        case updateUser = "update_user"
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
    let transactionId: Int
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


// MARK: - Service

@Observable
class APIService {
    var token: String
    var refreshToken: String
    var onUnauthorized: (() -> Void)?
    var onSessionExpired: (() -> Void)?

    // private let baseURL = "https://api.nobleledger.com/public/v1"
    private let baseURL = "http://localhost:8080/public/v1"

    
    private let decoder = JSONDecoder()

    init() {
        self.token = UserDefaults.standard.string(forKey: "authToken") ?? ""
        self.refreshToken = UserDefaults.standard.string(forKey: "refreshToken") ?? ""
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

        let (data, response) = try await URLSession.shared.data(for: req)
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
        let data = try await request("/read_open_journal_details")
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
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let journalNo = json["journal_id"] as? Int {
                return journalNo
            }
            throw APIError.decodingFailed
        } catch let error as APIError {
            throw error
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
        let data = try await request("/read_template/\(reference)")
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

    func fetchPaymentById(_ id: String) async throws -> Payment {
        let data = try await request("/read_payment/\(id)")
        do {
            return try decoder.decode(Payment.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func updatePayment(_ params: UpdatePaymentRequest) async throws {
        let body = try JSONEncoder().encode(params)
        _ = try await request("/update_payment", method: "POST", body: body)
    }

    func deletePayment(id: String) async throws {
        _ = try await request("/delete_payment/\(id)", method: "DELETE")
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
        _ = try await request("/api/exchange_public_token", method: "POST", body: body)
    }

    func fetchBankAccounts() async throws -> [BankAccount] {
        let data = try await request("/api/accounts")
        do {
            return try decoder.decode([BankAccount].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    func fetchBankTransactions() async throws -> [BankTransaction] {
        let data = try await request("/api/bank_transactions")
        do {
            return try decoder.decode([BankTransaction].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    // MARK: - AI Agent

    func sendAgentMessage(messages: [ChatMessage]) async throws -> String {
        let body = try JSONEncoder().encode(AgentRequest(messages: messages))
        let data = try await request("/agent/chat", method: "POST", body: body)
        do {
            let response = try decoder.decode(AgentResponse.self, from: data)
            return response.message
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
}
