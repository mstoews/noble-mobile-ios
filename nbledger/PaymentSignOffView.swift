//
//  PaymentSignOffView.swift
//  nbledger
//
//  Administrator sign-off queue for AP bills. Bills move through the
//  server-side approval state machine: PENDING → REVIEW → APPROVED/DENIED.
//  The server enforces role permissions and forbids self-sign-off.
//

import SwiftUI

enum SignOffFilterTab: String, CaseIterable {
    case pending = "Pending"
    case review = "Review"
    case approved = "Approved"
    case denied = "Denied"

    var status: String {
        switch self {
        case .pending: return "PENDING"
        case .review: return "REVIEW"
        case .approved: return "APPROVED"
        case .denied: return "DENIED"
        }
    }
}

struct PaymentSignOffView: View {
    @Environment(APIService.self) private var apiService

    @State private var bills: [AgingBill] = []
    @State private var vendorNames: [String: String] = [:]
    @State private var activeFilter: SignOffFilterTab = .pending
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var readOnlyRole = false

    private var filteredBills: [AgingBill] {
        bills.filter { $0.approvalStatus == activeFilter.status }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $activeFilter) {
                ForEach(SignOffFilterTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if readOnlyRole {
                Label("Your role is read-only for approvals", systemImage: "eye")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill))
            }

            content
        }
        .navigationTitle("Payment Sign-Off")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
        .refreshable { await loadData() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && bills.isEmpty {
            ProgressView("Loading bills...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text(errorMessage)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    Task { await loadData() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredBills.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No \(activeFilter.rawValue.lowercased()) bills")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(filteredBills) { bill in
                NavigationLink {
                    BillSignOffDetailView(
                        bill: bill,
                        vendorName: vendorNames[bill.vendorId],
                        readOnlyRole: readOnlyRole,
                        onUpdated: { Task { await loadData() } }
                    )
                } label: {
                    SignOffBillRow(bill: bill, vendorName: vendorNames[bill.vendorId])
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            var year = Calendar.current.component(.year, from: Date())
            if let period = try? await apiService.fetchCurrentActivePeriod() {
                year = period.periodYear
            }
            bills = try await apiService.fetchAgingBills(periodYear: year, status: "ALL")

            if let vendors = try? await apiService.fetchApVendors() {
                vendorNames = Dictionary(uniqueKeysWithValues: vendors.map { ($0.id, $0.name) })
            }

            if let profile = try? await apiService.fetchMyProfile() {
                let role = (profile.role ?? "").uppercased()
                readOnlyRole = role == "AUDITOR" || role == "REVIEWER"
            }
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Row

struct SignOffBillRow: View {
    let bill: AgingBill
    let vendorName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(bill.description.isEmpty ? "Bill \(bill.invoiceNumber)" : bill.description)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer()
                ApprovalStatusBadge(status: bill.approvalStatus)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vendorName ?? bill.vendorId)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if !bill.invoiceNumber.isEmpty {
                        Text("Inv: \(bill.invoiceNumber)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(bill.amount, format: .currency(code: "USD"))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    Text("Due \(bill.dueDate)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Approval Badge

struct ApprovalStatusBadge: View {
    let status: String

    private var color: Color {
        switch status {
        case "PENDING": return .orange
        case "REVIEW": return .blue
        case "APPROVED": return .green
        case "DENIED": return .red
        default: return .secondary
        }
    }

    var body: some View {
        Text(status)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

// MARK: - Detail

struct BillSignOffDetailView: View {
    @Environment(APIService.self) private var apiService
    @Environment(\.dismiss) private var dismiss

    let bill: AgingBill
    let vendorName: String?
    let readOnlyRole: Bool
    var onUpdated: () -> Void

    @State private var approvalStatus: String
    @State private var history: ApprovalHistory?
    @State private var isLoadingHistory = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var pendingTransition: String?
    @State private var showTransitionConfirmation = false

    init(bill: AgingBill, vendorName: String?, readOnlyRole: Bool, onUpdated: @escaping () -> Void) {
        self.bill = bill
        self.vendorName = vendorName
        self.readOnlyRole = readOnlyRole
        self.onUpdated = onUpdated
        _approvalStatus = State(initialValue: bill.approvalStatus)
    }

    var body: some View {
        List {
            Section("Bill") {
                DetailRow(label: "Description", value: bill.description)
                DetailRow(label: "Vendor", value: vendorName ?? bill.vendorId)
                DetailRow(label: "Invoice #", value: bill.invoiceNumber)
                HStack {
                    Text("Approval")
                    Spacer()
                    ApprovalStatusBadge(status: approvalStatus)
                }
                DetailRow(label: "Bill Status", value: bill.status)
                DetailRow(label: "Transaction Date", value: bill.transactionDate)
                DetailRow(label: "Due Date", value: bill.dueDate)
            }

            Section("Amounts") {
                HStack {
                    Text("Amount")
                    Spacer()
                    Text(bill.amount, format: .currency(code: "USD")).monospacedDigit()
                }
                HStack {
                    Text("Paid")
                    Spacer()
                    Text(bill.amountPaid, format: .currency(code: "USD"))
                        .monospacedDigit()
                        .foregroundStyle(.green)
                }
                HStack {
                    Text("Remaining")
                    Spacer()
                    Text(bill.remainder, format: .currency(code: "USD"))
                        .monospacedDigit()
                        .foregroundStyle(bill.remainder > 0 ? .red : .green)
                }
            }

            if !bill.funds.isEmpty {
                Section("Funds") {
                    ForEach(bill.funds, id: \.fund) { fund in
                        HStack {
                            Text(fund.fund)
                            Spacer()
                            Text(fund.amount, format: .currency(code: "USD")).monospacedDigit()
                        }
                        .font(.subheadline)
                    }
                }
            }

            historySection

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }

            if !readOnlyRole {
                actionsSection
            }
        }
        .navigationTitle("Bill J-\(bill.journalId)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadHistory() }
        .confirmationDialog(
            transitionPrompt,
            isPresented: $showTransitionConfirmation,
            titleVisibility: .visible
        ) {
            if let pendingTransition {
                Button(transitionLabel(pendingTransition), role: pendingTransition == "DENIED" ? .destructive : nil) {
                    Task { await applyTransition(pendingTransition) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var transitionPrompt: String {
        guard let pendingTransition else { return "" }
        return "\(transitionLabel(pendingTransition)) bill J-\(bill.journalId)?"
    }

    private func transitionLabel(_ status: String) -> String {
        switch status {
        case "REVIEW": return approvalStatus == "PENDING" ? "Move to Review" : "Return to Review"
        case "APPROVED": return "Approve"
        case "DENIED": return "Deny"
        case "PENDING": return approvalStatus == "DENIED" ? "Resubmit" : "Return to Pending"
        default: return status
        }
    }

    // Allowed transitions mirror the server state machine; the server is
    // still the authority (role + self-sign-off checks happen there).
    private var availableTransitions: [String] {
        switch approvalStatus {
        case "PENDING": return ["REVIEW", "APPROVED", "DENIED"]
        case "REVIEW": return ["APPROVED", "DENIED", "PENDING"]
        case "DENIED": return ["PENDING"]
        default: return []
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        if approvalStatus == "APPROVED" {
            Section {
                Label("Approved — no further action available", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
        } else {
            Section {
                ForEach(availableTransitions, id: \.self) { target in
                    Button(role: target == "DENIED" ? .destructive : nil) {
                        pendingTransition = target
                        showTransitionConfirmation = true
                    } label: {
                        if isSubmitting && pendingTransition == target {
                            HStack {
                                ProgressView()
                                Text(transitionLabel(target))
                            }
                        } else {
                            Label(transitionLabel(target), systemImage: transitionIcon(target))
                        }
                    }
                    .disabled(isSubmitting)
                }
            } header: {
                Text("Sign-Off")
            } footer: {
                Text("You cannot approve or deny a bill you created — another administrator must sign it off.")
            }
        }
    }

    private func transitionIcon(_ status: String) -> String {
        switch status {
        case "REVIEW": return "eye"
        case "APPROVED": return "checkmark.seal"
        case "DENIED": return "xmark.seal"
        case "PENDING": return "arrow.uturn.backward"
        default: return "questionmark"
        }
    }

    @ViewBuilder
    private var historySection: some View {
        Section("Approval History") {
            if isLoadingHistory {
                ProgressView()
            } else if let events = history?.events, !events.isEmpty {
                ForEach(events) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.actorDisplayName ?? event.actorEmail ?? event.actorUserId ?? "Unknown")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            if let occurredAt = event.occurredAt {
                                Text(formatTimestamp(occurredAt))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        HStack(spacing: 6) {
                            if let prior = event.priorState {
                                ApprovalStatusBadge(status: prior)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let newState = event.newState {
                                ApprovalStatusBadge(status: newState)
                            }
                            if let reason = event.rejectionReason {
                                Text(reason)
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                        }
                        if let note = event.note, !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } else {
                Text("No approval activity yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formatTimestamp(_ raw: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        guard let date else { return raw }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func loadHistory() async {
        isLoadingHistory = true
        history = try? await apiService.fetchJournalApprovalHistory(journalId: bill.journalId)
        isLoadingHistory = false
    }

    private func applyTransition(_ target: String) async {
        isSubmitting = true
        errorMessage = nil
        do {
            let response = try await apiService.updateBillApproval(journalId: bill.journalId, approvalStatus: target)
            approvalStatus = response.approvalStatus
            await loadHistory()
            onUpdated()
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
        pendingTransition = nil
    }
}

// MARK: - Shared detail row

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
