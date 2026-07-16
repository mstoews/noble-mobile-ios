//
//  MoreView.swift
//  nbledger
//
//  More hub — profile card, the "Needs your action" group with live counts,
//  and NavigationLink pushes to everything outside the two primary tabs.
//

import SwiftUI

struct MoreView: View {
    @Environment(APIService.self) private var apiService

    let userName: String
    let userEmail: String
    let companyName: String
    /// Programmatic navigation (the capture loop pushes the sign-off queue here).
    @Binding var path: [MoreDestination]
    /// Success banner handed to Payment Sign-Off after a captured draft is created.
    @Binding var captureBanner: String?
    var onLogout: () -> Void

    @State private var signOffCount: Int?
    @State private var signOffAmount = 0.0
    @State private var openJournalCount: Int?
    @State private var openJournalAmount = 0.0
    @State private var role: String?
    @State private var title: String?
    @State private var showAssistant = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    profileCard
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section("Needs your action") {
                    NavigationLink(value: MoreDestination.paymentSignOff) {
                        MoreRow(
                            icon: "checkmark",
                            iconTint: .white,
                            iconBackground: .nobleEmerald,
                            title: "Payment Sign-Off",
                            subtitle: signOffSubtitle,
                            badge: signOffCount,
                            badgeColor: .nobleWarn
                        )
                    }
                    NavigationLink(value: MoreDestination.journalBooking) {
                        MoreRow(
                            icon: "doc.text",
                            iconTint: .white,
                            iconBackground: .nobleEmerald,
                            title: "Journal Booking",
                            subtitle: journalSubtitle,
                            badge: openJournalCount,
                            badgeColor: .nobleAmber
                        )
                    }
                }

                Section("Money") {
                    NavigationLink(value: MoreDestination.payables) {
                        MoreRow(
                            icon: "arrow.up",
                            iconTint: .nobleEmerald,
                            iconBackground: .nobleEmeraldSoft,
                            title: "Payables",
                            subtitle: "Bills & vendor payments"
                        )
                    }
                    NavigationLink(value: MoreDestination.receivables) {
                        MoreRow(
                            icon: "arrow.down",
                            iconTint: .nobleEmerald,
                            iconBackground: .nobleEmeraldSoft,
                            title: "Receivables",
                            subtitle: "Customer invoices"
                        )
                    }
                    NavigationLink(value: MoreDestination.banking) {
                        MoreRow(
                            icon: "building.columns",
                            iconTint: .nobleEmerald,
                            iconBackground: .nobleEmeraldSoft,
                            title: "Banking",
                            subtitle: "Accounts connected via Plaid"
                        )
                    }
                }

                Section("Planning") {
                    NavigationLink(value: MoreDestination.budget) {
                        MoreRow(
                            icon: "chart.pie",
                            iconTint: .nobleEmerald,
                            iconBackground: .nobleEmeraldSoft,
                            title: "Budget",
                            subtitle: "Actuals vs plan, variance & forecast"
                        )
                    }
                }

                Section("Ledger") {
                    NavigationLink(value: MoreDestination.journals) {
                        MoreRow(
                            icon: "doc.text",
                            iconTint: .nobleSlate,
                            iconBackground: Color(.tertiarySystemFill),
                            title: "Journals",
                            subtitle: "Browse, create & manage entries"
                        )
                    }
                    NavigationLink(value: MoreDestination.accounts) {
                        MoreRow(
                            icon: "list.bullet.rectangle",
                            iconTint: .nobleSlate,
                            iconBackground: Color(.tertiarySystemFill),
                            title: "Chart of Accounts",
                            subtitle: "GL accounts & balances"
                        )
                    }
                }

                Section("Assistant") {
                    Button {
                        showAssistant = true
                    } label: {
                        MoreRow(
                            icon: "sparkles",
                            iconTint: .nobleSlate,
                            iconBackground: Color(.tertiarySystemFill),
                            title: "AI Assistant",
                            subtitle: "Ask about your books"
                        )
                    }
                    .buttonStyle(.plain)
                }

                Section {
                    NavigationLink(value: MoreDestination.settings) {
                        MoreRow(
                            icon: "gearshape",
                            iconTint: .nobleSlate,
                            iconBackground: Color(.tertiarySystemFill),
                            title: "Settings",
                            subtitle: "Security, Face ID, log out"
                        )
                    }
                } header: {
                    Text("Account")
                } footer: {
                    Text("Noble Ledger · \(appVersion)")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: MoreDestination.self) { dest in
                switch dest {
                case .paymentSignOff: PaymentSignOffView()
                case .journalBooking: JournalBookingView(banner: $captureBanner)
                case .payables: APPayablesView()
                case .receivables: ARReceivablesView()
                case .banking: BankingView()
                case .budget: BudgetView()
                case .journals: GLJournalView()
                case .accounts: LedgerView()
                case .settings:
                    SettingsView(
                        userName: userName,
                        userEmail: userEmail,
                        companyName: companyName,
                        onLogout: onLogout
                    )
                }
            }
            .sheet(isPresented: $showAssistant) {
                AgentChatView(onOpenDestination: { destination in
                    showAssistant = false
                    path.append(destination)
                })
            }
            .task { await loadCounts() }
            .refreshable { await loadCounts() }
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(Color.nobleSlate, lineWidth: 1.5)
                .frame(width: 44, height: 44)
                .overlay {
                    Image("NobleCrown")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 27, height: 27)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(companyName.isEmpty ? "Noble Ledger" : companyName)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(profileSubtitle)
                    .font(.caption)
                    .foregroundStyle(Color.nobleSlateMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if let role, !role.isEmpty {
                Text(role.uppercased())
                    .font(.caption2.weight(.bold))
                    .kerning(0.4)
                    .foregroundStyle(Color.nobleEmeraldOnDark)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.nobleEmerald.opacity(0.35), in: Capsule())
            }
        }
        .padding(16)
        .background(Color.nobleSlateInk, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.nobleSlateInk.opacity(0.25), radius: 9, x: 0, y: 6)
    }

    private var profileSubtitle: String {
        let name = userName.isEmpty ? userEmail : userName
        if let title, !title.isEmpty {
            return "\(name) · \(title)"
        }
        return name
    }

    // MARK: - Subtitles

    private var signOffSubtitle: String {
        guard let signOffCount else { return "Approve vendor bills" }
        if signOffCount == 0 { return "Nothing awaiting approval" }
        return "\(signOffAmount.formatted(.currency(code: "USD"))) awaiting approval"
    }

    private var journalSubtitle: String {
        guard let openJournalCount else { return "Close & book journal entries" }
        if openJournalCount == 0 { return "All entries booked" }
        let entries = openJournalCount == 1 ? "1 open entry" : "\(openJournalCount) open entries"
        return "\(entries) · \(openJournalAmount.formatted(.currency(code: "USD")))"
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

    // MARK: - Data

    private func loadCounts() async {
        // Sequential calls per the app's concurrency convention.
        var year = Calendar.current.component(.year, from: Date())
        if let period = try? await apiService.fetchCurrentActivePeriod() {
            year = period.periodYear
        }
        if let bills = try? await apiService.fetchAgingBills(periodYear: year, status: "ALL") {
            let awaiting = bills.filter {
                $0.approvalStatus == "PENDING" || $0.approvalStatus == "REVIEW"
            }
            signOffCount = awaiting.count
            signOffAmount = awaiting.map(\.amount).reduce(0, +)
        }
        if let journals = try? await apiService.fetchJournalHeaders() {
            let open = journals.filter { ($0.status ?? "") == "OPEN" && $0.booked != true }
            openJournalCount = open.count
            openJournalAmount = open.compactMap(\.amount).reduce(0, +)
        }
        if let profile = try? await apiService.fetchMyProfile() {
            role = profile.role
            title = profile.title
        }
    }
}

// MARK: - Destination

enum MoreDestination: Hashable {
    case paymentSignOff
    case journalBooking
    case payables
    case receivables
    case banking
    case budget
    case journals
    case accounts
    case settings
}

// MARK: - Row

private struct MoreRow: View {
    let icon: String
    let iconTint: Color
    let iconBackground: Color
    let title: String
    var subtitle: String? = nil
    var badge: Int? = nil
    var badgeColor: Color = .nobleWarn

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(iconBackground)
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: icon)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(iconTint)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let badge, badge > 0 {
                Text("\(badge)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(badgeColor, in: Capsule())
                    .accessibilityLabel("\(badge) items need attention")
            }
        }
        .padding(.vertical, 2)
    }
}
