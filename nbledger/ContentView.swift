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
                stops: [
                    .init(color: .nobleSlateInk, location: 0),
                    .init(color: Color(red: 18 / 255, green: 63 / 255, blue: 51 / 255), location: 0.55),
                    .init(color: .nobleEmeraldHighlight, location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.nobleSlate, lineWidth: 2)
                    .background(Color.nobleSlateInk.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image("NobleCrown")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                    }
                    .accessibilityHidden(true)

                Text("Noble Ledger")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)

                if sessionExpired {
                    Text("Session expired. Verify to continue.")
                        .font(.subheadline)
                        .foregroundStyle(Color.nobleSlateMuted)
                }

                Button {
                    Task { await authenticate() }
                } label: {
                    Label("Unlock with Face ID", systemImage: "faceid")
                        .font(.headline)
                        .foregroundStyle(Color.nobleEmeraldOnDark)
                }
                .padding(.top, 10)

                if biometricFailed {
                    Text("Authentication failed.")
                        .font(.subheadline)
                        .foregroundStyle(Color.nobleWarnSoft)

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
            .padding(.horizontal, 24)
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
