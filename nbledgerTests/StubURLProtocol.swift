//
//  StubURLProtocol.swift
//  nbledgerTests
//
//  The test target's one URLProtocol stub: it intercepts every request an
//  APIService makes so no traffic leaves the process.
//
//  A URLProtocol is instantiated by URLSession, so its responder and recording
//  have to be static — process-global. Swift Testing runs suites in parallel,
//  and a single shared responder therefore had concurrently-running suites
//  answering and recording each other's requests. The previous fix was one
//  copy of this class per suite, which reached five near-identical copies
//  (four byte-identical, one missing header capture) before this replaced them.
//
//  Instead, every stubbed session tags its requests with a unique id via
//  `httpAdditionalHeaders`, and both the responder and the recording are keyed
//  on that id. Suites are isolated by construction, and adding one needs no
//  new class.
//
//  Suites stay `.serialized` because tests *within* a suite share its id. That
//  is deliberate rather than a limitation worth engineering away: the whole
//  unit suite runs in well under a second, so intra-suite parallelism would
//  buy nothing and cost every test an explicit handle to pass around.
//

import Foundation
@testable import nbledger

final class StubURLProtocol: URLProtocol {
    struct RecordedRequest {
        let url: URL
        let method: String
        let headers: [String: String]
        let body: Data?

        var json: [String: Any]? {
            body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        }
    }

    /// Carries the owning suite's id on every request from its session.
    static let sessionHeader = "X-Stub-Session"

    private static let lock = NSLock()
    nonisolated(unsafe) private static var recordings: [String: [RecordedRequest]] = [:]
    nonisolated(unsafe) private static var responders: [String: (RecordedRequest) -> (Int, Data)] = [:]

    /// Clears `session`'s recorded requests and installs its responder for the
    /// next test. Other sessions' state is untouched.
    static func install(
        _ session: String,
        _ responder: @escaping (RecordedRequest) -> (Int, Data)
    ) {
        lock.lock(); defer { lock.unlock() }
        recordings[session] = []
        responders[session] = responder
    }

    static func recorded(_ session: String) -> [RecordedRequest] {
        lock.lock(); defer { lock.unlock() }
        return recordings[session] ?? []
    }

    /// A session whose requests all route to `session`'s responder.
    static func session(_ session: String) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        config.httpAdditionalHeaders = [sessionHeader: session]
        return URLSession(configuration: config)
    }

    /// An APIService wired to `session`'s stub, with the tenant pinned so the
    /// derived `{host}/{slug}/v1` base is deterministic regardless of the test
    /// host's UserDefaults.
    @MainActor
    static func makeService(
        _ session: String,
        token: String = "test-token",
        tenant: String = "public"
    ) -> APIService {
        let service = APIService(session: Self.session(session))
        service.token = token
        service.tenant = tenant
        return service
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

        // An untagged request means a session built without `session(_:)` —
        // fail it loudly rather than letting it silently match nothing.
        guard let session = record.headers[Self.sessionHeader] else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        Self.lock.lock()
        Self.recordings[session, default: []].append(record)
        let responder = Self.responders[session]
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
