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
                    BillDetailView(
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

/// The one bill detail view, pushed from Payment Sign-Off, Activity and
/// Payables. It carries approval (its original job) plus what has been paid
/// and what is scheduled, so those screens do not each grow their own.
struct BillDetailView: View {
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
    @State private var payments: [BillPayment] = []
    @State private var schedules: [BillPaymentSchedule] = []
    @State private var isLoadingPayments = false
    @State private var showScheduleSheet = false

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

            paymentsSection
            schedulesSection
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

                if bill.isPosted, !bill.isPaid {
                    Section {
                        Button {
                            showScheduleSheet = true
                        } label: {
                            Label("Schedule payment", systemImage: "calendar.badge.plus")
                        }
                    } footer: {
                        Text("Schedules a future-dated payment. Recording a payment already made is not supported in the app yet.")
                    }
                }
            }
        }
        .navigationTitle("Bill J-\(bill.journalId)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadHistory()
            await loadPayments()
        }
        .sheet(isPresented: $showScheduleSheet) {
            ScheduleBillPaymentSheet(bill: bill) {
                showScheduleSheet = false
                Task { await loadPayments() }
            }
        }
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

    // MARK: Payments

    @ViewBuilder
    private var paymentsSection: some View {
        if isLoadingPayments {
            Section("Payments") { ProgressView() }
        } else if !payments.isEmpty {
            Section("Payments applied") {
                ForEach(payments) { payment in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(payment.paymentDate ?? "—")
                                .font(.subheadline)
                            if let lines = payment.applyLines, lines > 1 {
                                Text("\(lines) apply lines")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(payment.appliedAmount ?? 0, format: .currency(code: "USD"))
                            .monospacedDigit()
                            .foregroundStyle(.green)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var schedulesSection: some View {
        let live = schedules.filter { !$0.isCancelled }
        if !live.isEmpty {
            Section("Scheduled") {
                ForEach(live) { schedule in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(schedule.scheduledFor ?? "—")
                                .font(.subheadline)
                            HStack(spacing: 6) {
                                if let method = schedule.method {
                                    Text(method).font(.caption).foregroundStyle(.secondary)
                                }
                                if schedule.isPosted {
                                    StatusPill.open("Posted")
                                }
                            }
                        }
                        Spacer()
                        Text(schedule.amount ?? 0, format: .currency(code: "USD"))
                            .monospacedDigit()
                    }
                    .swipeActions {
                        // Only an unposted schedule can be called back.
                        if !schedule.isPosted {
                            Button("Cancel", role: .destructive) {
                                Task { await cancelSchedule(schedule) }
                            }
                        }
                    }
                }
            }
        }
    }

    private func loadPayments() async {
        isLoadingPayments = true
        defer { isLoadingPayments = false }
        payments = (try? await apiService.fetchBillPayments(billJournalId: bill.journalId)) ?? []
        schedules = (try? await apiService.fetchBillPaymentSchedules(billJournalId: bill.journalId)) ?? []
    }

    private func cancelSchedule(_ schedule: BillPaymentSchedule) async {
        do {
            try await apiService.cancelScheduledPayment(id: schedule.id)
            await loadPayments()
        } catch {
            errorMessage = error.localizedDescription
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
        guard await BiometricGate.confirm("Confirm sign-off for bill J-\(bill.journalId)") else { return }
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

// Detail rows use the shared DS `DetailRow` from Theme/NobleKit.swift.

// MARK: - Schedule payment

/// Schedules a future-dated payment against a bill.
///
/// `schedule_bill_payment` needs a source GL account/child pair, and
/// `list_bank_accounts` carries only the child — so the account half is
/// resolved by matching the child against the chart of accounts rather than
/// asking the user to type a number they would have to look up.
struct ScheduleBillPaymentSheet: View {
    @Environment(APIService.self) private var apiService
    @Environment(\.dismiss) private var dismiss

    let bill: AgingBill
    var onScheduled: () -> Void

    @State private var amount: String = ""
    @State private var scheduledFor = Date()
    @State private var method = "EFT"
    @State private var accounts: [BankAccount] = []
    @State private var selectedAccountID: String?
    @State private var accountKeys: [Int: Int] = [:]   // gl_child -> account
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private static let methods = ["EFT", "CHEQUE", "CARD", "WIRE"]

    private var selectedAccount: BankAccount? {
        accounts.first { $0.id == selectedAccountID }
    }

    private var amountValue: Double? {
        Double(amount.trimmingCharacters(in: .whitespaces))
    }

    private var canSubmit: Bool {
        guard let amountValue, amountValue > 0, let account = selectedAccount else { return false }
        return accountKeys[account.glChild] != nil && !isSubmitting
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bill") {
                    DetailRow(label: "Invoice #", value: bill.invoiceNumber)
                    HStack {
                        Text("Outstanding")
                        Spacer()
                        Text(bill.remainder, format: .currency(code: "USD")).monospacedDigit()
                    }
                }

                Section("Payment") {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    // The server requires today or later.
                    DatePicker("Scheduled for", selection: $scheduledFor,
                               in: Date()..., displayedComponents: .date)
                    Picker("Method", selection: $method) {
                        ForEach(Self.methods, id: \.self) { Text($0) }
                    }
                }

                Section("Pay from") {
                    if accounts.isEmpty {
                        Text("No linked bank accounts.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Account", selection: $selectedAccountID) {
                            ForEach(accounts) { account in
                                Text(account.displayName).tag(Optional(account.id))
                            }
                        }
                        if let account = selectedAccount, accountKeys[account.glChild] == nil {
                            Text("This account's GL child (\(account.glChild)) isn't in the chart of accounts, so it can't be used as a payment source.")
                                .font(.caption)
                                .foregroundStyle(Color.nobleWarn)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.subheadline).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Schedule Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schedule") { Task { await submit() } }
                        .disabled(!canSubmit)
                }
            }
            .task { await loadAccounts() }
            .onAppear {
                if amount.isEmpty, bill.remainder > 0 {
                    amount = String(format: "%.2f", bill.remainder)
                }
            }
        }
    }

    private func loadAccounts() async {
        accounts = (try? await apiService.fetchBankAccounts()) ?? []
        if selectedAccountID == nil { selectedAccountID = accounts.first?.id }
        // gl_child -> account, so the request can carry the pair the server wants.
        if let chart = try? await apiService.fetchAccountList() {
            accountKeys = Dictionary(
                chart.map { ($0.child, $0.account) },
                uniquingKeysWith: { first, _ in first }
            )
        }
    }

    private func submit() async {
        guard let amountValue, let account = selectedAccount,
              let sourceAccount = accountKeys[account.glChild] else { return }
        guard await BiometricGate.confirm(
            "Schedule a \(amountValue.formatted(.currency(code: "USD"))) payment"
        ) else { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        do {
            _ = try await apiService.scheduleBillPayment(ScheduleBillPaymentRequest(
                billJournalId: bill.journalId,
                amount: String(format: "%.2f", amountValue),
                scheduledFor: formatter.string(from: scheduledFor),
                method: method,
                sourceAccount: sourceAccount,
                sourceChild: account.glChild
            ))
            onScheduled()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
