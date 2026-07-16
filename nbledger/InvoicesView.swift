//
//  InvoicesView.swift
//  nbledger
//
//  Created by Murray Toews on 4/4/26.
//
//  Capture flow (CONTRACT.md §5): scan (VisionKit document camera), pick
//  (photo library), or import (Files) a document -> images are re-encoded
//  to JPEG (D4) -> upload to the server's asset store (kind "receipts") ->
//  server-side AI analysis -> prefilled bill form the user confirms ->
//  create_bill -> attach the document to the returned journal id. PDFs are
//  uploaded and attached but NOT analyzed (the analyze endpoint rejects
//  PDFs, contract §3.1) — they go straight to manual entry with the asset
//  attached on save. Failures keep enough state to retry: a failed upload
//  keeps the captured bytes in memory, a failed analysis keeps the
//  uploaded asset and falls back to manual field entry.
//
//  Camera path is the VisionKit document scanner (ruling M-D1). It can
//  return multiple pages; v1 uploads page 1 only and tells the user so.
//

import SwiftUI
import PhotosUI
import VisionKit
import UniformTypeIdentifiers

// MARK: - Invoice Sub-Tab

enum InvoiceTab {
    case capture
    case confirm
    case manual
    case payments
}

// MARK: - Capture payload

/// The bytes queued for upload plus their upload metadata. Images are
/// always re-encoded JPEG (D4: HEIC and any other source format converts
/// client-side); PDFs pass through untouched and skip AI analysis.
struct CapturePayload: Equatable {
    let data: Data
    let contentType: String
    let originalName: String

    /// Only standard image types can be analyzed (CONTRACT.md §3.1); the
    /// capture flow produces image/jpeg for every image source.
    var isAnalyzable: Bool { contentType == "image/jpeg" }
}

/// Hand-off from the VisionKit scanner: the first page plus how many
/// pages the user actually scanned (v1 uploads page 1 only).
struct ScannedDocument: Equatable {
    let image: UIImage
    let pageCount: Int
}

// MARK: - Invoices Container

struct InvoicesView: View {
    @Environment(APIService.self) private var apiService

    /// Set when presented as the full-screen Capture flow; shows a Close button.
    var onClose: (() -> Void)? = nil
    /// Called after a bill is created so the shell can land in Payables
    /// with a success banner (the capture loop).
    var onDraftSaved: (() -> Void)? = nil

    @State private var activeTab: InvoiceTab = .capture

    // Capture -> upload -> analyze state
    @State private var capturedImage: UIImage?      // preview only; nil for PDFs
    @State private var capturePayload: CapturePayload?
    @State private var scannedDocument: ScannedDocument?  // transient scanner hand-off
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showScanner = false
    @State private var showFileImporter = false
    @State private var multiPageNote: String?

    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var uploadedAssetId: String?

    @State private var isAnalyzing = false
    @State private var analysisError: String?
    @State private var extraction: InvoiceExtraction?
    @State private var prefill: BillPrefill?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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

                Divider()

                // Bottom toolbar
                invoiceToolbar
            }
            .navigationTitle(toolbarTitle)
            .toolbar {
                if let onClose {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            onClose()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Close")
                    }
                }
            }
            .sheet(isPresented: $showScanner) {
                DocumentScannerView(scan: $scannedDocument)
                    .ignoresSafeArea()
            }
            .onChange(of: scannedDocument) { _, newScan in
                guard let newScan else { return }
                scannedDocument = nil
                handleScannedDocument(newScan)
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.image, .pdf]
            ) { result in
                handleImportedFile(result)
            }
        }
    }

    private var toolbarTitle: String {
        switch activeTab {
        case .capture:  return "Invoices"
        case .confirm:  return "Confirm Bill"
        case .manual:   return "Manual Entry"
        case .payments: return "Payments"
        }
    }

    // MARK: - Bottom Toolbar

    private var invoiceToolbar: some View {
        HStack {
            toolbarButton(
                label: "Confirm",
                icon: "checkmark.circle",
                tab: .confirm,
                disabled: uploadedAssetId == nil
            )
            toolbarButton(label: "Manual", icon: "square.and.pencil", tab: .manual)
            toolbarButton(label: "Payments", icon: "creditcard", tab: .payments)
            toolbarButton(label: "Back", icon: "arrow.uturn.backward", tab: .capture)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func toolbarButton(
        label: String,
        icon: String,
        tab: InvoiceTab,
        disabled: Bool = false
    ) -> some View {
        Button {
            activeTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(activeTab == tab ? Color.blue : disabled ? Color.gray.opacity(0.3) : Color.secondary)
        }
        .disabled(disabled)
    }

    // MARK: - Capture View

    private var captureView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                captureSection

                progressSection

                if let multiPageNote {
                    Text(multiPageNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if uploadError != nil, capturePayload != nil {
                    // Upload failed: the captured image stays in memory —
                    // retry uploads the same bytes.
                    Button {
                        Task { await uploadAndAnalyze() }
                    } label: {
                        Label("Retry Upload", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }

                if analysisError != nil, uploadedAssetId != nil {
                    // Analysis failed but the document is uploaded: the user
                    // can retry, or fill the form manually on the Confirm tab
                    // (the document is still attached on save).
                    VStack(spacing: 8) {
                        Button {
                            Task { await analyzeCaptured() }
                        } label: {
                            Label("Retry Analysis", systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Text("Or tap Confirm below to enter the details manually — the document is uploaded and will still be attached.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)
                }

                if capturePayload?.isAnalyzable == false, uploadedAssetId != nil {
                    Text("PDF uploaded. AI analysis is not available for PDFs — tap Confirm below to enter the details; the document will still be attached.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if extraction != nil {
                    extractionPreview
                        .padding(.horizontal)

                    Text("Tap Confirm below to review and save.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                messagesSection
            }
            .padding(.top)
        }
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            if isUploading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Uploading document...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            if isAnalyzing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Analyzing invoice...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            if uploadedAssetId != nil, !isUploading {
                Label("Document uploaded", systemImage: "checkmark.icloud")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Confirm View

    private var confirmView: some View {
        BillFormView(
            assetId: uploadedAssetId,
            capturedImage: capturedImage,
            prefill: prefill,
            onDone: { resetCapture() },
            onViewInPayables: onDraftSaved
        )
        // A new upload gets a fresh form.
        .id(uploadedAssetId ?? "no-asset")
    }

    // MARK: - Manual View

    private var manualView: some View {
        BillFormView(assetId: nil, capturedImage: nil, prefill: nil, onViewInPayables: onDraftSaved)
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

                Button("Clear Document", role: .destructive) {
                    resetCapture()
                }
                .font(.caption)
                .disabled(isUploading || isAnalyzing)
            } else if let payload = capturePayload {
                // Non-image capture (PDF): no thumbnail, show a document card.
                HStack(spacing: 12) {
                    Image(systemName: "doc.richtext")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(payload.originalName)
                            .font(.subheadline)
                            .lineLimit(1)
                        Text(payload.contentType)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Button("Clear Document", role: .destructive) {
                    resetCapture()
                }
                .font(.caption)
                .disabled(isUploading || isAnalyzing)
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
                            showScanner = true
                        } label: {
                            Label("Scan", systemImage: "doc.text.viewfinder")
                        }
                        .buttonStyle(.bordered)

                        PhotosPicker(selection: $photoPickerItem, matching: .images) {
                            Label("Photos", systemImage: "photo")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            showFileImporter = true
                        } label: {
                            Label("Files", systemImage: "folder")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
        }
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                photoPickerItem = nil
                guard let data = try? await newItem.loadTransferable(type: Data.self) else {
                    uploadError = "Could not load the selected photo."
                    return
                }
                handlePickedData(data, fileName: "photo")
            }
        }
    }

    // MARK: - Extraction Preview

    private var extractionPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Extracted Data")
                .font(.headline)

            if let prefill {
                if let vendor = prefill.vendorName {
                    Label(vendor, systemImage: "building.2")
                        .font(.subheadline)
                }
                if let num = prefill.invoiceNumber {
                    Label("Invoice #\(num)", systemImage: "doc.text")
                        .font(.subheadline)
                }
                if let amt = prefill.amount {
                    Label("$\(amt)", systemImage: "dollarsign.circle")
                        .font(.subheadline)
                }
                if let date = prefill.invoiceDate {
                    Label(Self.displayDate(date), systemImage: "calendar")
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
            if let uploadError {
                Text(uploadError)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
            if let analysisError {
                Text(analysisError)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Actions

    /// Scanner hand-off: re-encode page 1 to JPEG (D4) and start the flow.
    /// The VisionKit scanner can return multiple pages; v1 uploads only the
    /// first page and says so rather than dropping the rest silently.
    private func handleScannedDocument(_ scan: ScannedDocument) {
        guard let jpeg = scan.image.jpegData(compressionQuality: 0.85) else {
            uploadError = "Could not read the scanned image."
            return
        }
        let payload = CapturePayload(
            data: jpeg,
            contentType: "image/jpeg",
            originalName: "receipt-\(Int(Date().timeIntervalSince1970)).jpg"
        )
        startCapture(payload: payload, previewImage: scan.image)
        if scan.pageCount > 1 {
            multiPageNote = "You scanned \(scan.pageCount) pages. Only the first page is uploaded and attached in this version."
        }
    }

    /// Photo-library hand-off (raw data; may be HEIC — re-encoded by
    /// makeCapturePayload).
    private func handlePickedData(_ data: Data, fileName: String) {
        guard let payload = Self.makeCapturePayload(fileData: data, fileName: fileName) else {
            uploadError = "Unsupported file. Choose an image or a PDF."
            return
        }
        startCapture(payload: payload, previewImage: UIImage(data: payload.data))
    }

    /// Files-app import: images follow the same upload->analyze->prefill
    /// flow; PDFs are upload+attach only (analysis rejects PDFs, §3.1).
    private func handleImportedFile(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            uploadError = "Import failed: \(error.localizedDescription)"
        case .success(let url):
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                uploadError = "Could not read the selected file."
                return
            }
            guard let payload = Self.makeCapturePayload(fileData: data, fileName: url.lastPathComponent) else {
                uploadError = "Unsupported file. Choose an image or a PDF."
                return
            }
            startCapture(
                payload: payload,
                previewImage: payload.isAnalyzable ? UIImage(data: payload.data) : nil
            )
        }
    }

    /// Classifies raw file bytes for capture. PDFs (by extension or %PDF
    /// magic bytes) pass through unchanged; anything else must decode as an
    /// image and is re-encoded to JPEG per D4 (covers HEIC/PNG/etc.).
    /// Returns nil for bytes that are neither a PDF nor a decodable image.
    static func makeCapturePayload(fileData: Data, fileName: String) -> CapturePayload? {
        let isPDF = fileName.lowercased().hasSuffix(".pdf")
            || fileData.starts(with: Array("%PDF".utf8))
        if isPDF {
            let name = fileName.lowercased().hasSuffix(".pdf") ? fileName : "\(fileName).pdf"
            return CapturePayload(data: fileData, contentType: "application/pdf", originalName: name)
        }
        guard let image = UIImage(data: fileData),
              let jpeg = image.jpegData(compressionQuality: 0.85) else {
            return nil
        }
        var base = (fileName as NSString).deletingPathExtension
        if base.isEmpty { base = "receipt" }
        return CapturePayload(data: jpeg, contentType: "image/jpeg", originalName: "\(base).jpg")
    }

    private func startCapture(payload: CapturePayload, previewImage: UIImage?) {
        capturePayload = payload
        capturedImage = previewImage
        uploadedAssetId = nil
        extraction = nil
        prefill = nil
        uploadError = nil
        analysisError = nil
        multiPageNote = nil
        Task { await uploadAndAnalyze() }
    }

    private func uploadAndAnalyze() async {
        await uploadCaptured()
        guard uploadedAssetId != nil, capturePayload?.isAnalyzable == true else { return }
        await analyzeCaptured()
    }

    private func uploadCaptured() async {
        guard let payload = capturePayload else { return }

        isUploading = true
        uploadError = nil
        defer { isUploading = false }

        do {
            let uploaded = try await apiService.uploadAsset(
                payload.data,
                kind: "receipts",
                contentType: payload.contentType,
                originalName: payload.originalName
            )
            uploadedAssetId = uploaded.id
        } catch {
            uploadError = "Upload failed: \(error.localizedDescription)"
        }
    }

    private func analyzeCaptured() async {
        guard let payload = capturePayload, payload.isAnalyzable else { return }

        isAnalyzing = true
        analysisError = nil
        defer { isAnalyzing = false }

        do {
            let result = try await apiService.analyzeInvoice(imageData: payload.data, mediaType: payload.contentType)
            extraction = result
            prefill = Self.makePrefill(from: result)
        } catch {
            analysisError = "Analysis failed: \(error.localizedDescription)"
        }
    }

    /// Maps the extraction to form prefill. The server returns "" (strings)
    /// and 0 (amount) for fields it could NOT read — those become nil so the
    /// form field stays empty instead of showing "0.00".
    static func makePrefill(from extraction: InvoiceExtraction) -> BillPrefill {
        func nonEmpty(_ value: String?) -> String? {
            guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return value
        }

        var prefill = BillPrefill()
        prefill.invoiceNumber = nonEmpty(extraction.invoiceNumber)
        prefill.description = nonEmpty(extraction.description)
        prefill.vendorName = nonEmpty(extraction.vendorName)
        if let amount = extraction.amount, amount > 0 {
            prefill.amount = String(format: "%.2f", amount)
        }
        if let dateString = nonEmpty(extraction.date) {
            prefill.invoiceDate = parseDate(dateString)
        }
        if let dueDateString = nonEmpty(extraction.dueDate) {
            prefill.dueDate = parseDate(dueDateString)
        }
        return prefill
    }

    private func resetCapture() {
        capturedImage = nil
        capturePayload = nil
        scannedDocument = nil
        photoPickerItem = nil
        multiPageNote = nil
        uploadedAssetId = nil
        extraction = nil
        prefill = nil
        uploadError = nil
        analysisError = nil
        activeTab = .capture
    }

    static func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    private static func displayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
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
            payments = try await apiService.fetchApTransactions()
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

/// VisionKit document scanner (ruling M-D1: strictly better capture UX
/// than a bare camera — edge detection, de-skew, multi-page). Reports the
/// first page plus the total page count via `scan`.
struct DocumentScannerView: UIViewControllerRepresentable {
    @Binding var scan: ScannedDocument?
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
                parent.scan = ScannedDocument(
                    image: scan.imageOfPage(at: 0),
                    pageCount: scan.pageCount
                )
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
