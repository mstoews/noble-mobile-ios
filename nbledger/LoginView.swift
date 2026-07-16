
//
//  LoginView.swift
//  nbledger
//
//  Created by Murray Toews on 3/31/26.
//
//  Branded login (design_handoff_noble_mobile §1): emerald/slate gradient,
//  framed crown, remembered workspace card, and Sign in with Apple no longer
//  gated behind a Company ID field — the workspace persists across sessions.
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import Security

struct LoginResponse {
    let token: String
    let refreshToken: String
    let userName: String
    let userEmail: String
    let companyName: String
    let tenant: String
}

struct LoginView: View {
    // Survives logout — the "remembered workspace".
    @AppStorage("lastTenant") private var lastTenant = ""
    @AppStorage("lastCompanyName") private var lastCompanyName = ""

    @State private var email = ""
    @State private var password = ""
    @State private var workspace = ""
    @State private var isEditingWorkspace = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentNonce: String?

    var onLoginSuccess: (LoginResponse) -> Void

    private var tenant: String {
        workspace.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canLogIn: Bool {
        !email.isEmpty && !password.isEmpty && !tenant.isEmpty
    }

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (short, build) {
        case let (short?, build?): return "v\(short).\(build)"
        case let (short?, nil): return "v\(short)"
        default: return ""
        }
    }

    var body: some View {
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

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)

                    // Crown lockup
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
                        .padding(.top, 14)
                    Text("Accounting for condominium corporations")
                        .font(.subheadline)
                        .foregroundStyle(Color.nobleSlateMuted)
                        .padding(.top, 3)

                    VStack(spacing: 10) {
                        workspaceRow

                        loginField {
                            TextField("", text: $email, prompt: prompt("Email address"))
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }

                        loginField {
                            SecureField("", text: $password, prompt: prompt("Password"))
                                .textContentType(.password)
                        }
                    }
                    .padding(.top, 28)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Color.nobleWarnSoft)
                            .multilineTextAlignment(.center)
                            .padding(.top, 12)
                    }

                    Button {
                        Task { await login() }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Log In")
                                    .font(.headline)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            canLogIn ? Color.nobleEmeraldBright : Color.nobleEmeraldBright.opacity(0.4),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                    }
                    .disabled(isLoading || !canLogIn)
                    .padding(.top, 16)

                    HStack(spacing: 12) {
                        Rectangle().fill(.white.opacity(0.18)).frame(height: 1)
                        Text("or")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                        Rectangle().fill(.white.opacity(0.18)).frame(height: 1)
                    }
                    .padding(.vertical, 14)

                    SignInWithAppleButton(.signIn) { request in
                        let nonce = randomNonceString()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = sha256(nonce)
                    } onCompletion: { result in
                        Task { await handleAppleCompletion(result) }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .disabled(isLoading || tenant.isEmpty)
                    .opacity(tenant.isEmpty ? 0.5 : 1)

                    if tenant.isEmpty {
                        Text("Set your workspace to sign in.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.top, 10)
                    }

                    Spacer(minLength: 32)

                    Text(appVersion)
                        .font(.caption2)
                        .foregroundStyle(Color.nobleSlateMuted.opacity(0.8))
                        .padding(.bottom, 12)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .tint(Color.nobleEmeraldOnDark)
        .onAppear {
            if workspace.isEmpty {
                workspace = lastTenant
            }
            isEditingWorkspace = tenant.isEmpty
        }
    }

    // MARK: - Workspace card / field

    @ViewBuilder
    private var workspaceRow: some View {
        if isEditingWorkspace {
            loginField {
                TextField("", text: $workspace, prompt: prompt("Workspace"))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit {
                        if !tenant.isEmpty { isEditingWorkspace = false }
                    }
            }
        } else {
            HStack(spacing: 10) {
                Image(systemName: "building.2")
                    .font(.subheadline)
                    .foregroundStyle(Color.nobleEmeraldOnDark)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Workspace")
                        .font(.caption2)
                        .foregroundStyle(Color.nobleSlateMuted)
                    Text(lastCompanyName.isEmpty ? workspace : lastCompanyName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Button("Change") {
                    isEditingWorkspace = true
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.nobleEmeraldOnDark)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.13), lineWidth: 1)
            )
        }
    }

    private func prompt(_ text: String) -> Text {
        Text(text).foregroundStyle(Color.nobleSlateMuted)
    }

    private func loginField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.13), lineWidth: 1)
            )
    }

    private func login() async {
        guard let url = URL(string: "https://api.nobleledger.com/api/login") else {
            errorMessage = "Invalid server URL."
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body =
          ["Email": email, "Password": password, "returnSecureToken": true
          ] as [String : Any]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            errorMessage = "Failed to encode request."
            return
        }

        await performLogin(request: request, fallbackEmail: email)
    }

    // MARK: - Sign in with Apple

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Apple sign-in failed: missing credentials."
                return
            }
            // Apple only provides name/email on the first authorization for this app
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            await loginWithApple(
                identityToken: identityToken,
                rawNonce: nonce,
                fullName: fullName,
                appleEmail: credential.email
            )
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return
            }
            errorMessage = "Apple sign-in failed: \(error.localizedDescription)"
        }
    }

    private func loginWithApple(identityToken: String, rawNonce: String, fullName: String, appleEmail: String?) async {
        guard let url = URL(string: "https://api.nobleledger.com/api/login/apple") else {
            errorMessage = "Invalid server URL."
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "identityToken": identityToken,
            "rawNonce": rawNonce,
            "returnSecureToken": true
        ]
        if !fullName.isEmpty { body["fullName"] = fullName }
        if let appleEmail { body["email"] = appleEmail }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            errorMessage = "Failed to encode request."
            return
        }

        await performLogin(request: request, fallbackEmail: appleEmail ?? "")
    }

    /// Random URL-safe nonce for the Apple → Firebase token exchange.
    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        while result.count < length {
            var random: UInt8 = 0
            guard SecRandomCopyBytes(kSecRandomDefault, 1, &random) == errSecSuccess else {
                continue
            }
            if random < charset.count {
                result.append(charset[Int(random)])
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    // MARK: - Shared login request handling

    private func performLogin(request: URLRequest, fallbackEmail: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid server response."
                return
            }

            if httpResponse.statusCode == 200 {
                let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                let token = json["idToken"] as? String ?? ""
                let refreshToken = json["refreshToken"] as? String ?? ""
                // Support both flat and nested user objects
                let userDict = json["user"] as? [String: Any]
                let userName = userDict?["name"] as? String
                    ?? json["name"] as? String
                    ?? json["displayName"] as? String
                    ?? ""
                let userEmail = userDict?["email"] as? String ?? json["email"] as? String ?? fallbackEmail
                let companyDict = json["company"] as? [String: Any]
                let companyName = companyDict?["name"] as? String ?? json["company_name"] as? String ?? ""

                // Remember the workspace for the next session.
                lastTenant = tenant
                if !companyName.isEmpty {
                    lastCompanyName = companyName
                }

                let loginResponse = LoginResponse(
                    token: token,
                    refreshToken: refreshToken,
                    userName: userName,
                    userEmail: userEmail,
                    companyName: companyName,
                    tenant: tenant
                )
                onLoginSuccess(loginResponse)
            } else {
                // Try to extract an error message from the response body
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String ?? json["error"] as? String {
                    errorMessage = message
                } else {
                    errorMessage = "Login failed (HTTP \(httpResponse.statusCode))."
                }
            }
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
        }
    }
}

#Preview {
    LoginView(onLoginSuccess: { _ in })
}
