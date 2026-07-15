	//
//  ContentView.swift
//  nbledger
//
//  Created by Murray Toews on 3/31/26.
//

import SwiftUI
import LocalAuthentication

struct ContentView: View {
    @Environment(APIService.self) private var apiService
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("authToken") private var authToken = ""
    @AppStorage("refreshToken") private var refreshToken = ""
    @AppStorage("userName") private var userName = ""
    @AppStorage("userEmail") private var userEmail = ""
    @AppStorage("companyName") private var companyName = ""
    @AppStorage("tenant") private var tenant = ""
    @AppStorage("biometricEnabled") private var biometricEnabled = false
    @AppStorage("darkAppearance") private var darkAppearance = false

    @State private var isUnlocked = false
    @State private var biometricFailed = false

    private var needsBiometric: Bool {
        isLoggedIn && (biometricEnabled || sessionExpired) && !isUnlocked
    }

    @State private var sessionExpired = false

    private func logout() {
        apiService.token = ""
        apiService.refreshToken = ""
        apiService.tenant = ""
        isLoggedIn = false
        isUnlocked = false
        sessionExpired = false
        authToken = ""
        refreshToken = ""
        userName = ""
        userEmail = ""
        companyName = ""
        tenant = ""
    }

    /// Called when the JWT expires but the refresh token may still be valid.
    /// Locks the screen so the user can re-authenticate with biometrics.
    private func handleSessionExpired() {
        isUnlocked = false
        sessionExpired = true
    }

    var body: some View {
        Group {
            if isLoggedIn && (isUnlocked || !biometricEnabled) {
                MainView(
                    userName: userName,
                    userEmail: userEmail,
                    companyName: companyName,
                    onLogout: logout
                )
                .onAppear {
                    apiService.onUnauthorized = { logout() }
                    apiService.onSessionExpired = { handleSessionExpired() }
                }
            } else if needsBiometric {
                biometricLockScreen
            } else {
                LoginView { response in
                    apiService.token = response.token
                    apiService.refreshToken = response.refreshToken
                    apiService.tenant = response.tenant
                    authToken = response.token
                    refreshToken = response.refreshToken
                    userName = response.userName
                    userEmail = response.userEmail
                    companyName = response.companyName
                    tenant = response.tenant
                    isLoggedIn = true
                    isUnlocked = true
                }
            }
        }
        // Dark toggle forces dark; off follows the system setting.
        .preferredColorScheme(darkAppearance ? .dark : nil)
        .task {
            if needsBiometric {
                await authenticate()
            }
        }
    }

    // MARK: - Biometric Lock Screen

    private var biometricLockScreen: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.12, blue: 0.22), Color(red: 0.14, green: 0.20, blue: 0.36)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "faceid")
                    .font(.system(size: 64))
                    .foregroundStyle(.white.opacity(0.8))

                Text("Noble Ledger")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                if sessionExpired {
                    Text("Session expired. Verify to continue.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }

                if biometricFailed {
                    Text("Authentication failed.")
                        .font(.subheadline)
                        .foregroundStyle(.red.opacity(0.9))

                    Button {
                        Task { await authenticate() }
                    } label: {
                        Text("Try Again")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.20, green: 0.40, blue: 0.70))
                    .padding(.horizontal, 40)

                    Button("Sign in with password") {
                        if sessionExpired {
                            logout()
                        } else {
                            biometricEnabled = false
                            isUnlocked = false
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    // MARK: - Biometric Auth

    private func authenticate() async {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricFailed = true
            return
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock Noble Ledger"
            )
            if success {
                apiService.refreshToken = refreshToken

                if sessionExpired || authToken.isEmpty {
                    // JWT expired — attempt refresh before unlocking
                    do {
                        try await apiService.refreshAccessToken()
                        // Save the new token
                        authToken = apiService.token
                        sessionExpired = false
                        isUnlocked = true
                        biometricFailed = false
                    } catch {
                        // Refresh token is also dead — force full login
                        logout()
                    }
                } else {
                    apiService.token = authToken
                    isUnlocked = true
                    biometricFailed = false
                }
            } else {
                biometricFailed = true
            }
        } catch {
            biometricFailed = true
        }
    }
}

#Preview {
    ContentView()
}
