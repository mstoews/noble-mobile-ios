//
//  StubURLProtocolTests.swift
//  nbledgerTests
//
//  Tests the test harness. StubURLProtocol's whole reason for existing in its
//  current shape is that suites run in parallel and its state is necessarily
//  static, so the isolation between sessions is the invariant worth pinning:
//  if it regresses, every other suite starts failing intermittently and for
//  reasons that point anywhere but here.
//

import Foundation
import Testing
@testable import nbledger

@MainActor
@Suite(.serialized)
struct StubURLProtocolTests {

    @Test func sessionsDoNotSeeEachOthersTraffic() async throws {
        StubURLProtocol.install("iso-a") { _ in (200, Data(#"{"who":"a"}"#.utf8)) }
        StubURLProtocol.install("iso-b") { _ in (200, Data(#"{"who":"b"}"#.utf8)) }

        let a = StubURLProtocol.makeService("iso-a")
        let b = StubURLProtocol.makeService("iso-b")

        // Interleaved on purpose: two requests through B between A's.
        _ = try? await a.fetchMyProfile()
        _ = try? await b.fetchMyProfile()
        _ = try? await b.fetchMyProfile()
        _ = try? await a.fetchMyProfile()

        // Each session records only its own, in its own order.
        #expect(StubURLProtocol.recorded("iso-a").count == 2)
        #expect(StubURLProtocol.recorded("iso-b").count == 2)
        #expect(StubURLProtocol.recorded("iso-a").allSatisfy {
            $0.headers[StubURLProtocol.sessionHeader] == "iso-a"
        })
        #expect(StubURLProtocol.recorded("iso-b").allSatisfy {
            $0.headers[StubURLProtocol.sessionHeader] == "iso-b"
        })
    }

    @Test func respondersAnswerOnlyTheirOwnSession() async throws {
        StubURLProtocol.install("resp-a") { _ in (200, Data(#"{"name":"from-a"}"#.utf8)) }
        StubURLProtocol.install("resp-b") { _ in (500, Data(#"{"error":"from-b"}"#.utf8)) }

        let a = StubURLProtocol.makeService("resp-a")
        let b = StubURLProtocol.makeService("resp-b")

        // A succeeds while B's responder is failing everything — the two do
        // not answer each other, which is precisely what a single shared
        // responder got wrong.
        let profile = try await a.fetchMyProfile()
        #expect(profile.name == "from-a")

        await #expect(throws: APIError.self) {
            _ = try await b.fetchMyProfile()
        }
    }

    @Test func installClearsOnlyThatSessionsRecording() async throws {
        StubURLProtocol.install("keep") { _ in (200, Data("{}".utf8)) }
        StubURLProtocol.install("wipe") { _ in (200, Data("{}".utf8)) }
        let keep = StubURLProtocol.makeService("keep")
        let wipe = StubURLProtocol.makeService("wipe")
        _ = try? await keep.fetchMyProfile()
        _ = try? await wipe.fetchMyProfile()
        #expect(StubURLProtocol.recorded("keep").count == 1)

        // Re-installing "wipe" is what each test does at its start; it must
        // not reset a sibling suite that is mid-run.
        StubURLProtocol.install("wipe") { _ in (200, Data("{}".utf8)) }

        #expect(StubURLProtocol.recorded("wipe").isEmpty)
        #expect(StubURLProtocol.recorded("keep").count == 1)
    }

    @Test func anUntaggedSessionFailsRatherThanMatchingNothing() async throws {
        // A service built without makeService/session(_:) sends no id. Failing
        // loudly beats a test that mysteriously records zero requests.
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let untagged = APIService(session: URLSession(configuration: config))
        untagged.token = "test-token"
        untagged.tenant = "public"

        await #expect(throws: APIError.self) {
            _ = try await untagged.fetchMyProfile()
        }
    }
}
