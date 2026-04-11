//
//  InvoicesView.swift
//  nbledger
//
//  Created by Murray Toews on 4/4/26.
//

import SwiftUI
import PhotosUI
import VisionKit

// MARK: - Invoice Sub-Tab

enum InvoiceTab {
    case capture
    case confirm
    case manual
    case payments
}

// MARK: - Invoices Container

struct InvoicesView: View {
    @Environment(APIService.self) private var apiService

    @State private var activeTab: InvoiceTab = .capture

    // Shared state for capture → confirm flow
    @State private var capturedImage: UIImage?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var isAnalyzing = false
    @State private var extraction: InvoiceExtraction?

    // Shared form fields (populated by AI, used in confirm)
    @State private var invoiceNumber = ""
    @State private var amount = ""
    @State private var invoiceDate = Date()
    @State private var dueDate = Date()
    @State private var description = ""
    @State private var selectedVendor: Vendor?

    @State private var vendors: [Vendor] = []
    @State private var vendorSearchText = ""
    @State private var showVendorPicker = false

    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented picker for sub-navigation
                Picker("Section", selection: $activeTab) {
                    Text("Capture").tag(InvoiceTab.capture)
                    Text("Confirm").tag(InvoiceTab.confirm)
                    Text("Manual").tag(InvoiceTab.manual)
                    Text("Payments").tag(InvoiceTab.payments)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Content area
                Group {
                    switch activeTab {
                    case .capture:
                        captureView
                    case .confirm:
                        confirmView
                    case .manual:
                        manualView
                    case .payments:
                        paymentsView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Invoices")
            .task { await loadVendors() }
            .sheet(isPresented: $showCamera) {
                DocumentScannerView(image: $capturedImage)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showVendorPicker) {
                vendorPickerSheet
            }
        }
    }

    // MARK: - Capture View

    private var captureView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                captureSection

                if capturedImage != nil && extraction == nil && !isAnalyzing {
                    Button {
                        Task { await analyzeImage() }
                    } label: {
                        Label("Process with AI", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }

                if isAnalyzing {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Analyzing invoice...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }

                if extraction != nil {
                    extractionPreview
                        .padding(.horizontal)

                    Text("Tap Confirm below to review and submit.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                messagesSection
            }
            .padding(.top)
        }
    }

    // MARK: - Confirm View

    private var confirmView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let capturedImage {
                    Image(uiImage: capturedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Review Invoice")
                        .font(.headline)

                    confirmRow("Invoice #", value: invoiceNumber)
                    confirmRow("Amount", value: amount.isEmpty ? "—" : "$\(amount)")
                    confirmRow("Vendor", value: selectedVendor?.displayName ?? "Not selected")
                    confirmRow("Description", value: description.isEmpty ? "—" : description)
                    confirmRow("Invoice Date", value: formatDate(invoiceDate))
                    confirmRow("Due Date", value: formatDate(dueDate))
                }
                .padding(.horizontal)

                if selectedVendor == nil {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vendor")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            showVendorPicker = true
                        } label: {
                            HStack {
                                Text("Select a vendor")
                                    .foregroundStyle(.secondary)
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
                    .padding(.horizontal)
                }

                Button {
                    Task { await submitInvoice() }
                } label: {
                    Text("Create Invoice")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedVendor == nil || amount.isEmpty)
                .padding(.horizontal)

                messagesSection
            }
            .padding(.top)
        }
    }

    private func confirmRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.subheadline)
        }
    }

    // MARK: - Manual View

    private var manualView: some View {
        ManualInvoiceView(vendors: vendors)
    }

    // MARK: - Payments View

    private var paymentsView: some View {
        PaymentsListView()
    }

    // MARK: - Capture Section

    private var captureSection: some View {
        VStack(spacing: 12) {
            if let capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                Button("Clear Image", role: .destructive) {
                    self.capturedImage = nil
                    self.extraction = nil
                    resetForm()
                }
                .font(.caption)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text("Capture or select an invoice")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Scan", systemImage: "doc.text.viewfinder")
                        }
                        .buttonStyle(.bordered)

                        PhotosPicker(selection: $photoPickerItem, matching: .images) {
                            Label("Photos", systemImage: "photo")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
        }
        .onChange(of: photoPickerItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    capturedImage = image
                }
            }
        }
    }

    // MARK: - Extraction Preview

    private var extractionPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Extracted Data")
                .font(.headline)

            if let ext = extraction {
                if let vendor = ext.vendorName {
                    Label(vendor, systemImage: "building.2")
                        .font(.subheadline)
                }
                if let num = ext.invoiceNumber {
                    Label("Invoice #\(num)", systemImage: "doc.text")
                        .font(.subheadline)
                }
                if let amt = ext.amount {
                    Label(String(format: "$%.2f", amt), systemImage: "dollarsign.circle")
                        .font(.subheadline)
                }
                if let date = ext.date {
                    Label(date, systemImage: "calendar")
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Messages

    private var messagesSection: some View {
        VStack {
            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
            if let successMessage {
                Text(successMessage)
                    .font(.subheadline)
                    .foregroundStyle(.green)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Vendor Picker Sheet

    private var filteredVendors: [Vendor] {
        if vendorSearchText.isEmpty { return vendors }
        return vendors.filter {
            $0.displayName.localizedCaseInsensitiveContains(vendorSearchText)
        }
    }

    private var vendorPickerSheet: some View {
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

    // MARK: - Actions

    private func loadVendors() async {
        do {
            vendors = try await apiService.fetchVendors()
        } catch {
            vendors = []
        }
    }

    private func analyzeImage() async {
        guard let image = capturedImage,
              let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }

        do {
            let result = try await apiService.analyzeInvoice(imageData: imageData)
            extraction = result
            prefillForm(from: result)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func prefillForm(from extraction: InvoiceExtraction) {
        invoiceNumber = extraction.invoiceNumber ?? ""
        if let amt = extraction.amount {
            amount = String(format: "%.2f", amt)
        }
        description = extraction.description ?? ""

        if let dateStr = extraction.date, let parsed = parseDate(dateStr) {
            invoiceDate = parsed
        }
        if let dueDateStr = extraction.dueDate, let parsed = parseDate(dueDateStr) {
            dueDate = parsed
        }

        if let vendorName = extraction.vendorName {
            selectedVendor = vendors.first {
                $0.displayName.localizedCaseInsensitiveContains(vendorName)
            }
        }
    }

    private func submitInvoice() async {
        guard let vendor = selectedVendor,
              let amountValue = Double(amount) else { return }

        errorMessage = nil
        successMessage = nil

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let payment = CreatePaymentRequest(
            status: "OPEN",
            vendorId: vendor.partyId,
            invoiceId: invoiceNumber,
            description: description,
            amount: amountValue,
            transactionDate: formatter.string(from: invoiceDate),
            dueDate: formatter.string(from: dueDate),
            reference: invoiceNumber,
            createDate: formatter.string(from: Date()),
            createUser: "MOBILE"
        )

        do {
            try await apiService.createPayment(payment)
            successMessage = "Invoice created successfully."
            capturedImage = nil
            extraction = nil
            resetForm()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetForm() {
        invoiceNumber = ""
        amount = ""
        description = ""
        invoiceDate = Date()
        dueDate = Date()
        selectedVendor = nil
        errorMessage = nil
        successMessage = nil
    }

    private func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Manual Invoice View

struct ManualInvoiceView: View {
    @Environment(APIService.self) private var apiService
    let vendors: [Vendor]

    @State private var invoiceNumber = ""
    @State private var amount = ""
    @State private var invoiceDate = Date()
    @State private var dueDate = Date()
    @State private var description = ""
    @State private var selectedVendor: Vendor?
    @State private var vendorSearchText = ""
    @State private var showVendorPicker = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var filteredVendors: [Vendor] {
        if vendorSearchText.isEmpty { return vendors }
        return vendors.filter {
            $0.displayName.localizedCaseInsensitiveContains(vendorSearchText)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Invoice Details")
                    .font(.headline)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    FormField(label: "Invoice Number", text: $invoiceNumber)
                    FormField(label: "Amount", text: $amount, keyboard: .decimalPad)
                    FormField(label: "Description", text: $description)

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

                    DatePicker("Invoice Date", selection: $invoiceDate, displayedComponents: .date)
                        .font(.subheadline)
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                        .font(.subheadline)
                }
                .padding(.horizontal)

                Button {
                    Task { await submitManualInvoice() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Submit Invoice")
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
                if let successMessage {
                    Text(successMessage)
                        .font(.subheadline)
                        .foregroundStyle(.green)
                        .padding(.horizontal)
                }
            }
            .padding(.top)
        }
        .sheet(isPresented: $showVendorPicker) {
            NavigationStack {
                List(filteredVendors) { vendor in
                    Button {
                        selectedVendor = vendor
                        showVendorPicker = false
                    } label: {
                        HStack {
                            Text(vendor.displayName)
                                .font(.body)
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

    private func submitManualInvoice() async {
        guard let vendor = selectedVendor,
              let amountValue = Double(amount) else { return }

        isSubmitting = true
        errorMessage = nil
        successMessage = nil
        defer { isSubmitting = false }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let payment = CreatePaymentRequest(
            status: "OPEN",
            vendorId: vendor.partyId,
            invoiceId: invoiceNumber,
            description: description,
            amount: amountValue,
            transactionDate: formatter.string(from: invoiceDate),
            dueDate: formatter.string(from: dueDate),
            reference: invoiceNumber,
            createDate: formatter.string(from: Date()),
            createUser: "MOBILE"
        )

        do {
            try await apiService.createPayment(payment)
            successMessage = "Invoice submitted successfully."
            invoiceNumber = ""
            amount = ""
            description = ""
            invoiceDate = Date()
            dueDate = Date()
            selectedVendor = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Payments List View

struct PaymentsListView: View {
    @Environment(APIService.self) private var apiService

    @State private var payments: [Payment] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading payments...")
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
            } else if payments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No payments found.")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(payments) { payment in
                    PaymentRow(payment: payment)
                }
                .listStyle(.insetGrouped)
            }
        }
        .task { await loadPayments() }
        .refreshable { await loadPayments() }
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

struct PaymentRow: View {
    let payment: Payment

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.description ?? "Payment")
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let vendor = payment.vendorId {
                        Text(vendor)
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
            if let amount = payment.amount {
                Text(amount, format: .currency(code: "USD"))
                    .font(.body.monospacedDigit())
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

// MARK: - Form Field

struct FormField: View {
    let label: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(label, text: $text)
                .textFieldStyle(.roundedBorder)
                .keyboardType(keyboard)
        }
    }
}

// MARK: - Document Scanner View

struct DocumentScannerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView

        init(_ parent: DocumentScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            if scan.pageCount > 0 {
                parent.image = scan.imageOfPage(at: 0)
            }
            parent.dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.dismiss()
        }
    }
}
