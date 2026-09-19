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
}
