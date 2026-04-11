//
//  APPayablesView.swift
//  nbledger
//
//  Created by Murray Toews on 4/10/26.
//

import SwiftUI

// MARK: - Filter Tab

enum APFilterTab: String, CaseIterable {
    case all = "All"
    case open = "Open"
    case paid = "Paid"
    case closed = "Closed"
}

// MARK: - AP Payables Container

struct APPayablesView: View {
    @Environment(APIService.self) private var apiService

    @State private var payments: [Payment] = []
    @State private var activeFilter: APFilterTab = .all
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false

    private var filteredPayments: [Payment] {
        switch activeFilter {
        case .all:
            return payments
        case .open:
            return payments.filter { $0.status?.uppercased() == "OPEN" }
        case .paid:
            return payments.filter { $0.status?.uppercased() == "PAID" }
        case .closed:
            return payments.filter { $0.status?.uppercased() == "CLOSED" }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Filter", selection: $activeFilter) {
                    ForEach(APFilterTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Group {
                    if isLoading {
                        ProgressView("Loading payables...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text(errorMessage)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                            Button("Retry") { Task { await loadPayments() } }
                                .buttonStyle(.bordered)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredPayments.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "creditcard")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No payables found.")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(filteredPayments) { payment in
                            NavigationLink(value: payment.id) {
                                APPaymentRow(payment: payment)
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Payables")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task { await loadPayments() }
            .refreshable { await loadPayments() }
            .navigationDestination(for: String.self) { paymentId in
                if let payment = payments.first(where: { $0.id == paymentId }) {
                    APPaymentDetailView(
                        payment: payment,
                        onUpdate: { await loadPayments() }
                    )
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateAPPaymentSheet(onCreate: {
                    showCreateSheet = false
                    Task { await loadPayments() }
                })
            }
        }
    }

    private func loadPayments() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            payments = try await apiService.fetchPayments()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - AP Payment Row

struct APPaymentRow: View {
    let payment: Payment

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.displayDescription)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let vendorId = payment.vendorId {
                        Text(vendorId)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let status = payment.status {
                        Text(status)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusColor(status).opacity(0.15), in: Capsule())
                            .foregroundStyle(statusColor(status))
                    }
                    if let date = payment.transactionDate {
                        Text(date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let amount = payment.amount {
                    Text(amount, format: .currency(code: "USD"))
                        .font(.body.monospacedDigit())
                }
                if let paid = payment.amountPaid, paid > 0 {
                    Text("Paid: \(paid, format: .currency(code: "USD"))")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func statusColor(_ status: String) -> Color {
        switch status.uppercased() {
        case "OPEN":   return .orange
        case "PAID":   return .green
        case "CLOSED": return .secondary
        default:       return .blue
        }
    }
}

// MARK: - AP Payment Detail View

struct APPaymentDetailView: View {
    @Environment(APIService.self) private var apiService
    @Environment(\.dismiss) private var dismiss

    let payment: Payment
    var onUpdate: () async -> Void

    @State private var details: [PaymentDetail] = []
    @State private var txnDetails: [PaymentTxnDetail] = []
    @State private var events: [PaymentEvent] = []
    @State private var isLoadingDetails = false
    @State private var showRecordPayment = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Payment Info") {
                LabeledContent("Description", value: payment.displayDescription)
                if let vendorId = payment.vendorId {
                    LabeledContent("Vendor", value: vendorId)
                }
                if let invoiceId = payment.invoiceId {
                    LabeledContent("Invoice #", value: invoiceId)
                }
                if let status = payment.status {
                    LabeledContent("Status") {
                        Text(status)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(statusColor(status).opacity(0.15), in: Capsule())
                            .foregroundStyle(statusColor(status))
                    }
                }
                if let date = payment.transactionDate {
                    LabeledContent("Transaction Date", value: date)
                }
                if let dueDate = payment.dueDate {
                    LabeledContent("Due Date", value: dueDate)
                }
                if let orderNo = payment.orderNo {
                    LabeledContent("Order #", value: orderNo)
                }
                if let reference = payment.reference {
                    LabeledContent("Reference", value: reference)
                }
                if let payRef = payment.paymentReference {
                    LabeledContent("Payment Ref", value: payRef)
                }
            }

            Section("Amounts") {
                if let amount = payment.amount {
                    LabeledContent("Amount") {
                        Text(amount, format: .currency(code: "USD"))
                            .monospacedDigit()
                    }
                }
                if let paid = payment.amountPaid {
                    LabeledContent("Amount Paid") {
                        Text(paid, format: .currency(code: "USD"))
                            .monospacedDigit()
                            .foregroundStyle(.green)
                    }
                }
                LabeledContent("Remaining") {
                    Text(payment.remainingBalance, format: .currency(code: "USD"))
                        .monospacedDigit()
                        .foregroundStyle(payment.remainingBalance > 0 ? .red : .green)
                }
                if let datePaid = payment.datePaid {
                    LabeledContent("Date Paid", value: datePaid)
                }
                if let gst = payment.gstAmount, gst != 0 {
                    LabeledContent("GST") {
                        Text(gst, format: .currency(code: "USD"))
                            .monospacedDigit()
                    }
                }
                if let pst = payment.pstAmount, pst != 0 {
                    LabeledContent("PST") {
                        Text(pst, format: .currency(code: "USD"))
                            .monospacedDigit()
                    }
                }
                if let adjustment = payment.adjustmentAmt, adjustment != 0 {
                    LabeledContent("Adjustment") {
                        Text(adjustment, format: .currency(code: "USD"))
                            .monospacedDigit()
                    }
                }
                if let rebate = payment.rebateAmt, rebate != 0 {
                    LabeledContent("Rebate") {
                        Text(rebate, format: .currency(code: "USD"))
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
                        PaymentDetailRow(detail: detail)
                    }
                }
            }

            if !txnDetails.isEmpty {
                Section("Transaction Details") {
                    ForEach(txnDetails) { detail in
                        PaymentTxnDetailRow(detail: detail)
                    }
                }
            }

            if !events.isEmpty {
                Section("Events") {
                    ForEach(events) { event in
                        PaymentEventRow(event: event)
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
                    showRecordPayment = true
                } label: {
                    Label("Record Payment", systemImage: "dollarsign.circle")
                }
                .disabled(payment.remainingBalance <= 0)

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Payment", systemImage: "trash")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Payment Detail")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadAllDetails() }
        .sheet(isPresented: $showRecordPayment) {
            RecordAPPaymentSheet(
                payment: payment,
                onSubmit: {
                    showRecordPayment = false
                    await onUpdate()
                    dismiss()
                }
            )
        }
        .confirmationDialog("Delete this payment?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await deletePayment() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func loadAllDetails() async {
        isLoadingDetails = true
        defer { isLoadingDetails = false }

        do {
            details = try await apiService.fetchPaymentDetails(transactionId: payment.id)
        } catch {
            details = []
        }
        do {
            txnDetails = try await apiService.fetchPaymentTxnDetails(transactionId: payment.id)
        } catch {
            txnDetails = []
        }
        do {
            events = try await apiService.fetchPaymentEvents(transactionId: payment.id)
        } catch {
            events = []
        }
    }

    private func deletePayment() async {
        do {
            try await apiService.deletePayment(id: payment.id)
            await onUpdate()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.uppercased() {
        case "OPEN":   return .orange
        case "PAID":   return .green
        case "CLOSED": return .secondary
        default:       return .blue
        }
    }
}

// MARK: - Payment Detail Row

struct PaymentDetailRow: View {
    let detail: PaymentDetail

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

// MARK: - Payment Txn Detail Row

struct PaymentTxnDetailRow: View {
    let detail: PaymentTxnDetail

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(detail.description ?? "Txn Detail")
                    .font(.subheadline)
                HStack(spacing: 6) {
                    if let account = detail.account {
                        Text("Acct: \(account)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let fund = detail.fund {
                        Text(fund)
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

// MARK: - Payment Event Row

struct PaymentEventRow: View {
    let event: PaymentEvent

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.transactionType ?? "Event")
                    .font(.subheadline)
                if let date = event.createDate {
                    Text(date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let user = event.createUser {
                Text(user)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Record AP Payment Sheet

struct RecordAPPaymentSheet: View {
    @Environment(APIService.self) private var apiService
    @Environment(\.dismiss) private var dismiss

    let payment: Payment
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
                        Text(payment.displayDescription)
                            .font(.headline)
                        if let vendorId = payment.vendorId {
                            Text("Vendor: \(vendorId)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    VStack(spacing: 4) {
                        HStack {
                            Text("Total Amount")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(payment.amount ?? 0, format: .currency(code: "USD"))
                                .monospacedDigit()
                        }
                        HStack {
                            Text("Previously Paid")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(payment.amountPaid ?? 0, format: .currency(code: "USD"))
                                .monospacedDigit()
                                .foregroundStyle(.green)
                        }
                        Divider()
                        HStack {
                            Text("Remaining")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(payment.remainingBalance, format: .currency(code: "USD"))
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

        let totalPaid = (payment.amountPaid ?? 0) + amountValue
        let params = UpdatePaymentRequest(
            transactionId: payment.id,
            amountPaid: totalPaid,
            datePaid: formatter.string(from: datePaid),
            updateDate: formatter.string(from: Date()),
            updateUser: "MOBILE"
        )

        do {
            try await apiService.updatePayment(params)
            await onSubmit()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Create AP Payment Sheet

struct CreateAPPaymentSheet: View {
    @Environment(APIService.self) private var apiService
    @Environment(\.dismiss) private var dismiss

    var onCreate: () -> Void

    @State private var vendorId = ""
    @State private var invoiceId = ""
    @State private var description = ""
    @State private var reference = ""
    @State private var orderNo = ""
    @State private var amount = ""
    @State private var transactionDate = Date()
    @State private var dueDate = Date()
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    // Vendor picker
    @State private var vendors: [Vendor] = []
    @State private var selectedVendor: Vendor?
    @State private var showVendorPicker = false
    @State private var vendorSearchText = ""

    private var filteredVendors: [Vendor] {
        if vendorSearchText.isEmpty { return vendors }
        return vendors.filter {
            $0.displayName.localizedCaseInsensitiveContains(vendorSearchText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("New Payable")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Vendor")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button {
                                showVendorPicker = true
                            } label: {
                                HStack {
                                    Text(selectedVendor?.displayName ?? "Select a vendor")
                                        .foregroundStyle(selectedVendor != nil ? .primary : .secondary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(10)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }

                        FormField(label: "Invoice #", text: $invoiceId)
                        FormField(label: "Description", text: $description)
                        FormField(label: "Reference", text: $reference)
                        FormField(label: "Order #", text: $orderNo)
                        FormField(label: "Amount", text: $amount, keyboard: .decimalPad)

                        DatePicker("Transaction Date", selection: $transactionDate, displayedComponents: .date)
                            .font(.subheadline)
                        DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
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
                            Text("Create Payable")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting || selectedVendor == nil || amount.isEmpty)
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
            .navigationTitle("Create Payable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await loadVendors() }
            .sheet(isPresented: $showVendorPicker) {
                NavigationStack {
                    List(filteredVendors) { vendor in
                        Button {
                            selectedVendor = vendor
                            showVendorPicker = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(vendor.displayName)
                                        .font(.body)
                                    if let type = vendor.partyType {
                                        Text(type)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if vendor.id == selectedVendor?.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .searchable(text: $vendorSearchText, prompt: "Search vendors")
                    .navigationTitle("Select Vendor")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showVendorPicker = false }
                        }
                    }
                }
            }
        }
    }

    private func loadVendors() async {
        do {
            vendors = try await apiService.fetchVendors()
        } catch {
            vendors = []
        }
    }

    private func submitPayment() async {
        guard let vendor = selectedVendor,
              let amountValue = Double(amount) else { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let params = CreatePaymentRequest(
            status: "OPEN",
            vendorId: vendor.partyId,
            invoiceId: invoiceId.isEmpty ? nil : invoiceId,
            description: description.isEmpty ? nil : description,
            amount: amountValue,
            transactionDate: formatter.string(from: transactionDate),
            dueDate: formatter.string(from: dueDate),
            orderNo: orderNo.isEmpty ? nil : orderNo,
            reference: reference.isEmpty ? nil : reference,
            createDate: formatter.string(from: Date()),
            createUser: "MOBILE"
        )

        do {
            try await apiService.createPayment(params)
            onCreate()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    APPayablesView()
        .environment(APIService())
}
