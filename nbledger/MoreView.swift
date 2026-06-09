//
//  MoreView.swift
//  nbledger
//
//  Custom "More" tab — replaces SwiftUI's default TabView overflow list.
//

import SwiftUI

struct MoreView: View {
    let userName: String
    let userEmail: String
    let companyName: String
    var onLogout: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    grid
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: MoreDestination.self) { dest in
                switch dest {
                case .payables: APPayablesView()
                case .banking: BankingView()
                case .receivables: ARReceivablesView()
                case .paymentSignOff: PaymentSignOffView()
                case .journalBooking: JournalBookingView()
                case .settings:
                    SettingsView(
                        userName: userName,
                        userEmail: userEmail,
                        companyName: companyName,
                        onLogout: onLogout
                    )
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.18))
                Image(systemName: "building.2.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(companyName.isEmpty ? "Noble Ledger" : companyName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !userName.isEmpty {
                    Text(userName)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.14, green: 0.20, blue: 0.36),
                    Color(red: 0.20, green: 0.40, blue: 0.70)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }

    // MARK: - Grid

    private var grid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
            spacing: 14
        ) {
            ForEach(MoreDestination.allCases) { dest in
                NavigationLink(value: dest) {
                    MoreCard(destination: dest)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Destination

enum MoreDestination: String, CaseIterable, Identifiable, Hashable {
    case payables
    case banking
    case receivables
    case paymentSignOff
    case journalBooking
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .payables: return "Payables"
        case .banking: return "Banking"
        case .receivables: return "Receivables"
        case .paymentSignOff: return "Payment Sign-Off"
        case .journalBooking: return "Journal Booking"
        case .settings: return "Settings"
        }
    }

    var subtitle: String {
        switch self {
        case .payables: return "Bills & vendor payments"
        case .banking: return "Connected bank accounts"
        case .receivables: return "Customer invoices"
        case .paymentSignOff: return "Approve vendor bills"
        case .journalBooking: return "Close & book journal entries"
        case .settings: return "Account & security"
        }
    }

    var systemImage: String {
        switch self {
        case .payables: return "creditcard.fill"
        case .banking: return "building.columns.fill"
        case .receivables: return "dollarsign.arrow.circlepath"
        case .paymentSignOff: return "checkmark.seal.fill"
        case .journalBooking: return "book.closed.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var tint: Color {
        switch self {
        case .payables: return Color(red: 0.20, green: 0.45, blue: 0.85)
        case .banking: return Color(red: 0.10, green: 0.55, blue: 0.55)
        case .receivables: return Color(red: 0.85, green: 0.50, blue: 0.15)
        case .paymentSignOff: return Color(red: 0.45, green: 0.30, blue: 0.75)
        case .journalBooking: return Color(red: 0.15, green: 0.60, blue: 0.35)
        case .settings: return Color(red: 0.35, green: 0.38, blue: 0.45)
        }
    }
}

// MARK: - Card

private struct MoreCard: View {
    let destination: MoreDestination

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                Circle()
                    .fill(destination.tint.opacity(0.15))
                Image(systemName: destination.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(destination.tint)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(destination.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(destination.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .frame(height: 140)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
