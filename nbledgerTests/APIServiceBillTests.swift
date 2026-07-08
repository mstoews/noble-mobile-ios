//
//  APIServiceBillTests.swift
//  nbledgerTests
//
//  Unit tests for the create_bill / attach_bill_asset / list_bill_assets
//  flow and the v1 reference-data reads, mirroring CONTRACT.md §2 and §4.
//
//  Uses its own URLProtocol stub (not APIServiceAssetTests's) so the two
//  @Suite(.serialized) suites cannot race each other's shared static
//  state if Swift Testing runs them in parallel.
//
//  Also covers the capture view layer (ported with the M2 UI port):
//  InvoicesView.makePrefill / makeCapturePayload and
//  BillFormView.rfc3339DateOnly.
//

import Foundation
import Testing
import UIKit
@testable import nbledger

// MARK: - URLProtocol stub (state independent of StubURLProtocol)

final class BillStubURLProtocol: URLProtocol {
    struct RecordedRequest {
        let url: URL
        let method: String
        let headers: [String: String]
        let body: Data?

        var json: [String: Any]? {
            body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        }
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var _recorded: [RecordedRequest] = []
    nonisolated(unsafe) private static var _responder: ((RecordedRequest) -> (Int, Data))?

    static var recorded: [RecordedRequest] {
        lock.lock(); defer { lock.unlock() }
        return _recorded
    }

    /// Clears recorded requests and installs the responder for the next test.
    static func install(_ responder: @escaping (RecordedRequest) -> (Int, Data)) {
        lock.lock(); defer { lock.unlock() }
        _recorded = []
        _responder = responder
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        let record = RecordedRequest(
            url: url,
            method: request.httpMethod ?? "GET",
            headers: request.allHTTPHeaderFields ?? [:],
            body: request.httpBody ?? Self.drain(request.httpBodyStream)
        )

        Self.lock.lock()
        Self._recorded.append(record)
        let responder = Self._responder
        Self.lock.unlock()

        guard let responder else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        let (status, data) = responder(record)
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func drain(_ stream: InputStream?) -> Data? {
        guard let stream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

// MARK: - Fixtures

@MainActor
private func makeService() -> APIService {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [BillStubURLProtocol.self]
    let service = APIService(session: URLSession(configuration: config))
    service.token = "test-token"
    // Pin the tenant so the derived {host}/{slug}/v1 base is deterministic
    // regardless of the test host's UserDefaults.
    service.tenant = "public"
    return service
}

private let vendorID = "019e3944-d510-736f-b64f-8e130e47b937"
private let assetID = "019a7f3e-1111-7abc-9def-0123456789ab"

/// create_bill 201 response per CONTRACT.md §4 (verified live).
private let createBillResponseJSON = """
{
  "header": {
    "journal_id": 58,
    "transaction_date": "2026-06-28",
    "due_date": "2026-07-28",
    "description": "Electricity service June 2026",
    "invoice_no": "INV-2026-04417",
    "party_id": "\(vendorID)",
    "amount": 1250.00,
    "period": 6,
    "period_year": 2026,
    "status": "OPEN",
    "booked": false
  },
  "ap_lines": [
    { "journal_id": 58, "journal_subid": 1, "account": 6100, "child": 6110,
      "description": "Hydro June", "debit": 1250.00, "credit": null,
      "fund": "OPER", "create_date": "2026-07-07", "create_user": "@mstoews" }
  ],
  "remainder": 1250.00
}
""".data(using: .utf8)!

private let billAssetRowJSON = """
{
  "id": "\(assetID)",
  "tenant": "public",
  "user_uid": "user-1",
  "kind": "receipts",
  "object_key": "public/receipts/\(assetID).jpg",
  "content_type": "image/jpeg",
  "original_name": "receipt.jpg",
  "size_bytes": 482133,
  "uploaded": true,
  "created_at": "2026-07-07T11:59:00Z",
  "confirmed_at": "2026-07-07T12:00:30Z",
  "deleted_at": null
}
""".data(using: .utf8)!

// MARK: - Tests

// @MainActor because the nbledger module builds with default MainActor
// isolation — APIService and its models are main-actor isolated.
@MainActor
@Suite(.serialized)
struct APIServiceBillTests {

    @Test func createBillPostsContractShapeAndDecodesJournalId() async throws {
        BillStubURLProtocol.install { _ in (201, createBillResponseJSON) }
        let service = makeService()

        let request = CreateBillRequest(
            vendorId: vendorID,
            invoiceNo: "INV-2026-04417",
            transactionDate: "2026-06-28T00:00:00Z",
            dueDate: "2026-07-28T00:00:00Z",
            description: "Electricity service June 2026",
            expenseLines: [
                CreateBillExpenseLine(
                    fund: "OPER",
                    account: 6100,
                    child: 6110,
                    amount: "1250.00",
                    description: "Hydro June"
                )
            ],
            booked: false
        )
        let response = try await service.createBill(request)

        let requests = BillStubURLProtocol.recorded
        #expect(requests.count == 1)
        let req = try #require(requests.first)
        #expect(req.url.absoluteString == "https://api.nobleledger.com/public/v1/create_bill")
        #expect(req.method == "POST")
        #expect(req.headers["Authorization"] == "Bearer test-token")

        let json = try #require(req.json)
        #expect(json["vendor_id"] as? String == vendorID)
        #expect(json["invoice_no"] as? String == "INV-2026-04417")
        // RFC3339 timestamps, not bare dates.
        #expect(json["transaction_date"] as? String == "2026-06-28T00:00:00Z")
        #expect(json["due_date"] as? String == "2026-07-28T00:00:00Z")
        // booked must be false from mobile capture (ruling D5).
        #expect(json["booked"] as? Bool == false)

        let lines = try #require(json["expense_lines"] as? [[String: Any]])
        #expect(lines.count == 1)
        let line = try #require(lines.first)
        #expect(line["fund"] as? String == "OPER")
        #expect(line["account"] as? Int == 6100)
        #expect(line["child"] as? Int == 6110)
        // amount is a STRING in expense_lines per the contract.
        #expect(line["amount"] as? String == "1250.00")

        #expect(response.header.journalId == 58)
        #expect(response.header.status == "OPEN")
        #expect(response.header.booked == false)
        #expect(response.header.amount == 1250.00)
    }

    @Test func createBillSurfacesServerError() async throws {
        BillStubURLProtocol.install { _ in
            (422, Data("{\"error\":\"vendor has no ap_account / ap_child configured\"}".utf8))
        }
        let service = makeService()

        do {
            _ = try await service.createBill(CreateBillRequest(
                vendorId: vendorID,
                invoiceNo: "INV-1",
                transactionDate: "2026-06-28T00:00:00Z",
                dueDate: "2026-07-28T00:00:00Z",
                description: "",
                expenseLines: [CreateBillExpenseLine(fund: "OPER", account: 5000, child: 5000, amount: "1.00", description: "")],
                booked: false
            ))
            Issue.record("expected APIError.serverError")
        } catch let APIError.serverError(statusCode, message) {
            #expect(statusCode == 422)
            #expect(message == "vendor has no ap_account / ap_child configured")
        }
    }

    @Test func attachBillAssetPostsJournalAndAssetIds() async throws {
        BillStubURLProtocol.install { _ in
            (200, Data("{\"journal_id\":58,\"asset_id\":\"\(assetID)\"}".utf8))
        }
        let service = makeService()

        let link = try await service.attachBillAsset(journalId: 58, assetId: assetID)

        let req = try #require(BillStubURLProtocol.recorded.first)
        #expect(req.url.absoluteString == "https://api.nobleledger.com/public/v1/attach_bill_asset")
        #expect(req.method == "POST")
        let json = try #require(req.json)
        #expect(json["journal_id"] as? Int == 58)
        #expect(json["asset_id"] as? String == assetID)

        #expect(link.journalId == 58)
        #expect(link.assetId == assetID)
    }

    @Test func attachBillAssetSurfacesWrongTenantError() async throws {
        BillStubURLProtocol.install { _ in
            (422, Data("{\"error\":\"asset belongs to a different tenant\"}".utf8))
        }
        let service = makeService()

        do {
            _ = try await service.attachBillAsset(journalId: 58, assetId: assetID)
            Issue.record("expected APIError.serverError")
        } catch let APIError.serverError(statusCode, message) {
            #expect(statusCode == 422)
            #expect(message == "asset belongs to a different tenant")
        }
    }

    @Test func listBillAssetsGetsJournalPathAndDecodesRows() async throws {
        BillStubURLProtocol.install { _ in
            (200, Data("[\(String(data: billAssetRowJSON, encoding: .utf8)!)]".utf8))
        }
        let service = makeService()

        let assets = try await service.listBillAssets(journalId: 58)

        let req = try #require(BillStubURLProtocol.recorded.first)
        #expect(req.url.absoluteString == "https://api.nobleledger.com/public/v1/list_bill_assets/58")
        #expect(req.method == "GET")

        #expect(assets.count == 1)
        let asset = try #require(assets.first)
        #expect(asset.id == assetID)
        #expect(asset.contentType == "image/jpeg")
        #expect(asset.uploaded == true)
    }

    @Test func fetchAPVendorsReadsV1RouteAndDecodesUUIDIds() async throws {
        let vendorsJSON = """
        [{
          "id": "\(vendorID)",
          "name": "CleanPro Janitorial Services",
          "short_name": "CleanPro",
          "address1": "3100 Boundary Road",
          "account": 5120,
          "child": 0,
          "ap_account": 2000,
          "ap_child": 2000,
          "description": "Building cleaning and janitorial",
          "type": "SERVICE",
          "status": "ACTIVE",
          "vendor_terms": 15
        }]
        """.data(using: .utf8)!
        BillStubURLProtocol.install { _ in (200, vendorsJSON) }
        let service = makeService()

        let vendors = try await service.fetchAPVendors()

        let req = try #require(BillStubURLProtocol.recorded.first)
        #expect(req.url.absoluteString == "https://api.nobleledger.com/public/v1/list_ap_vendors")
        #expect(req.method == "GET")

        #expect(vendors.count == 1)
        let vendor = try #require(vendors.first)
        #expect(vendor.id == vendorID)
        #expect(vendor.displayName == "CleanPro Janitorial Services")
        #expect(vendor.account == 5120)
        #expect(vendor.child == 0)
    }

    @Test func fetchFundsAndGLAccountsReadV1Routes() async throws {
        BillStubURLProtocol.install { req in
            switch req.url.path {
            case "/public/v1/funds_list":
                return (200, Data("""
                [{"id":"019e3944-ce44-72a3-b3de-3355f5fd9375","fund":"OPER","description":"Operating Fund","restriction":"unrestricted"}]
                """.utf8))
            case "/public/v1/account_list":
                return (200, Data("""
                [{"id":"019e3944-d152-7028-88e8-72550852ebf3","account":5000,"child":5000,"parent_account":false,"acct_type":"EXPENSE","description":"Hydro / Electricity","status":"ACTIVE"}]
                """.utf8))
            default:
                return (404, Data("{\"error\":\"unexpected request\"}".utf8))
            }
        }
        let service = makeService()

        let funds = try await service.fetchFunds()
        let accounts = try await service.fetchGLAccounts()

        #expect(funds.count == 1)
        #expect(funds.first?.fund == "OPER")
        #expect(funds.first?.displayName == "OPER — Operating Fund")

        // The v1 account_list id is a uuid STRING (the legacy Account
        // model's Int id cannot decode it).
        #expect(accounts.count == 1)
        let account = try #require(accounts.first)
        #expect(account.id == "019e3944-d152-7028-88e8-72550852ebf3")
        #expect(account.account == 5000)
        #expect(account.child == 5000)
        #expect(account.acctType == "EXPENSE")
    }

    // MARK: - Extraction -> prefill semantics

    @Test func makePrefillTreatsEmptyAndZeroAsNotExtracted() {
        // Server contract: fields it could NOT read arrive as "" / 0.
        let empty = InvoiceExtraction(
            vendorName: "",
            invoiceNumber: "",
            amount: 0.0,
            date: "",
            dueDate: "",
            description: ""
        )
        let prefill = InvoicesView.makePrefill(from: empty)
        #expect(prefill.vendorName == nil)
        #expect(prefill.invoiceNumber == nil)
        #expect(prefill.amount == nil)
        #expect(prefill.invoiceDate == nil)
        #expect(prefill.dueDate == nil)
        #expect(prefill.description == nil)
    }

    @Test func makePrefillMapsExtractedValues() {
        let extraction = InvoiceExtraction(
            vendorName: "BC Hydro",
            invoiceNumber: "INV-2026-04417",
            amount: 1250.0,
            date: "2026-06-28",
            dueDate: "2026-07-28",
            description: "Electricity service June 2026"
        )
        let prefill = InvoicesView.makePrefill(from: extraction)
        #expect(prefill.vendorName == "BC Hydro")
        #expect(prefill.invoiceNumber == "INV-2026-04417")
        #expect(prefill.amount == "1250.00")
        #expect(prefill.description == "Electricity service June 2026")
        #expect(prefill.invoiceDate == InvoicesView.parseDate("2026-06-28"))
        #expect(prefill.dueDate == InvoicesView.parseDate("2026-07-28"))
    }

    @Test func rfc3339DateOnlyFormatsUTCMidnight() throws {
        let date = try #require(InvoicesView.parseDate("2026-06-28"))
        #expect(BillFormView.rfc3339DateOnly(date) == "2026-06-28T00:00:00Z")
    }

    // MARK: - Capture payload routing (images analyze, PDFs do not)

    @Test func makeCapturePayloadRoutesPDFByExtension() throws {
        let bytes = Data("not-really-pdf-but-named-so".utf8)
        let payload = try #require(InvoicesView.makeCapturePayload(fileData: bytes, fileName: "invoice.pdf"))
        // PDFs pass through untouched, upload as application/pdf, and are
        // NOT analyzable (agent/analyze-invoice rejects PDF, contract §3.1).
        #expect(payload.contentType == "application/pdf")
        #expect(payload.isAnalyzable == false)
        #expect(payload.data == bytes)
        #expect(payload.originalName == "invoice.pdf")
    }

    @Test func makeCapturePayloadRoutesPDFByMagicBytes() throws {
        let bytes = Data("%PDF-1.4\n1 0 obj".utf8)
        let payload = try #require(InvoicesView.makeCapturePayload(fileData: bytes, fileName: "photo"))
        #expect(payload.contentType == "application/pdf")
        #expect(payload.isAnalyzable == false)
        #expect(payload.originalName == "photo.pdf")
    }

    @Test func makeCapturePayloadReencodesImagesToJPEG() throws {
        // A real (non-JPEG) image: 2x2 PNG rendered in-process. Covers the
        // D4 rule that every image source (HEIC/PNG/...) re-encodes to JPEG.
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2))
        let pngData = renderer.pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }

        let payload = try #require(InvoicesView.makeCapturePayload(fileData: pngData, fileName: "scan.HEIC"))
        #expect(payload.contentType == "image/jpeg")
        #expect(payload.isAnalyzable == true)
        #expect(payload.originalName == "scan.jpg")
        // JPEG SOI marker.
        #expect(payload.data.prefix(2) == Data([0xFF, 0xD8]))
    }

    @Test func makeCapturePayloadRejectsUndecodableBytes() {
        let payload = InvoicesView.makeCapturePayload(
            fileData: Data("plain text, not an image".utf8),
            fileName: "notes.txt"
        )
        #expect(payload == nil)
    }
}
