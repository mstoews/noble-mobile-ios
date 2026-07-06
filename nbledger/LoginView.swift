
//
//  LoginView.swift
//  nbledger
//
//  Created by Murray Toews on 3/31/26.
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
    @State private var email = ""
    @State private var password = ""
    @State private var companyId = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentNonce: String?

    var onLoginSuccess: (LoginResponse) -> Void

    private var isFormComplete: Bool {
        !email.isEmpty && !password.isEmpty && !companyId.isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.12, blue: 0.22), Color(red: 0.14, green: 0.20, blue: 0.36)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("Noble Ledger")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("Sign in to your account")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)

                    TextField("Company ID", text: $companyId)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    Task { await login() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(isFormComplete ? Color(red: 0.20, green: 0.40, blue: 0.70) : Color(white: 0.85))
                .padding(.horizontal)
                .disabled(isLoading || !isFormComplete)

                HStack(spacing: 12) {
                    Rectangle()
                        .fill(.white.opacity(0.3))
                        .frame(height: 1)
                    Text("or")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                    Rectangle()
                        .fill(.white.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.horizontal)

                SignInWithAppleButton(.signIn) { request in
                    let nonce = randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = sha256(nonce)
                } onCompletion: { result in
                    Task { await handleAppleCompletion(result) }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 44)
                .padding(.horizontal)
                .disabled(isLoading || companyId.isEmpty)
                .opacity(companyId.isEmpty ? 0.5 : 1)

                if companyId.isEmpty {
                    Text("Enter your Company ID to use Sign in with Apple.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()
            }
        }
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
                let loginResponse = LoginResponse(
                    token: token,
                    refreshToken: refreshToken,
                    userName: userName,
                    userEmail: userEmail,
                    companyName: companyName,
                    tenant: companyId.trimmingCharacters(in: .whitespacesAndNewlines)
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

