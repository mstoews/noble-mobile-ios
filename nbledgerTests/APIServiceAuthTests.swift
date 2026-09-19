//
//  APIServiceAuthTests.swift
//  nbledgerTests
//
//  Unit tests for the session auth contract (POST /v1/auth/login,
//  /v1/auth/refresh, /v1/auth/logout), using the shared stubbed URLProtocol so
//  no network traffic leaves the process.
//
//  The single-flight refresh test is the load-bearing one: the server revokes
//  the refresh token it is handed and treats a second presentation as theft,
//  burning every session the user has. Two parallel 401s must therefore
//  produce exactly one rotation.
//

import Foundation
import Testing
@testable import nbledger


// MARK: - Fixtures

/// Keys this suite's responder and recording in the shared stub.
private let stubSession = "auth"

@MainActor
private func makeAuthService(token: String = "stale-token", canRefresh: Bool = true) -> APIService {
    let service = StubURLProtocol.makeService(stubSession, token: token)
    service.refreshExpiresAt = canRefresh
        ? Date().addingTimeInterval(48 * 3600)
        : Date().addingTimeInterval(-60)
    return service
}

/// The test host shares UserDefaults with every other test, and logIn/refresh
/// persist the session there on purpose. Clear what they write.
@MainActor
private func clearPersistedSession(_ service: APIService) {
    service.clearSession()
    UserDefaults.standard.removeObject(forKey: "tenant")
}

// Go marshals time.Time as RFC3339 *with* fractional seconds — the shape the
// parser has to cope with, so the fixtures use it.
private let sessionJSON = """
{
  "session_token": "sess-fresh",
  "expires_at": "2026-09-19T12:15:00.123456789Z",
  "refresh_expires_at": "2026-09-21T12:00:00.5Z"
}
""".data(using: .utf8)!

private let rotatedSessionJSON = """
{
  "session_token": "sess-rotated",
  "expires_at": "2026-09-19T12:30:00.987Z",
  "refresh_expires_at": "2026-09-21T12:30:00Z"
}
""".data(using: .utf8)!

private let mfaChallengeJSON = """
{
  "mfa_required": true,
  "challenge_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "factors": [
    {"id": "11111111-1111-1111-1111-111111111111", "type": "totp", "hint": null},
    {"id": "22222222-2222-2222-2222-222222222222", "type": "email", "hint": "m•••@example.com"}
  ]
}
""".data(using: .utf8)!

private let platformSessionJSON = """
{
  "session_token": "sess-platform",
  "expires_at": "2026-09-19T12:15:00Z",
  "refresh_expires_at": "2026-09-21T12:00:00Z",
  "scope": "platform"
}
""".data(using: .utf8)!

private let unauthorizedJSON = Data(#"{"error":"The password or email (ID) is incorrect"}"#.utf8)
private let noTenantAccessJSON = Data(#"{"code":"NO_TENANT_ACCESS","error":"your account has no access to tenant \"acme\""}"#.utf8)

// MARK: - Tests

// @MainActor because the nbledger module builds with default MainActor
// isolation — APIService and its models are main-actor isolated.
@MainActor
@Suite(.serialized)
struct APIServiceAuthTests {

    // MARK: Login

    @Test func logInPostsCredentialsOutsideTheTenantGroup() async throws {
        StubURLProtocol.install(stubSession) { _ in (200, sessionJSON) }
        let service = makeAuthService(token: "")
        defer { clearPersistedSession(service) }

        let outcome = try await service.logIn(tenant: "acme", email: "a@b.com", password: "pw")

        let req = try #require(StubURLProtocol.recorded(stubSession).first)
        // Session auth sits at the host root, NOT under /{tenant}/v1 — the
        // tenant travels in the body.
        #expect(req.url.absoluteString == "https://api.nobleledger.com/v1/auth/login")
        #expect(req.method == "POST")
        #expect(req.headers["Authorization"] == nil)
        let json = try #require(req.json)
        #expect(json["tenant"] as? String == "acme")
        #expect(json["email"] as? String == "a@b.com")
        #expect(json["password"] as? String == "pw")

        guard case .session = outcome else {
            Issue.record("expected a session, got \(outcome)")
            return
        }
        #expect(service.token == "sess-fresh")
        #expect(service.tenant == "acme")
        #expect(UserDefaults.standard.string(forKey: "authToken") == "sess-fresh")
    }

    @Test func logInParsesFractionalSecondExpiries() async throws {
        StubURLProtocol.install(stubSession) { _ in (200, sessionJSON) }
        let service = makeAuthService(token: "")
        defer { clearPersistedSession(service) }

        _ = try await service.logIn(tenant: "acme", email: "a@b.com", password: "pw")

        // .iso8601 alone rejects fractional seconds; losing the refresh expiry
        // would make canAttemptRefresh false and force a full login every 15
        // minutes.
        let sessionExpiry = try #require(service.sessionExpiresAt)
        let refreshExpiry = try #require(service.refreshExpiresAt)
        let expected = try #require(ISO8601DateFormatter().date(from: "2026-09-19T12:15:00Z"))
        #expect(abs(sessionExpiry.timeIntervalSince(expected)) < 1)
        #expect(refreshExpiry > sessionExpiry)
        #expect(service.canAttemptRefresh)
    }

    @Test func logInReturnsMFAChallengeWithoutInstallingASession() async throws {
        StubURLProtocol.install(stubSession) { _ in (200, mfaChallengeJSON) }
        let service = makeAuthService(token: "")
        defer { clearPersistedSession(service) }

        let outcome = try await service.logIn(tenant: "acme", email: "a@b.com", password: "pw")

        guard case .mfaRequired(let challengeID, let factors) = outcome else {
            Issue.record("expected an MFA challenge, got \(outcome)")
            return
        }
        #expect(challengeID == "3fa85f64-5717-4562-b3fc-2c963f66afa6")
        #expect(factors.map(\.type) == ["totp", "email"])
        #expect(factors[1].hint == "m•••@example.com")
        // A challenge is not a session.
        #expect(service.token.isEmpty)
    }

    @Test func logInRefusesAPlatformScopedSession() async throws {
        StubURLProtocol.install(stubSession) { _ in (200, platformSessionJSON) }
        let service = makeAuthService(token: "")
        defer { clearPersistedSession(service) }

        // A platform session authenticates /admin/v1 only and is refused by
        // every tenant route, so installing it would hand the user an app in
        // which nothing loads.
        await #expect(throws: APIError.self) {
            _ = try await service.logIn(tenant: "acme", email: "su@b.com", password: "pw")
        }
        #expect(service.token.isEmpty)
        #expect(UserDefaults.standard.string(forKey: "authToken") == nil)
    }

    @Test func logInSurfacesTheServerMessageOnRejection() async throws {
        StubURLProtocol.install(stubSession) { _ in (401, unauthorizedJSON) }
        let service = makeAuthService(token: "")
        defer { clearPersistedSession(service) }

        do {
            _ = try await service.logIn(tenant: "acme", email: "a@b.com", password: "wrong")
            Issue.record("expected a rejection")
        } catch let error as APIError {
            #expect(error.localizedDescription == "The password or email (ID) is incorrect")
        }
        #expect(service.token.isEmpty)
    }

    @Test func logInSurfacesNoTenantAccess() async throws {
        StubURLProtocol.install(stubSession) { _ in (403, noTenantAccessJSON) }
        let service = makeAuthService(token: "")
        defer { clearPersistedSession(service) }

        do {
            _ = try await service.logIn(tenant: "acme", email: "a@b.com", password: "pw")
            Issue.record("expected a rejection")
        } catch let error as APIError {
            #expect(error.localizedDescription.contains("no access to tenant"))
        }
        // A refused login must not repoint the client at the tenant it asked for.
        #expect(service.tenant == "public")
    }


    @Test func logInRefusesTheTemplateSchemaWithoutARoundTrip() async throws {
        StubURLProtocol.install(stubSession) { _ in (200, sessionJSON) }
        let service = makeAuthService(token: "")
        defer { clearPersistedSession(service) }

        // `public` is the template schema every tenant is cloned from; the
        // server refuses it on every path. Catch it here so the user gets an
        // actionable message and the attempt does not consume lockout budget.
        await #expect(throws: APIError.self) {
            _ = try await service.logIn(tenant: "public", email: "a@b.com", password: "pw")
        }
        await #expect(throws: APIError.self) {
            _ = try await service.logIn(tenant: "pg_catalog", email: "a@b.com", password: "pw")
        }
        #expect(StubURLProtocol.recorded(stubSession).isEmpty)
        #expect(service.token.isEmpty)
    }

    @Test func tenantScopedRequestsRefuseAnAbsentTenant() async throws {
        StubURLProtocol.install(stubSession) { _ in (200, Data("[]".utf8)) }
        let service = makeAuthService()
        service.tenant = ""
        defer { clearPersistedSession(service) }

        // The old code addressed /public/v1 in this case, which served the
        // seed ledger. No tenant means no session.
        // Matched by case rather than #expect(throws:) — APIError carries
        // payloads and is not Equatable.
        do {
            _ = try await service.fetchJournalHeaders()
            Issue.record("expected the request to be refused")
        } catch APIError.unauthorized {
            // expected
        }
        #expect(StubURLProtocol.recorded(stubSession).isEmpty)
    }

    // MARK: Refresh

    @Test func refreshSendsNoBearerAndNoBody() async throws {
        StubURLProtocol.install(stubSession) { _ in (200, rotatedSessionJSON) }
        let service = makeAuthService()
        defer { clearPersistedSession(service) }

        try await service.refreshAccessToken()

        let req = try #require(StubURLProtocol.recorded(stubSession).first)
        #expect(req.url.absoluteString == "https://api.nobleledger.com/v1/auth/refresh")
        #expect(req.method == "POST")
        // The credential is the HttpOnly refresh cookie; sending the stale
        // bearer or a body would both be wrong.
        #expect(req.headers["Authorization"] == nil)
        #expect(req.body == nil || req.body?.isEmpty == true)
        #expect(service.token == "sess-rotated")
    }

    @Test func concurrentUnauthorizedRequestsRotateTheSessionOnce() async throws {
        StubURLProtocol.install(stubSession) { req in
            if req.url.path == "/v1/auth/refresh" {
                return (200, rotatedSessionJSON)
            }
            // Only the stale token is refused, so the retry after rotation
            // succeeds.
            if req.headers["Authorization"] == "Bearer stale-token" {
                return (401, Data(#"{"error":"token expired"}"#.utf8))
            }
            return (200, Data("[]".utf8))
        }
        let service = makeAuthService()
        defer { clearPersistedSession(service) }

        // Six parallel reads is what the dashboard actually fires.
        async let a = service.fetchJournalHeaders()
        async let b = service.fetchJournalHeaders()
        async let c = service.fetchJournalHeaders()
        _ = try await (a, b, c)

        let refreshes = StubURLProtocol.recorded(stubSession).filter { $0.url.path == "/v1/auth/refresh" }
        // Two rotations would revoke the first refresh token and, outside the
        // server's 30s grace window, burn every session the user has.
        #expect(refreshes.count == 1)
        #expect(service.token == "sess-rotated")
    }

    @Test func expiredRefreshCredentialForcesFullLogoutWithoutARoundTrip() async throws {
        StubURLProtocol.install(stubSession) { _ in (401, Data(#"{"error":"token expired"}"#.utf8)) }
        let service = makeAuthService(canRefresh: false)
        defer { clearPersistedSession(service) }

        var unauthorizedFired = false
        var sessionExpiredFired = false
        service.onUnauthorized = { unauthorizedFired = true }
        service.onSessionExpired = { sessionExpiredFired = true }

        await #expect(throws: APIError.self) {
            _ = try await service.fetchJournalHeaders()
        }

        #expect(unauthorizedFired)
        #expect(!sessionExpiredFired)
        #expect(service.token.isEmpty)
        // Nothing should have been spent asking to rotate a dead credential.
        #expect(StubURLProtocol.recorded(stubSession).allSatisfy { $0.url.path != "/v1/auth/refresh" })
    }

    @Test func liveRefreshCredentialLocksToBiometricsInsteadOfLoggingOut() async throws {
        StubURLProtocol.install(stubSession) { req in
            if req.url.path == "/v1/auth/refresh" {
                return (401, Data(#"{"error":"invalid refresh token"}"#.utf8))
            }
            return (401, Data(#"{"error":"token expired"}"#.utf8))
        }
        let service = makeAuthService()
        defer { clearPersistedSession(service) }

        var unauthorizedFired = false
        var sessionExpiredFired = false
        service.onUnauthorized = { unauthorizedFired = true }
        service.onSessionExpired = { sessionExpiredFired = true }

        await #expect(throws: APIError.self) {
            _ = try await service.fetchJournalHeaders()
        }

        // The refresh cookie has not expired yet, so this is a lock-and-retry,
        // not a sign-out: the user unlocks with Face ID and the app rotates.
        #expect(sessionExpiredFired)
        #expect(!unauthorizedFired)
    }

    // MARK: Logout

    @Test func logOutRevokesServerSideThenClearsLocalState() async throws {
        StubURLProtocol.install(stubSession) { _ in (200, Data("{}".utf8)) }
        let service = makeAuthService(token: "sess-live")
        defer { clearPersistedSession(service) }

        await service.logOut()

        let req = try #require(StubURLProtocol.recorded(stubSession).first)
        #expect(req.url.absoluteString == "https://api.nobleledger.com/v1/auth/logout")
        #expect(req.method == "POST")
        // Logout is the one auth call that needs the session bearer.
        #expect(req.headers["Authorization"] == "Bearer sess-live")

        #expect(service.token.isEmpty)
        #expect(service.refreshExpiresAt == nil)
        #expect(!service.canAttemptRefresh)
        #expect(UserDefaults.standard.string(forKey: "authToken") == nil)
    }

    @Test func logOutClearsLocalStateEvenWhenTheServerCallFails() async throws {
        StubURLProtocol.install(stubSession) { _ in (500, Data(#"{"error":"boom"}"#.utf8)) }
        let service = makeAuthService(token: "sess-live")
        defer { clearPersistedSession(service) }

        await service.logOut()

        // A device that thinks it is still signed in is the worse outcome.
        #expect(service.token.isEmpty)
        #expect(!service.canAttemptRefresh)
    }
}
