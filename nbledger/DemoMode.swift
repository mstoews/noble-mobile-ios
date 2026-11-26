//
//  DemoMode.swift
//  nbledger
//
//  Test-only demo login. Launching a DEBUG build with `-UITestDemoLogin`
//  seeds a signed-in session so UI tests can reach the main shell on a
//  fresh simulator without real credentials:
//
//      app.launchArguments += [DemoMode.launchArgument]   // "-UITestDemoLogin"
//
//  The demo session never talks to the server: every API request is answered
//  on-device — sample data for the endpoints in DemoFixtures.swift, a 503 for
//  the rest — so the fake token can neither reach production nor trip the
//  401 → logout path.
//  The next launch without the argument wipes the seeded session.
//
//  Release builds compile all of this out: `isEnabled` is always false.
//

import Foundation

enum DemoMode {
    static let launchArgument = "-UITestDemoLogin"

    /// Marks UserDefaults as holding a demo session so a later normal launch
    /// knows to discard it.
    private static let markerKey = "demoSession"

    /// Every key the demo seeds, which is also what a normal launch clears.
    private static let sessionKeys = [
        "isLoggedIn", "authToken", "tenant", "userName", "userEmail",
        "companyName", "sessionExpiresAt", "refreshExpiresAt", markerKey,
    ]

    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(launchArgument)
        #else
        false
        #endif
    }

    /// Seeds (demo launch) or clears (normal launch after a demo) the stored
    /// session. Must run before `APIService` and the root view read defaults.
    static func prepareDefaults(_ defaults: UserDefaults = .standard) {
        if isEnabled {
            let values: [String: Any] = [
                "isLoggedIn": true,
                "authToken": "demo-token",
                "tenant": "demo",
                "userName": "Demo User",
                "userEmail": "demo@example.com",
                "companyName": "Demo Condominium Corp",
                "biometricEnabled": false,
                markerKey: true,
            ]
            values.forEach { defaults.set($0.value, forKey: $0.key) }
        } else if defaults.bool(forKey: markerKey) {
            sessionKeys.forEach(defaults.removeObject(forKey:))
        }
    }

    /// URLSession for the demo `APIService`: all traffic stays on-device.
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DemoURLProtocol.self]
        return URLSession(configuration: config)
    }
}

/// Serves sample data for the endpoints that have fixtures and a 503 for the
/// rest, so un-stubbed demo screens show a "no backend" error state.
nonisolated final class DemoURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url ?? URL(string: "about:blank")!
        let fixture = DemoFixtures.body(forPath: url.path)
        let response = HTTPURLResponse(
            url: url, statusCode: fixture == nil ? 503 : 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        let body = fixture ?? Data(#"{"message":"Demo mode: no backend connected."}"#.utf8)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
