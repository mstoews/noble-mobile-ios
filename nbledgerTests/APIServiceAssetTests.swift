//
//  APIServiceAssetTests.swift
//  nbledgerTests
//
//  Unit tests for the asset upload flow (upload_url -> PUT -> confirm) and
//  the server-side invoice analysis call, using a stubbed URLProtocol so no
//  network traffic leaves the process.
//

import Foundation
import Testing
@testable import nbledger


// MARK: - Fixtures

/// Keys this suite's responder and recording in the shared stub.
private let stubSession = "asset"

@MainActor
private func makeService() -> APIService {
    let service = StubURLProtocol.makeService(stubSession, token: "test-token")
    return service
}

private let assetID = "11111111-2222-3333-4444-555555555555"

private let uploadTicketJSON = """
{
  "id": "\(assetID)",
  "upload_url": "https://storage.googleapis.com/noble-ledger-assets/public/receipt/\(assetID).jpg?X-Goog-Signature=abc",
  "object_key": "public/receipt/\(assetID).jpg",
  "expires_at": "2026-07-07T12:00:00Z",
  "http_method": "PUT",
  "headers": {"Content-Type": "image/jpeg"}
}
""".data(using: .utf8)!

private let assetRowJSON = """
{
  "id": "\(assetID)",
  "tenant": "public",
  "user_uid": "user-1",
  "kind": "receipt",
  "object_key": "public/receipt/\(assetID).jpg",
  "content_type": "image/jpeg",
  "original_name": "receipt.jpg",
  "size_bytes": 9,
  "uploaded": true,
  "created_at": "2026-07-07T11:59:00Z",
  "confirmed_at": "2026-07-07T12:00:30Z",
  "deleted_at": null
}
""".data(using: .utf8)!

private let downloadURLJSON = """
{
  "download_url": "https://storage.googleapis.com/noble-ledger-assets/public/receipt/\(assetID).jpg?X-Goog-Signature=get",
  "expires_at": "2026-07-07T12:15:00Z"
}
""".data(using: .utf8)!

// MARK: - Tests

// @MainActor because the nbledger module builds with default MainActor
// isolation — APIService and its models are main-actor isolated.
@MainActor
@Suite(.serialized)
struct APIServiceAssetTests {

    @Test func requestUploadURLPostsToV1AssetsAndDecodesTicket() async throws {
        StubURLProtocol.install(stubSession) { _ in (200, uploadTicketJSON) }
        let service = makeService()

        let ticket = try await service.requestAssetUploadURL(
            kind: "receipt",
            contentType: "image/jpeg",
            originalName: "receipt.jpg"
        )

        let requests = StubURLProtocol.recorded(stubSession)
        #expect(requests.count == 1)
        let req = try #require(requests.first)
        #expect(req.url.absoluteString == "https://api.nobleledger.com/public/v1/assets/upload_url")
        #expect(req.method == "POST")
        #expect(req.headers["Authorization"] == "Bearer test-token")
        let json = try #require(req.json)
        #expect(json["kind"] as? String == "receipt")
        #expect(json["content_type"] as? String == "image/jpeg")
        #expect(json["original_name"] as? String == "receipt.jpg")

        #expect(ticket.id == assetID)
        #expect(ticket.httpMethod == "PUT")
        #expect(ticket.headers?["Content-Type"] == "image/jpeg")
        #expect(ticket.uploadURL.hasPrefix("https://storage.googleapis.com/"))
    }

    @Test func uploadAssetRunsThreeStepFlow() async throws {
        StubURLProtocol.install(stubSession) { req in
            switch (req.method, req.url.host, req.url.path) {
            case ("POST", "api.nobleledger.com", "/public/v1/assets/upload_url"):
                return (200, uploadTicketJSON)
            case ("PUT", "storage.googleapis.com", _):
                return (200, Data())
            case ("POST", "api.nobleledger.com", "/public/v1/assets/\(assetID)/confirm"):
                return (200, assetRowJSON)
            default:
                return (404, Data("{\"error\":\"unexpected request\"}".utf8))
            }
        }
        let service = makeService()
        let bytes = Data("test-body".utf8)

        let uploaded = try await service.uploadAsset(bytes, kind: "receipt", contentType: "image/jpeg", originalName: "receipt.jpg")

        // The confirm is the success point — no download-URL call is part of
        // the upload flow (a failure there must not read as a failed upload).
        let requests = StubURLProtocol.recorded(stubSession)
        #expect(requests.map(\.method) == ["POST", "PUT", "POST"])

        // Step 2 — the PUT goes to the signed URL with the ticket's headers,
        // carries the raw bytes, and must NOT include the bearer token.
        let put = requests[1]
        #expect(put.url.host == "storage.googleapis.com")
        #expect(put.headers["Authorization"] == nil)
        #expect(put.headers["Content-Type"] == "image/jpeg")
        #expect(put.body == bytes)

        // Step 3 — confirm reports the uploaded size and returns the
        // confirmed asset row.
        let confirm = requests[2]
        #expect(confirm.json?["size_bytes"] as? Int == bytes.count)

        #expect(uploaded.id == assetID)
        #expect(uploaded.uploaded == true)
        #expect(uploaded.confirmedAt != nil)
    }

    @Test func uploadAssetStopsWhenPutToStorageFails() async throws {
        StubURLProtocol.install(stubSession) { req in
            switch (req.method, req.url.host) {
            case ("POST", "api.nobleledger.com"):
                return (200, uploadTicketJSON)
            case ("PUT", "storage.googleapis.com"):
                return (403, Data())
            default:
                return (404, Data())
            }
        }
        let service = makeService()

        await #expect(throws: APIError.self) {
            try await service.uploadAsset(Data("x".utf8), kind: "receipt", contentType: "image/jpeg")
        }
        // No confirm attempt after a failed PUT.
        #expect(StubURLProtocol.recorded(stubSession).map(\.method) == ["POST", "PUT"])
    }

    @Test func listAssetsSendsKindQueryAndDecodesRows() async throws {
        StubURLProtocol.install(stubSession) { _ in
            (200, Data("[\(String(data: assetRowJSON, encoding: .utf8)!)]".utf8))
        }
        let service = makeService()

        let assets = try await service.listAssets(kind: "receipt")

        let req = try #require(StubURLProtocol.recorded(stubSession).first)
        #expect(req.url.absoluteString == "https://api.nobleledger.com/public/v1/assets?kind=receipt")
        #expect(req.method == "GET")
        #expect(assets.count == 1)
        let asset = try #require(assets.first)
        #expect(asset.id == assetID)
        #expect(asset.contentType == "image/jpeg")
        #expect(asset.sizeBytes == 9)
        #expect(asset.uploaded == true)
    }

    @Test func assetDownloadURLFetchesSignedURL() async throws {
        StubURLProtocol.install(stubSession) { _ in (200, downloadURLJSON) }
        let service = makeService()

        let url = try await service.assetDownloadURL(id: assetID)

        let req = try #require(StubURLProtocol.recorded(stubSession).first)
        #expect(req.url.absoluteString == "https://api.nobleledger.com/public/v1/assets/\(assetID)/download_url")
        #expect(req.method == "GET")
        #expect(url.absoluteString.contains("X-Goog-Signature=get"))
    }

    @Test func assetDownloadURLSurfacesServerError() async throws {
        StubURLProtocol.install(stubSession) { _ in
            (409, Data("{\"error\":\"asset upload not confirmed\"}".utf8))
        }
        let service = makeService()

        do {
            _ = try await service.assetDownloadURL(id: assetID)
            Issue.record("expected APIError.serverError")
        } catch let APIError.serverError(statusCode, message) {
            #expect(statusCode == 409)
            #expect(message == "asset upload not confirmed")
        }
    }

    // MARK: - Server-side invoice analysis

    @Test func analyzeInvoicePostsToServerAgentEndpoint() async throws {
        let responseJSON = """
        {
          "vendor_name": "Acme Supplies",
          "invoice_number": "INV-42",
          "amount": 123.45,
          "date": "2026-07-01",
          "due_date": "2026-07-31",
          "description": "Office supplies"
        }
        """.data(using: .utf8)!
        StubURLProtocol.install(stubSession) { _ in (200, responseJSON) }
        let service = makeService()
        let imageData = Data("fake-image-bytes".utf8)

        let extraction = try await service.analyzeInvoice(imageData: imageData)

        let req = try #require(StubURLProtocol.recorded(stubSession).first)
        // AI analysis goes to OUR server agent — never to an AI provider host.
        #expect(req.url.absoluteString == "https://api.nobleledger.com/public/v1/agent/analyze-invoice")
        #expect(req.method == "POST")
        #expect(req.headers["Authorization"] == "Bearer test-token")
        let json = try #require(req.json)
        #expect(json["image"] as? String == imageData.base64EncodedString())
        #expect(json["media_type"] as? String == "image/jpeg")

        #expect(extraction.vendorName == "Acme Supplies")
        #expect(extraction.invoiceNumber == "INV-42")
        #expect(extraction.amount == 123.45)
        #expect(extraction.date == "2026-07-01")
        #expect(extraction.dueDate == "2026-07-31")
        #expect(extraction.description == "Office supplies")
    }

    @Test func analyzeInvoicePassesExplicitMediaType() async throws {
        StubURLProtocol.install(stubSession) { _ in
            (200, Data("{\"vendor_name\":\"\",\"invoice_number\":\"\",\"amount\":0,\"date\":\"\",\"due_date\":\"\",\"description\":\"\"}".utf8))
        }
        let service = makeService()

        _ = try await service.analyzeInvoice(imageData: Data("png-bytes".utf8), mediaType: "image/png")

        let req = try #require(StubURLProtocol.recorded(stubSession).first)
        #expect(req.json?["media_type"] as? String == "image/png")
    }

    @Test func analyzeInvoiceSurfacesServerError() async throws {
        StubURLProtocol.install(stubSession) { _ in
            (500, Data("{\"error\":\"failed to analyze invoice\"}".utf8))
        }
        let service = makeService()

        do {
            _ = try await service.analyzeInvoice(imageData: Data("x".utf8))
            Issue.record("expected APIError.serverError")
        } catch let APIError.serverError(statusCode, message) {
            #expect(statusCode == 500)
            #expect(message == "failed to analyze invoice")
        }
    }
}
