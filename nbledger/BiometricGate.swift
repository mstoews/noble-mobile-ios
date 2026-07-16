//
//  BiometricGate.swift
//  nbledger
//
//  Face ID / passcode confirmation in front of ledger mutations
//  (sign-off, booking, recording payments). Devices with no local
//  authentication available do not block the action — the server
//  still enforces roles and separation of duties.
//

import LocalAuthentication

enum BiometricGate {
    static func confirm(_ reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return true
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
