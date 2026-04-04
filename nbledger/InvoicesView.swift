//
//  InvoicesView.swift
//  nbledger
//
//  Created by Murray Toews on 4/4/26.
//

import SwiftUI
import PhotosUI

// MARK: - Invoices View

struct InvoicesView: View {
    @Environment(APIService.self) private var apiService

    @State private var capturedImage: UIImage?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showCamera = false

    @State private var isAnalyzing = false
    @State private var isSubmitting = false
    @State private var extraction: InvoiceExtraction?

    // Form fields
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

    var filteredVendors: [Vendor] {
        if vendorSearchText.isEmpty {
            return vendors
        }
        return vendors.filter {
            $0.displayName.localizedCaseInsensitiveContains(vendorSearchText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: - Image Capture Section
                    captureSection

                    // MARK: - AI Analysis
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

                    // MARK: - Invoice Form
                    if extraction != nil || capturedImage != nil {
                        invoiceForm
                    }

                    // MARK: - Messages
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
            .navigationTitle("Invoices")
            .task { await loadVendors() }
            .sheet(isPresented: $showCamera) {
                CameraView(image: $capturedImage)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showVendorPicker) {
                vendorPickerSheet
            }
        }
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
                            Label("Camera", systemImage: "camera")
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

    // MARK: - Invoice Form

    private var invoiceForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Invoice Details")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 12) {
                FormField(label: "Invoice Number", text: $invoiceNumber)
                FormField(label: "Amount", text: $amount, keyboard: .decimalPad)
                FormField(label: "Description", text: $description)

                // Vendor picker
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

            // Submit
            Button {
                Task { await submitInvoice() }
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
        }
    }

    // MARK: - Vendor Picker Sheet

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

        // Try to match vendor by name
        if let vendorName = extraction.vendorName {
            selectedVendor = vendors.first {
                $0.displayName.localizedCaseInsensitiveContains(vendorName)
            }
        }
    }

    private func submitInvoice() async {
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

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
