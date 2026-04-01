//
//  MainView.swift
//  nbledger
//
//  Created by Murray Toews on 3/31/26.
//

import SwiftUI

struct MainView: View {
    let userName: String
    let userEmail: String
    let companyName: String
    var onLogout: () -> Void

    var body: some View {
        TabView {
            DashboardView(userName: userName, companyName: companyName)
                .tabItem {
                    Label("Dashboard", systemImage: "house")
                }

            LedgerView()
                .tabItem {
                    Label("Ledger", systemImage: "list.bullet.rectangle")
                }

            SettingsView(
                userName: userName,
                userEmail: userEmail,
                companyName: companyName,
                onLogout: onLogout
            )
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    let userName: String
    let companyName: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Greeting
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hello, \(userName.isEmpty ? "there" : userName)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        if !companyName.isEmpty {
                            Text(companyName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    // Summary Cards
                    VStack(spacing: 12) {
                        SummaryCard(title: "Total Assets", amount: "$0.00", color: .blue)
                        SummaryCard(title: "Total Liabilities", amount: "$0.00", color: .red)
                        SummaryCard(title: "Net Balance", amount: "$0.00", color: .green)
                    }
                    .padding(.horizontal)

                    // Recent Entries
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Entries")
                            .font(.headline)
                            .padding(.horizontal)

                        Text("No entries yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Dashboard")
        }
    }
}

struct SummaryCard: View {
    let title: String
    let amount: String
    let color: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(amount)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            Spacer()
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: cardIcon(for: title))
                        .foregroundStyle(color)
                }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func cardIcon(for title: String) -> String {
        switch title {
        case "Total Assets":    return "arrow.up.circle"
        case "Total Liabilities": return "arrow.down.circle"
        default:                return "scalemass"
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    let userName: String
    let userEmail: String
    let companyName: String
    var onLogout: () -> Void

    @State private var showLogoutConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    LabeledContent("Name", value: userName.isEmpty ? "—" : userName)
                    LabeledContent("Email", value: userEmail.isEmpty ? "—" : userEmail)
                    if !companyName.isEmpty {
                        LabeledContent("Company", value: companyName)
                    }
                }

                Section {
                    Button("Log Out", role: .destructive) {
                        showLogoutConfirmation = true
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Are you sure you want to log out?", isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
                Button("Log Out", role: .destructive, action: onLogout)
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MainView(
        userName: "Jane Smith",
        userEmail: "jane@example.com",
        companyName: "Acme Corp",
        onLogout: {}
    )
}
