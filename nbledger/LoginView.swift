
//
//  LoginView.swift
//  nbledger
//
//  Created by Murray Toews on 3/31/26.
//

import SwiftUI

struct LoginResponse {
    let token: String
    let refreshToken: String
    let userName: String
    let userEmail: String
    let companyName: String
}

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var companyId = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

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

                Spacer()
            }
        }
    }

    private func login() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

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
                let userName = userDict?["name"] as? String ?? json["name"] as? String ?? ""
                let userEmail = userDict?["email"] as? String ?? json["email"] as? String ?? email
                let companyDict = json["company"] as? [String: Any]
                let companyName = companyDict?["name"] as? String ?? json["company_name"] as? String ?? ""
                let loginResponse = LoginResponse(token: token, refreshToken: refreshToken, userName: userName, userEmail: userEmail, companyName: companyName)
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

