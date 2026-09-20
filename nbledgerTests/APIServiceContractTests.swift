//
//  APIServiceContractTests.swift
//  nbledgerTests
//
//  Contract tests for the A3/A4 realignment (.claude/plans/api-realignment):
//  the Banking tab's rerouted Plaid/cash-movement reads, and the OCC tokens
//  the master-data writes now require.
//

import Foundation
import Testing
@testable import nbledger


// MARK: - Fixtures

/// Keys this suite's responder and recording in the shared stub.
private let stubSession = "contract"

@MainActor
private func makeService() -> APIService {
    let service = StubURLProtocol.makeService(stubSession, token: "test-token")
    return service
}

private let bankAccountID = "019e3944-d510-736f-b64f-8e130e47b937"
private let vendorID = "019a7f3e-1111-7abc-9def-0123456789ab"
private let txnID = "019b8c4f-2222-7abc-9def-0123456789ab"

/// `bank_account` rows — note there is no balance anywhere in this payload.
private let bankAccountsJSON = """
[
  {
    "id": "\(bankAccountID)",
    "name": "Operating Chequing",
    "gl_child": 1010,
    "active": true,
    "currency": "CAD",
    "fund": "OPERATING",
    "institution_name": "RBC Royal Bank",
    "mask": "4321",
    "plaid_account_id": "abc123",
    "plaid_item_id": "item-1",
    "subtype": "chequing"
  }
]
""".data(using: .utf8)!

/// `+` is an inflow and `-` an outflow — the opposite of Plaid's convention.
private let cashMovementsJSON = """
[
  {
    "id": "aaaaaaaa-0000-4000-8000-000000000001",
    "bank_account_id": "\(bankAccountID)",
    "amount": 2500.00,
    "currency": "CAD",
    "date": "2026-09-10",
    "status": "posted",
    "description": "Assessment receipt",
    "reference": "DEP-88",
    "journal_id": 4711,
    "party_id": null,
    "updated_at": "2026-09-10T18:04:00Z"
  },
  {
    "id": "aaaaaaaa-0000-4000-8000-000000000002",
    "bank_account_id": "\(bankAccountID)",
    "amount": -1250.00,
    "currency": "CAD",
    "date": "2026-09-12",
    "status": "pending",
    "description": null,
    "reference": null,
    "journal_id": null,
    "party_id": null,
    "updated_at": "2026-09-12T09:00:00Z"
  }
]
""".data(using: .utf8)!


/// A freshly linked account: `gl_child` null (no mapping yet) and balances
/// present. Both were wrong in the first cut of this model — `gl_child` was
/// non-optional (so this row threw) and the balances were left out entirely.
private let unmappedBankAccountJSON = """
[
  {
    "id": "019e3944-d510-736f-b64f-8e130e47b937", "tenant": "public",
    "name": "New Savings", "gl_child": null, "active": true, "currency": "CAD",
    "fund": null, "institution_name": "RBC Royal Bank", "mask": "9911",
    "plaid_account_id": "acct-9", "plaid_item_id": "item-9", "subtype": "savings",
    "balance_current": 18234.55, "balance_available": 18000.00,
    "balance_as_of": "2026-09-19T06:00:00Z"
  }
]
""".data(using: .utf8)!

/// The same row with the balances as decimal STRINGS — pgtype.Numeric can
/// serialize either way, which is why this model decodes them flexibly.
private let stringBalanceBankAccountJSON = """
[
  {
    "id": "019e3944-d510-736f-b64f-8e130e47b937", "tenant": "public",
    "name": "Operating", "gl_child": 1010, "active": true, "currency": "CAD",
    "balance_current": "2500.75", "balance_available": "2400.00"
  }
]
""".data(using: .utf8)!

private let vendorJSON = """
{
  "id": "\(vendorID)",
  "name": "Hydro One",
  "short_name": "HYDRO",
  "status": "ACTIVE",
  "update_date": "2026-09-01",
  "update_user": "MOBILE",
  "updated_at": "2026-09-01T12:00:00.123456Z"
}
""".data(using: .utf8)!

private let arTransactionJSON = """
{
  "id": "\(txnID)",
  "customer_id": "CUST-1",
  "status": "OPEN",
  "amount": 1000.00,
  "amount_received": 250.00,
  "updated_at": "2026-09-05T08:30:00Z"
}
""".data(using: .utf8)!

private let occStaleJSON = Data(#"{"error":"stale","current_updated_at":"2026-09-19T14:00:00.5Z"}"#.utf8)


/// `GlJournalHeader` rows. `booked` survived the 2026-09 "stop returning
/// booked" change — that dropped it from the AP bill/aging responses only —
/// so the open-journal count may keep reading it.
private let journalHeadersJSON = """
[
  {"journal_id": 4711, "description": "September utilities", "booked": false, "status": "OPEN", "period": 9, "period_year": 2026},
  {"journal_id": 4712, "description": "Posted entry", "booked": true, "status": "CLOSED", "period": 9, "period_year": 2026},
  {"journal_id": 4713, "description": "Cancelled entry", "booked": false, "status": "CANCELLED", "period": 9, "period_year": 2026}
]
""".data(using: .utf8)!


/// `read_aging_bills_by_period` rows, as `api/ap_aging.go` sends them: note
/// `journal_status` and NO `booked`.
private let agingBillsJSON = """
[
  {
    "journal_id": 5001, "vendor_id": "v-1", "invoice_number": "INV-9",
    "description": "September hydro", "transaction_date": "2026-09-02",
    "due_date": "2026-09-30", "amount": 1200.00, "amount_paid": 0,
    "remainder": 1200.00, "status": "OPEN", "journal_status": "CLOSED",
    "approval_status": "APPROVED", "update_date": "2026-09-02T10:00:00Z",
    "funds": [{"fund": "OPERATING", "amount": 1200.00, "amount_paid": 0, "remainder": 1200.00}]
  },
  {
    "journal_id": 5002, "vendor_id": "v-2", "invoice_number": "INV-10",
    "description": "Draft bill", "transaction_date": "2026-09-05",
    "due_date": "2026-10-05", "amount": 300.00, "amount_paid": 0,
    "remainder": 300.00, "status": "OPEN", "journal_status": "OPEN",
    "approval_status": "PENDING", "update_date": null, "funds": []
  },
  {
    "journal_id": 5003, "vendor_id": "v-1", "invoice_number": "INV-8",
    "description": "Settled bill", "transaction_date": "2026-08-01",
    "due_date": "2026-08-31", "amount": 500.00, "amount_paid": 500.00,
    "remainder": 0, "status": "CLOSED", "journal_status": "CLOSED",
    "approval_status": "APPROVED", "update_date": null, "funds": []
  }
]
""".data(using: .utf8)!


/// `read_payments_by_date` rows — the receipts-shaped payments table. Only the
/// first is confirmable: the second is already posted, the third reversed, the
/// fourth is AR.
private let paymentsByDateJSON = """
[
  {"id": 3001, "kind": "AP", "party_id": "v-1", "party_name": "ACME Furniture",
   "receipt_no": "R-77", "reference": "CHQ-4001", "receipt_date": "2026-09-20",
   "amount": 5000.00, "currency": "USD", "method": "CHQ",
   "deposit_account": "1010", "deposit_account_desc": "Reserve Fund Bank Account",
   "approval_state": "PENDING", "posted_journal_id": null, "reversed": false},
  {"id": 3002, "kind": "AP", "party_id": "v-2", "amount": 100.00,
   "approval_state": "APPROVED", "posted_journal_id": 8100, "reversed": false},
  {"id": 3003, "kind": "AP", "party_id": "v-3", "amount": 250.00,
   "approval_state": "APPROVED", "posted_journal_id": null, "reversed": true},
  {"id": 3004, "kind": "AR", "party_id": "c-1", "amount": 900.00,
   "approval_state": "PENDING", "posted_journal_id": null, "reversed": false}
]
""".data(using: .utf8)!

/// `db.PaymentTxnDetail` — the GL lines the web built.
private let paymentTxnLinesJSON = """
[
  {"id": 1, "transaction_id": 3001, "account_code": "2000", "account_name": "Accounts Payable",
   "description": "Payment INV-9", "fund": "OPERATING", "debit": 5000.00, "credit": 0},
  {"id": 2, "transaction_id": 3001, "account_code": "1010", "account_name": "Reserve Fund Bank Account",
   "description": "Payment INV-9", "fund": "OPERATING", "debit": 0, "credit": 5000.00}
]
""".data(using: .utf8)!

/// `db.PaymentDetail` — charge_id is the bill's journal id.
private let paymentApplyLinesJSON = """
[
  {"id": 1, "transaction_id": 3001, "charge_id": "5001", "charge_no": "INV-9",
   "charge_date": "2026-09-02", "charge_description": "Rental Furniture",
   "fund": "OPERATING", "original_amount": 5000.00, "outstanding_amount": 5000.00,
   "apply_amount": 5000.00, "discount_amount": 0}
]
""".data(using: .utf8)!

private let billPaymentsJSON = """
[{"payment_transaction_id": "pt-1", "payment_date": "2026-09-15", "applied_amount": 400.00, "apply_lines": 2}]
""".data(using: .utf8)!

private let billSchedulesJSON = """
{
  "bill_journal_id": 5001,
  "schedules": [
    {"id": 71, "bill_journal_id": 5001, "amount": 800.00, "scheduled_for": "2026-09-28",
     "method": "EFT", "status": "SCHEDULED", "source_account": 1000, "source_child": 1010,
     "posted_journal_id": null, "cancel_date": null, "create_date": "2026-09-19"},
    {"id": 72, "bill_journal_id": 5001, "amount": 100.00, "scheduled_for": "2026-09-20",
     "method": "CHEQUE", "status": "CANCELLED", "source_account": 1000, "source_child": 1010,
     "posted_journal_id": null, "cancel_date": "2026-09-19", "create_date": "2026-09-18"}
  ]
}
""".data(using: .utf8)!

@MainActor
private func vendorUpdate(expectedUpdatedAt: String) -> UpdateApVendorRequest {
    UpdateApVendorRequest(
        id: vendorID,
        name: "Hydro One",
        updateDate: "2026-09-19",
        updateUser: "MOBILE",
        expectedUpdatedAt: expectedUpdatedAt
    )
}

// MARK: - Tests

// @MainActor because the nbledger module builds with default MainActor
// isolation. .serialized on the OUTER suite matters here: all three nested
// suites share one `stubSession` id, so they must not interleave.
@MainActor
@Suite(.serialized)
struct APIServiceContractTests {

    // MARK: A3 — Banking

    // @MainActor is not inherited from the enclosing suite; each nested type
    // needs it to reach the main-actor-isolated fixtures.
    @MainActor
    @Suite(.serialized)
    struct Banking {

        @Test func createLinkTokenPostsToTheRenamedRoute() async throws {
            StubURLProtocol.install(stubSession) { _ in (200, Data(#"{"link_token":"link-sandbox-1","expiration":"2026-09-19T15:00:00Z"}"#.utf8)) }
            let service = makeService()

            let token = try await service.createLinkToken()

            let req = try #require(StubURLProtocol.recorded(stubSession).first)
            // Was /api/create_link_token, which no longer exists.
            #expect(req.url.absoluteString == "https://api.nobleledger.com/public/v1/plaid_link_token")
            #expect(req.method == "POST")
            // A new link sends no body: the server reads io.EOF as "new link".
            #expect(req.body == nil || req.body?.isEmpty == true)
            #expect(token == "link-sandbox-1")
        }

        @Test func createLinkTokenSendsItemIDForUpdateMode() async throws {
            StubURLProtocol.install(stubSession) { _ in (200, Data(#"{"link_token":"link-update-1"}"#.utf8)) }
            let service = makeService()

            _ = try await service.createLinkToken(itemID: "item-42")

            let req = try #require(StubURLProtocol.recorded(stubSession).first)
            #expect(req.json?["item_id"] as? String == "item-42")
        }

        @Test func fetchBankAccountsReadsTheTenantBankAccountRoute() async throws {
            StubURLProtocol.install(stubSession) { _ in (200, bankAccountsJSON) }
            let service = makeService()

            let accounts = try await service.fetchBankAccounts()

            let req = try #require(StubURLProtocol.recorded(stubSession).first)
            // Was GET /api/accounts, which is gone; only the PUT mapping route
            // survives under that prefix.
            #expect(req.url.absoluteString == "https://api.nobleledger.com/public/v1/list_bank_accounts")
            #expect(req.method == "GET")

            let account = try #require(accounts.first)
            #expect(account.id == bankAccountID)
            #expect(account.glChild == 1010)
            #expect(account.active)
            #expect(account.institutionName == "RBC Royal Bank")
            #expect(account.fund == "OPERATING")
            #expect(account.displayName == "Operating Chequing")
        }

        @Test func fetchCashMovementsScopesByAccountAndRequiresADateWindow() async throws {
            StubURLProtocol.install(stubSession) { _ in (200, cashMovementsJSON) }
            let service = makeService()
            let from = try #require(ISO8601DateFormatter().date(from: "2026-06-21T00:00:00Z"))
            let to = try #require(ISO8601DateFormatter().date(from: "2026-09-19T00:00:00Z"))

            _ = try await service.fetchCashMovements(bankAccountID: bankAccountID, from: from, to: to)

            let req = try #require(StubURLProtocol.recorded(stubSession).first)
            #expect(req.method == "GET")
            #expect(req.url.path == "/public/v1/cash_movements/by_account/\(bankAccountID)")
            // dateFrom/dateTo are required by the server, so the client must
            // always send a window rather than an open-ended "recent" read.
            let query = try #require(req.url.query)
            #expect(query.contains("dateFrom=2026-06-21"))
            #expect(query.contains("dateTo=2026-09-19"))
            #expect(!query.contains("outstanding"))
        }

        @Test func fetchCashMovementsPassesTheOutstandingFilter() async throws {
            StubURLProtocol.install(stubSession) { _ in (200, cashMovementsJSON) }
            let service = makeService()

            _ = try await service.fetchCashMovements(
                bankAccountID: bankAccountID, from: Date(), to: Date(), outstandingOnly: true
            )

            let req = try #require(StubURLProtocol.recorded(stubSession).first)
            #expect(req.url.query?.contains("outstanding=true") == true)
        }

        @Test func cashMovementSignConventionIsInvertedFromPlaid() async throws {
            StubURLProtocol.install(stubSession) { _ in (200, cashMovementsJSON) }
            let service = makeService()

            let movements = try await service.fetchCashMovements(
                bankAccountID: bankAccountID, from: Date(), to: Date()
            )
            #expect(movements.count == 2)

            // + is an inflow here; the retired Plaid payload meant the opposite,
            // so reading this backwards would render every row's direction and
            // colour inverted.
            let inflow = movements[0]
            #expect(inflow.amount == 2500)
            #expect(inflow.isMoneyIn)
            #expect(!inflow.isOutstanding)
            #expect(inflow.displayName == "Assessment receipt")

            let outflow = movements[1]
            #expect(outflow.amount == -1250)
            #expect(!outflow.isMoneyIn)
            // journal_id IS NULL is the reconciliation-status source of truth.
            #expect(outflow.isOutstanding)
            // description and reference are both null while outstanding.
            #expect(outflow.displayName == "Withdrawal")
        }

        @Test func unmappedBankAccountDecodesWithBalances() async throws {
            StubURLProtocol.install(stubSession) { _ in (200, unmappedBankAccountJSON) }
            let service = StubURLProtocol.makeService(stubSession)

            let accounts = try await service.fetchBankAccounts()
            let account = try #require(accounts.first)

            // gl_child is pgtype.Int4 in the row: a linked-but-unmapped account
            // is normal until someone PUTs a mapping, and decoding it as
            // non-optional threw and blanked the whole tab.
            #expect(account.glChild == nil)
            #expect(!account.isMapped)

            // The row has carried balances all along; the OpenAPI BankAccount
            // schema omits them, which is what led an earlier pass to conclude
            // the API had no balance side at all.
            #expect(account.balanceCurrent == 18234.55)
            #expect(account.balanceAvailable == 18000.00)
            #expect(account.balanceAsOf == "2026-09-19T06:00:00Z")
        }

        @Test func bankBalancesDecodeFromStringsToo() async throws {
            StubURLProtocol.install(stubSession) { _ in (200, stringBalanceBankAccountJSON) }
            let service = StubURLProtocol.makeService(stubSession)

            let account = try #require(try await service.fetchBankAccounts().first)
            #expect(account.glChild == 1010)
            #expect(account.balanceCurrent == 2500.75)
            #expect(account.balanceAvailable == 2400.00)
        }

        @Test func syncBankTransactionsPostsRatherThanGets() async throws {
            StubURLProtocol.install(stubSession) { _ in (200, Data("{}".utf8)) }
            let service = makeService()

            try await service.syncBankTransactions(itemID: "item-42")

            let req = try #require(StubURLProtocol.recorded(stubSession).first)
            // The client used to GET this path, which is a 405: the route is a
            // POST, and it triggers a sync rather than returning a list.
            #expect(req.method == "POST")
            #expect(req.url.path == "/public/v1/api/transactions")
            #expect(req.url.query == "item_id=item-42")
        }
    }

    // MARK: A4 — OCC tokens

    // @MainActor is not inherited from the enclosing suite; each nested type
    // needs it to reach the main-actor-isolated fixtures.
    @MainActor
    @Suite(.serialized)
    struct OptimisticConcurrency {

        @Test func vendorReadCarriesTheOCCToken() async throws {
            StubURLProtocol.install(stubSession) { _ in (200, vendorJSON) }
            let service = makeService()

            let vendor = try await service.fetchApVendor(id: vendorID)

            // updated_at is a distinct column from update_date, and the spec's
            // read schema omits it — the handler returns the full row.
            #expect(vendor.updatedAt == "2026-09-01T12:00:00.123456Z")
            #expect(vendor.updateDate == "2026-09-01")
        }

        @Test func updateSendsTheTokenTheCallerHeldWithoutRereading() async throws {
            StubURLProtocol.install(stubSession) { _ in (200, vendorJSON) }
            let service = makeService()

            try await service.updateApVendor(vendorUpdate(expectedUpdatedAt: "2026-09-01T12:00:00.123456Z"))

            let requests = StubURLProtocol.recorded(stubSession)
            // One request: the caller already had the token, so no re-read.
            #expect(requests.count == 1)
            let req = try #require(requests.first)
            #expect(req.url.path == "/public/v1/update_ap_vendor")
            #expect(req.json?["expected_updated_at"] as? String == "2026-09-01T12:00:00.123456Z")
        }

        @Test func updateRereadsTheRowWhenTheCallerHasNoToken() async throws {
            // Both the re-read and the write answer with the row; the point
            // of the test is the request sequence, not the payloads.
            StubURLProtocol.install(stubSession) { _ in (200, vendorJSON) }
            let service = makeService()

            try await service.updateApVendor(vendorUpdate(expectedUpdatedAt: ""))

            let requests = StubURLProtocol.recorded(stubSession)
            #expect(requests.count == 2)
            // Re-read first, then write with what it returned — never a
            // synthesised timestamp, which is the whole point of the token.
            #expect(requests[0].url.path == "/public/v1/get_ap_vendor/\(vendorID)")
            #expect(requests[1].url.path == "/public/v1/update_ap_vendor")
            #expect(requests[1].json?["expected_updated_at"] as? String == "2026-09-01T12:00:00.123456Z")
        }

        @Test func updateRefusesToWriteWhenNoTokenCanBeResolved() async throws {
            // A row with no updated_at at all: there is nothing safe to send.
            StubURLProtocol.install(stubSession) { _ in
                (200, Data(#"{"id":"\#(vendorID)","name":"Hydro One"}"#.utf8))
            }
            let service = makeService()

            await #expect(throws: APIError.self) {
                try await service.updateApVendor(vendorUpdate(expectedUpdatedAt: ""))
            }
            let requests = StubURLProtocol.recorded(stubSession)
            #expect(requests.count == 1)
            #expect(requests[0].url.path == "/public/v1/get_ap_vendor/\(vendorID)")
        }

        @Test func staleWriteSurfacesAsAConflictCarryingTheCurrentToken() async throws {
            StubURLProtocol.install(stubSession) { _ in (409, occStaleJSON) }
            let service = makeService()

            do {
                try await service.updateApVendor(vendorUpdate(expectedUpdatedAt: "2026-09-01T12:00:00Z"))
                Issue.record("expected the stale write to be refused")
            } catch APIError.conflict(let currentUpdatedAt) {
                // The server hands back the row's present token so a client can
                // re-read; surfacing the raw body would say only "stale".
                #expect(currentUpdatedAt == "2026-09-19T14:00:00.5Z")
            }
        }

        @Test func arReceiptWriteCarriesTheToken() async throws {
            StubURLProtocol.install(stubSession) { _ in (200, arTransactionJSON) }
            let service = makeService()

            try await service.updateArTransactionAmountReceived(
                UpdateArAmountReceivedRequest(
                    id: txnID,
                    amountReceived: 500,
                    datePaid: "2026-09-19",
                    updateUser: "MOBILE",
                    expectedUpdatedAt: "2026-09-05T08:30:00Z"
                )
            )

            let req = try #require(StubURLProtocol.recorded(stubSession).first)
            #expect(req.url.path == "/public/v1/update_ar_transaction_amount_received")
            #expect(req.json?["expected_updated_at"] as? String == "2026-09-05T08:30:00Z")
            #expect(req.json?["amount_received"] as? Double == 500)
        }
    }

    // MARK: A5 — Journal lifecycle

    @MainActor
    @Suite(.serialized)
    struct JournalLifecycle {

        @Test func journalHeadersStillCarryBooked() async throws {
            StubURLProtocol.install(stubSession) { _ in (200, journalHeadersJSON) }
            let service = makeService()

            let headers = try await service.fetchJournalHeaders()

            let req = try #require(StubURLProtocol.recorded(stubSession).first)
            #expect(req.url.path == "/public/v1/read_journal_header")

            // The open-journal count in AgentChatView filters on both fields;
            // if `booked` ever stops shipping here it silently counts posted
            // entries as open, so pin the decode.
            #expect(headers.map(\.booked) == [false, true, false])
            #expect(headers.map { $0.status ?? "" } == ["OPEN", "CLOSED", "CANCELLED"])

            let open = headers.filter { ($0.status ?? "") == "OPEN" && $0.booked != true }
            #expect(open.map(\.journalId) == [4711])
        }

        @Test func lifecycleConflictIsNotReportedAsAnEditCollision() async throws {
            // "journal 4711 is already posted" (api/journal_lifecycle.go:109)
            // is a 409, but it is not an OCC stale write — it must keep its own
            // message rather than becoming "someone else changed this record".
            StubURLProtocol.install(stubSession) { _ in
                (409, Data(#"{"error":"journal 4711 is already posted"}"#.utf8))
            }
            let service = makeService()

            do {
                try await service.bookJournalEntry(
                    BookJournalRequest(journalId: 4711, userName: "MOBILE", period: 9, year: 2026)
                )
                Issue.record("expected the booking to be refused")
            } catch APIError.conflict {
                Issue.record("a lifecycle 409 must not be reported as an OCC conflict")
            } catch let error as APIError {
                guard case .serverError(let status, let message) = error else {
                    Issue.record("expected a serverError, got \(error)")
                    return
                }
                #expect(status == 409)
                #expect(message == "journal 4711 is already posted")
            }
        }

        @Test func separationOfDutiesRefusalCarriesTheServersSentence() async throws {
            let sod = "separation of duties: you cannot book, close, delete, or clone a journal you created"
            StubURLProtocol.install(stubSession) { _ in (403, Data(#"{"error":"\#(sod)"}"#.utf8)) }
            let service = makeService()

            do {
                try await service.bookJournalEntry(
                    BookJournalRequest(journalId: 4711, userName: "MOBILE", period: 9, year: 2026)
                )
                Issue.record("expected the booking to be refused")
            } catch let error as APIError {
                guard case .serverError(let status, let message) = error else {
                    Issue.record("expected a serverError, got \(error)")
                    return
                }
                #expect(status == 403)
                // Already a sentence the user can act on — the view shows it
                // as-is rather than prefixing "Error:".
                #expect(message == sod)
            }
        }
    }

    // MARK: A2 — Payables on the bills surface

    @MainActor
    @Suite(.serialized)
    struct Payables {

        @Test func agingBillsDecodeJournalStatusAndNotBooked() async throws {
            StubURLProtocol.install(stubSession) { _ in (200, agingBillsJSON) }
            let service = StubURLProtocol.makeService(stubSession)

            let bills = try await service.fetchAgingBills(periodYear: 2026, status: "ALL")

            let req = try #require(StubURLProtocol.recorded(stubSession).first)
            #expect(req.url.path == "/public/v1/read_aging_bills_by_period")
            // period_year/from/to are all required by the server.
            let query = try #require(req.url.query)
            #expect(query.contains("period_year=2026"))
            #expect(query.contains("period_from=1"))
            #expect(query.contains("period_to=12"))

            // This is the regression that mattered: the model carried a
            // non-optional `booked`, which the server stopped sending, so
            // EVERY aging-bills read threw .decodingFailed — taking the
            // sign-off screen down with it.
            #expect(bills.count == 3)
            #expect(bills.map(\.journalStatus) == ["CLOSED", "OPEN", "CLOSED"])

            // status is settlement; journal_status is the GL lifecycle.
            let posted = bills[0]
            #expect(posted.isPosted)
            #expect(!posted.isDraft)
            #expect(!posted.isPaid)

            let draft = bills[1]
            #expect(draft.isDraft)
            #expect(!draft.isPosted)

            let settled = bills[2]
            #expect(settled.isPaid)
            #expect(settled.isPosted)
        }

        @Test func billPaymentsAndSchedulesReadTheirOwnRoutes() async throws {
            StubURLProtocol.install(stubSession) { req in
                req.url.path.contains("read_payments_for_bill")
                    ? (200, billPaymentsJSON)
                    : (200, billSchedulesJSON)
            }
            let service = StubURLProtocol.makeService(stubSession)

            let payments = try await service.fetchBillPayments(billJournalId: 5001)
            let schedules = try await service.fetchBillPaymentSchedules(billJournalId: 5001)

            let paths = StubURLProtocol.recorded(stubSession).map(\.url.path)
            #expect(paths == [
                "/public/v1/read_payments_for_bill/5001",
                "/public/v1/read_scheduled_payments_for_bill/5001",
            ])

            #expect(payments.first?.appliedAmount == 400)
            #expect(payments.first?.applyLines == 2)

            // The schedules read is wrapped in an object, not a bare array.
            #expect(schedules.count == 2)
            #expect(schedules[0].isCancelled == false)
            #expect(schedules[1].isCancelled)       // cancel_date set
            #expect(schedules[0].isPosted == false) // posted_journal_id null
        }


    }

    // MARK: A10 — Confirming a payment the web raised

    @MainActor
    @Suite(.serialized)
    struct ConfirmingAPayment {

        @Test func awaitingConfirmationIsUnpostedUnreversedAP() async throws {
            StubURLProtocol.install(stubSession) { _ in (200, paymentsByDateJSON) }
            let service = StubURLProtocol.makeService(stubSession)

            let payments = try await service.fetchPaymentsAwaitingConfirmation(
                from: try #require(ISO8601DateFormatter().date(from: "2026-06-22T00:00:00Z")),
                to: try #require(ISO8601DateFormatter().date(from: "2026-09-20T00:00:00Z"))
            )

            let req = try #require(StubURLProtocol.recorded(stubSession).first)
            #expect(req.url.path == "/public/v1/read_payments_by_date")
            #expect(req.method == "POST")
            // The body was renamed from transaction_date/transaction_date_2.
            #expect(req.json?["from_date"] as? String == "2026-06-22")
            #expect(req.json?["to_date"] as? String == "2026-09-20")

            // Only unposted, unreversed AP is confirmable: a posted payment is
            // done, a reversed one is void, and AR/OWNER are not this flow.
            #expect(payments.map(\.id) == [3001])
            let payment = try #require(payments.first)
            #expect(payment.awaitsConfirmation)
            #expect(payment.amount == 5000.00)
            #expect(payment.displayParty == "ACME Furniture")
        }

        @Test func paymentAmountDecodesFromAStringToo() async throws {
            StubURLProtocol.install(stubSession) { _ in
                (200, Data(#"[{"id":3009,"kind":"AP","party_id":"v-9","amount":"1234.56","posted_journal_id":null,"reversed":false}]"#.utf8))
            }
            let service = StubURLProtocol.makeService(stubSession)
            let payment = try #require(try await service.fetchPaymentsAwaitingConfirmation(from: Date(), to: Date()).first)
            // pgtype.Numeric arrives either way.
            #expect(payment.amount == 1234.56)
        }

        @Test func theJournalAndWhatItSettlesAreReadForReview() async throws {
            StubURLProtocol.install(stubSession) { req in
                req.url.path.contains("read_payment_txn_details")
                    ? (200, paymentTxnLinesJSON)
                    : (200, paymentApplyLinesJSON)
            }
            let service = StubURLProtocol.makeService(stubSession)

            let lines = try await service.fetchPaymentTxnLines(paymentId: 3001)
            let applies = try await service.fetchPaymentApplyLines(paymentId: 3001)

            #expect(StubURLProtocol.recorded(stubSession).map(\.url.path) == [
                "/public/v1/read_payment_txn_details/3001",
                "/public/v1/read_payment_details/3001",
            ])

            // These return the sqlc structs, NOT the retired ap_transactions
            // shape the OpenAPI schema still documents for them (#217).
            #expect(lines.count == 2)
            #expect(lines[0].accountName == "Accounts Payable")
            #expect(lines[0].debit == 5000.00)
            #expect(lines[1].credit == 5000.00)
            let debits = lines.compactMap(\.debit).reduce(0, +)
            let credits = lines.compactMap(\.credit).reduce(0, +)
            #expect(abs(debits - credits) < 0.001)

            // charge_id carries the bill's journal id.
            let apply = try #require(applies.first)
            #expect(apply.billJournalId == 5001)
            #expect(apply.applyAmount == 5000.00)
        }

        @Test func confirmingPostsTheExistingPayment() async throws {
            StubURLProtocol.install(stubSession) { _ in
                (200, Data(#"{"journal_id":8123,"payment_id":3001}"#.utf8))
            }
            let service = StubURLProtocol.makeService(stubSession)

            let posted = try await service.postPayment(PostPaymentRequest(
                id: 3001, period: 9, periodYear: 2026, description: "Payment CHQ-4001 — ACME Furniture"
            ))

            let requests = StubURLProtocol.recorded(stubSession)
            // ONE call. iOS composes no lines and chooses no account: the web
            // built all of that, and post_payment is the only route that flips
            // approval_state to APPROVED.
            #expect(requests.count == 1)
            let req = try #require(requests.first)
            #expect(req.url.path == "/public/v1/post_payment")
            #expect(req.method == "POST")
            let json = try #require(req.json)
            #expect(json["id"] as? Int == 3001)
            #expect(json["period"] as? Int == 9)
            #expect(json["period_year"] as? Int == 2026)
            #expect((json["description"] as? String)?.isEmpty == false)
            // No account, no GL line, no apply line in the request.
            #expect(json["deposit_account"] == nil)
            #expect(json["source_account"] == nil)

            #expect(posted.journalId == 8123)
        }

        @Test func anAlreadyPostedPaymentIsRefusedWithItsOwnMessage() async throws {
            StubURLProtocol.install(stubSession) { _ in
                (409, Data(#"{"error":"payment already posted"}"#.utf8))
            }
            let service = StubURLProtocol.makeService(stubSession)

            do {
                _ = try await service.postPayment(PostPaymentRequest(
                    id: 3001, period: 9, periodYear: 2026, description: "dup"
                ))
                Issue.record("expected the second post to be refused")
            } catch APIError.conflict {
                Issue.record("a lifecycle 409 must not read as an OCC edit collision")
            } catch let error as APIError {
                #expect(error.localizedDescription == "payment already posted")
            }
        }
    }
}
