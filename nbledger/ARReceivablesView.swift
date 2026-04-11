//
//  ARReceivablesView.swift
//  nbledger
//
//  Created by Murray Toews on 4/10/26.
//

import SwiftUI

// MARK: - Filter Tab

enum ARFilterTab: String, CaseIterable {
    case all = "All"
    case open = "Open"
    case overdue = "Overdue"
    case closed = "Closed"
}

// MARK: - AR Receivables Container

struct ARReceivablesView: View {
    @Environment(APIService.self) private var apiService

    @State private var transactions: [ArTransaction] = []
    @State private var overdueTransactions: [ArTransaction] = []
    @State private var activeFilter: ARFilterTab = .all
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var selectedTransaction: ArTransaction?

    private var filteredTransactions: [ArTransaction] {
        switch activeFilter {
        case .all:
            return transactions
        case .open:
            return transactions.filter {
                $0.status?.uppercased() == "OPEN" || $0.status?.uppercased() == "PARTIAL"
            }
        case .overdue:
            return overdueTransactions
        case .closed:
            return transactions.filter { $0.status?.uppercased() == "CLOSED" }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Filter", selection: $activeFilter) {
                    ForEach(ARFilterTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Group {
                    if isLoading {
                        ProgressView("Loading receivables...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text(errorMessage)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                            Button("Retry") { Task { await loadTransactions() } }
                                .buttonStyle(.bordered)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredTransactions.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "dollarsign.arrow.circlepath")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No receivables found.")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(filteredTransactions) { transaction in
                            NavigationLink(value: transaction.id) {
                                ARTransactionRow(transaction: transaction)
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Receivables")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task { await loadTransactions() }
            .refreshable { await loadTransactions() }
            .onChange(of: activeFilter) { _, newFilter in
                if newFilter == .overdue {
                    Task { await loadOverdue() }
                }
            }
            .navigationDestination(for: String.self) { transactionId in
                if let transaction = transactions.first(where: { $0.id == transactionId })
                    ?? overdueTransactions.first(where: { $0.id == transactionId }) {
                    ARTransactionDetailView(
                        transaction: transaction,
                        onUpdate: { await loadTransactions() }
                    )
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateARTransactionSheet(onCreate: {
                    showCreateSheet = false
                    Task { await loadTransactions() }
                })
            }
        }
    }

    private func loadTransactions() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            transactions = try await apiService.fetchArTransactions()
            if activeFilter == .overdue {
                await loadOverdue()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadOverdue() async {
        do {
            overdueTransactions = try await apiService.fetchOverdueArTransactions()
        } catch {
            overdueTransactions = []
        }
    }
}

// MARK: - AR Transaction Row

struct ARTransactionRow: View {
    let transaction: ArTransaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.displayDescription)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let customerId = transaction.customerId {
                        Text(customerId)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let status = transaction.status {
                        Text(status)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusColor(status).opacity(0.15), in: Capsule())
                            .foregroundStyle(statusColor(status))
                    }
                    if let date = transaction.transactionDate {
                        Text(date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let amount = transaction.amount {
                    Text(amount, format: .currency(code: "USD"))
                        .font(.body.monospacedDigit())
                }
                if let received = transaction.amountReceived, received > 0 {
                    Text("Rcvd: \(received, format: .currency(code: "USD"))")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func statusColor(_ status: String) -> Color {
        switch status.uppercased() {
        case "OPEN":    return .orange
        case "PARTIAL": return .yellow
        case "CLOSED":  return .green
        case "OVERDUE": return .red
        default:        return .blue
        }
    }
}

// MARK: - AR Transaction Detail View

struct ARTransactionDetailView: View {
    @Environment(APIService.self) private var apiService
    @Environment(\.dismiss) private var dismiss

    let transaction: ArTransaction
    var onUpdate: () async -> Void

    @State private var details: [ArTransactionDetail] = []
    @State private var isLoadingDetails = false
    @State private var showPaymentSheet = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Transaction Info") {
                LabeledContent("Description", value: transaction.displayDescription)
                if let customerId = transaction.customerId {
                    LabeledContent("Customer", value: customerId)
                }
                if let status = transaction.status {
                    LabeledContent("Status") {
                        Text(status)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(statusColor(status).opacity(0.15), in: Capsule())
                            .foregroundStyle(statusColor(status))
                    }
                }
                if let date = transaction.transactionDate {
                    LabeledContent("Transaction Date", value: date)
                }
                if let dueDate = transaction.dueDate {
                    LabeledContent("Due Date", value: dueDate)
                }
                if let receiptNo = transaction.receiptNo {
                    LabeledContent("Receipt #", value: receiptNo)
                }
                if let reference = transaction.reference {
                    LabeledContent("Reference", value: reference)
                }
            }

            Section("Amounts") {
                if let amount = transaction.amount {
                    LabeledContent("Amount") {
                        Text(amount, format: .currency(code: "USD"))
                            .monospacedDigit()
                    }
                }
                if let received = transaction.amountReceived {
                    LabeledContent("Amount Received") {
                        Text(received, format: .currency(code: "USD"))
                            .monospacedDigit()
                            .foregroundStyle(.green)
                    }
                }
                LabeledContent("Remaining") {
                    Text(transaction.remainingBalance, format: .currency(code: "USD"))
                        .monospacedDigit()
                        .foregroundStyle(transaction.remainingBalance > 0 ? .red : .green)
                }
                if let datePaid = transaction.datePaid {
                    LabeledContent("Date Paid", value: datePaid)
                }
                if let adjustment = transaction.adjustmentAmt, adjustment != 0 {
                    LabeledContent("Adjustment") {
                        Text(adjustment, format: .currency(code: "USD"))
                            .monospacedDigit()
                    }
                }
            }

            Section("Line Items") {
                if isLoadingDetails {
                    ProgressView("Loading details...")
                        .frame(maxWidth: .infinity)
                } else if details.isEmpty {
                    Text("No line items.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(details) { detail in
                        ARDetailRow(detail: detail)
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    showPaymentSheet = true
                } label: {
                    Label("Record Payment", systemImage: "dollarsign.circle")
                }
                .disabled(transaction.remainingBalance <= 0)

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Transaction", systemImage: "trash")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("AR Detail")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadDetails() }
        .sheet(isPresented: $showPaymentSheet) {
            RecordPaymentSheet(
                transaction: transaction,
                onSubmit: {
                    showPaymentSheet = false
                    await onUpdate()
                    dismiss()
                }
            )
        }
        .confirmationDialog("Delete this transaction?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await deleteTransaction() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func loadDetails() async {
        isLoadingDetails = true
        defer { isLoadingDetails = false }
        do {
            details = try await apiService.fetchArTransactionDetails(transactionId: transaction.id)
        } catch {
            details = []
        }
    }

    private func deleteTransaction() async {
        do {
            try await apiService.deleteArTransaction(id: transaction.id)
            await onUpdate()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.uppercased() {
        case "OPEN":    return .orange
        case "PARTIAL": return .yellow
        case "CLOSED":  return .green
        case "OVERDUE": return .red
        default:        return .blue
        }
    }
}

// MARK: - AR Detail Row

struct ARDetailRow: View {
    let detail: ArTransactionDetail

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(detail.description ?? "Line Item")
                    .font(.subheadline)
                HStack(spacing: 6) {
                    if let account = detail.account {
                        Text("Acct: \(account)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let reference = detail.reference {
                        Text(reference)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let debit = detail.debit, debit > 0 {
                    Text("Dr: \(debit, format: .currency(code: "USD"))")
                        .font(.caption.monospacedDigit())
                }
                if let credit = detail.credit, credit > 0 {
                    Text("Cr: \(credit, format: .currency(code: "USD"))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.green)
                }
            }
        }
    }
}

// MARK: - Record Payment Sheet

struct RecordPaymentSheet: View {
    @Environment(APIService.self) private var apiService
    @Environment(\.dismiss) private var dismiss

    let transaction: ArTransaction
    var onSubmit: () async -> Void

    @State private var paymentAmount = ""
    @State private var datePaid = Date()
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Payment for")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(transaction.displayDescription)
                            .font(.headline)
                    }
                    .padding(.horizontal)

                    VStack(spacing: 4) {
                        HStack {
                            Text("Total Amount")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(transaction.amount ?? 0, format: .currency(code: "USD"))
                                .monospacedDigit()
                        }
                        HStack {
                            Text("Previously Received")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(transaction.amountReceived ?? 0, format: .currency(code: "USD"))
                                .monospacedDigit()
                                .foregroundStyle(.green)
                        }
                        Divider()
                        HStack {
                            Text("Remaining")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(transaction.remainingBalance, format: .currency(code: "USD"))
                                .monospacedDigit()
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        FormField(label: "Payment Amount", text: $paymentAmount, keyboard: .decimalPad)
                        DatePicker("Date Paid", selection: $datePaid, displayedComponents: .date)
                            .font(.subheadline)
                    }
                    .padding(.horizontal)

                    Button {
                        Task { await submitPayment() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Record Payment")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting || paymentAmount.isEmpty)
                    .padding(.horizontal)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Record Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func submitPayment() async {
        guard let amountValue = Double(paymentAmount) else { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let totalReceived = (transaction.amountReceived ?? 0) + amountValue
        let params = UpdateArAmountReceivedRequest(
            id: transaction.id,
            amountReceived: totalReceived,
            datePaid: formatter.string(from: datePaid),
            updateUser: "MOBILE"
        )

        do {
            try await apiService.updateArTransactionAmountReceived(params)
            await onSubmit()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Create AR Transaction Sheet

struct CreateARTransactionSheet: View {
    @Environment(APIService.self) private var apiService
    @Environment(\.dismiss) private var dismiss

    var onCreate: () -> Void

    @State private var customerId = ""
    @State private var description = ""
    @State private var reference = ""
    @State private var receiptNo = ""
    @State private var amount = ""
    @State private var transactionDate = Date()
    @State private var dueDate = Date()
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("New Receivable")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        FormField(label: "Customer ID", text: $customerId)
                        FormField(label: "Description", text: $description)
                        FormField(label: "Reference", text: $reference)
                        FormField(label: "Receipt No", text: $receiptNo)
                        FormField(label: "Amount", text: $amount, keyboard: .decimalPad)

                        DatePicker("Transaction Date", selection: $transactionDate, displayedComponents: .date)
                            .font(.subheadline)
                        DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                            .font(.subheadline)
                    }
                    .padding(.horizontal)

                    Button {
                        Task { await submitTransaction() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Create Receivable")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting || customerId.isEmpty || amount.isEmpty)
                    .padding(.horizontal)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Create Receivable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func submitTransaction() async {
        guard let amountValue = Double(amount) else { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let params = CreateArTransactionRequest(
            customerId: customerId,
            status: "OPEN",
            transactionDate: formatter.string(from: transactionDate),
            dueDate: formatter.string(from: dueDate),
            receiptNo: receiptNo.isEmpty ? nil : receiptNo,
            reference: reference.isEmpty ? nil : reference,
            description: description.isEmpty ? nil : description,
            amount: amountValue,
            createDate: formatter.string(from: Date()),
            createUser: "MOBILE"
        )

        do {
            try await apiService.createArTransaction(params)
            onCreate()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    ARReceivablesView()
        .environment(APIService())
}
