
//
//  LoginView.swift
//  nbledger
//
//  Created by Murray Toews on 3/31/26.
//
//  Branded login (design_handoff_noble_mobile §1): emerald/slate gradient,
//  framed crown, and a remembered workspace card — the workspace persists
//  across sessions.
//
//  Auth is the server's session contract: POST /v1/auth/login returns an
//  opaque session token plus an HttpOnly refresh cookie. Sign in with Apple
//  was removed with the /api/login/apple route it depended on (2026-08-19);
//  there is no Apple path on the server to call.
//

import SwiftUI

/// What the login screen hands back to the shell. Deliberately carries no
/// token: `APIService.logIn` has already installed the session, so these are
/// only the fields the shell displays.
struct LoginResponse {
    let userName: String
    let userEmail: String
    let companyName: String
    let tenant: String
}

struct LoginView: View {
    @Environment(APIService.self) private var apiService

    // Survives logout — the "remembered workspace".
    @AppStorage("lastTenant") private var lastTenant = ""
    @AppStorage("lastCompanyName") private var lastCompanyName = ""

    @State private var email = ""
    @State private var password = ""
    @State private var workspace = ""
    @State private var isEditingWorkspace = false
    @State private var isLoading = false
    @State private var errorMessage: String?

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

                    if tenant.isEmpty {
                        Text("Set your workspace to sign in.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.top, 14)
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
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            switch try await apiService.logIn(tenant: tenant, email: email, password: password) {
            case .mfaRequired:
                // The server issued a challenge instead of a session. Finishing
                // it needs /v1/auth/mfa/select + /mfa/verify, which this app
                // does not implement yet — say so plainly rather than leaving
                // the user on a screen that cannot proceed.
                errorMessage = "This account uses two-factor authentication, which the app can't complete yet. Sign in on the web for now."
            case .session:
                await finishLogin()
            }
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
        }
    }

    /// The session response carries no display name or company, so the profile
    /// read is where those come from. It deliberately does not gate sign-in: a
    /// profile that fails to load — or a role without `profile.read` — still
    /// leaves a perfectly usable session, so fall back to what is already known.
    private func finishLogin() async {
        var userName = email.split(separator: "@").first.map(String.init) ?? ""
        var userEmail = email
        var companyName = lastCompanyName

        if let profile = try? await apiService.fetchMyProfile() {
            let resolved = profile.bestDisplayName
            if !resolved.isEmpty { userName = resolved }
            if let profileEmail = profile.email, !profileEmail.isEmpty { userEmail = profileEmail }
            if let company = profile.company, !company.isEmpty { companyName = company }
        }

        // Remember the workspace for the next session.
        lastTenant = tenant
        if !companyName.isEmpty { lastCompanyName = companyName }

        onLoginSuccess(LoginResponse(
            userName: userName,
            userEmail: userEmail,
            companyName: companyName,
            tenant: tenant
        ))
    }
}

#Preview {
    LoginView(onLoginSuccess: { _ in })
}
