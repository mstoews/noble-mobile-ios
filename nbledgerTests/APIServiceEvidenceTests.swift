//
//  APIServiceEvidenceTests.swift
//  nbledgerTests
//
//  Contract tests for the journal evidence flow: gl_evidence rows carry a
//  Postgres uuid id (a string — decoding as Int silently broke the Evidence
//  section before), create_evidence posts snake_case JSON, and
//  read_journal_header rows carry the evidence_count indicator field.
//

import Foundation
import Testing
@testable import nbledger

// Private stub with its own static state. StubURLProtocol's statics are
// shared process-wide, and Swift Testing runs separate suites in parallel
// (.serialized only orders tests within a suite) — reusing it from a second
// suite races against APIServiceAssetTests' responder installs.
final class EvidenceStubURLProtocol: URLProtocol {
    struct RecordedRequest {
        let url: URL
        let method: String
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

@MainActor
private func makeService() -> APIService {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [EvidenceStubURLProtocol.self]
    let service = APIService(session: URLSession(configuration: config))
    service.token = "test-token"
    service.tenant = "public"
    return service
}

private let evidenceRowsJSON = """
[
  {
    "id": "0197c8a2-1111-2222-3333-444455556666",
    "journal_id": 42,
    "reference": "INV-9",
    "description": "evidence-1751970000.jpg",
    "location": "11111111-2222-3333-4444-555555555555",
    "user_created": "mstoews",
    "date_created": "2026-07-09",
    "confirmed": false
  }
]
""".data(using: .utf8)!

@MainActor
@Suite(.serialized)
struct APIServiceEvidenceTests {

    @Test func fetchEvidenceDecodesUUIDIdRows() async throws {
        EvidenceStubURLProtocol.install { _ in (200, evidenceRowsJSON) }
        let service = makeService()

        let evidence = try await service.fetchEvidenceByJournal(42)

        let req = try #require(EvidenceStubURLProtocol.recorded.first)
        #expect(req.url.absoluteString == "https://api.nobleledger.com/public/v1/read_evidence_by_journal/42")
        #expect(evidence.count == 1)
        let row = try #require(evidence.first)
        #expect(row.id == "0197c8a2-1111-2222-3333-444455556666")
        #expect(row.journalId == 42)
        #expect(row.location == "11111111-2222-3333-4444-555555555555")
        #expect(row.confirmed == false)
    }

    @Test func createEvidencePostsSnakeCaseBody() async throws {
        EvidenceStubURLProtocol.install { _ in (200, Data("{}".utf8)) }
        let service = makeService()

        try await service.createEvidence(CreateEvidenceRequest(
            journalId: 42,
            description: "evidence.jpg",
            location: "11111111-2222-3333-4444-555555555555",
            dateCreated: "2026-07-09",
            confirmed: false
        ))

        let req = try #require(EvidenceStubURLProtocol.recorded.first)
        #expect(req.url.absoluteString == "https://api.nobleledger.com/public/v1/create_evidence")
        #expect(req.method == "POST")
        let json = try #require(req.json)
        #expect(json["journal_id"] as? Int == 42)
        #expect(json["description"] as? String == "evidence.jpg")
        #expect(json["location"] as? String == "11111111-2222-3333-4444-555555555555")
        #expect(json["date_created"] as? String == "2026-07-09")
        #expect(json["confirmed"] as? Bool == false)
    }

    @Test func journalHeadersDecodeEvidenceCount() async throws {
        let headersJSON = """
        [
          {"journal_id": 1, "description": "Rent", "evidence_count": 2},
          {"journal_id": 2, "description": "Payroll", "evidence_count": 0},
          {"journal_id": 3, "description": "Legacy endpoint row"}
        ]
        """.data(using: .utf8)!
        EvidenceStubURLProtocol.install { _ in (200, headersJSON) }
        let service = makeService()

        let headers = try await service.fetchJournalHeaders()

        #expect(headers.count == 3)
        #expect(headers[0].evidenceCount == 2)
        #expect(headers[1].evidenceCount == 0)
        // Endpoints that don't emit the field decode to nil, not a failure.
        #expect(headers[2].evidenceCount == nil)
    }
}
