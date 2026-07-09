//
//  JournalEvidenceView.swift
//  nbledger
//
//  Evidence section for the journal detail screen: lists gl_evidence
//  rows, attaches new evidence (scan / photo / file -> GCS asset ->
//  create_evidence with location = asset id), and previews attached
//  documents via short-lived signed URLs and QuickLook — the same
//  asset flow the bill documents feature uses (AssetService.swift).
//
//  gl_evidence.location holds the asset UUID for evidence attached
//  here; rows whose location is not an asset id (legacy/web entries)
//  render without a preview affordance.
//

import SwiftUI
import PhotosUI

struct JournalEvidenceSection: View {
    @Environment(APIService.self) private var apiService

    let journalId: Int
    /// Called after evidence is added so the parent can refresh anything
    /// derived from evidence counts (e.g. the journal list indicator).
    var onEvidenceChanged: () async -> Void = {}

    @State private var evidence: [GlEvidence] = []
    @State private var isLoading = false
    @State private var loadError: String?

    // Capture hand-off
    @State private var showAttachOptions = false
    @State private var showScanner = false
    @State private var scannedDocument: ScannedDocument?
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showFileImporter = false

    // Upload state
    @State private var isUploading = false
    @State private var attachError: String?

    // Preview state
    @State private var previewItem: EvidencePreviewItem?
    @State private var lastPreviewFileURL: URL?
    @State private var loadingEvidenceId: String?

    var body: some View {
        Section("Evidence") {
            if isLoading && evidence.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading evidence...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if evidence.isEmpty {
                Label("No evidence attached", systemImage: "paperclip.slash")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(evidence) { item in
                if let assetId = assetId(for: item) {
                    Button {
                        Task { await preview(item, assetId: assetId) }
                    } label: {
                        HStack {
                            EvidenceRow(evidence: item)
                            if loadingEvidenceId == item.id {
                                ProgressView()
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(loadingEvidenceId != nil)
                } else {
                    EvidenceRow(evidence: item)
                }
            }

            if isUploading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Uploading evidence...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    showAttachOptions = true
                } label: {
                    Label("Attach Evidence", systemImage: "paperclip")
                }
            }

            if let attachError {
                Text(attachError)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
            if let loadError {
                Text(loadError)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
        }
        .task(id: journalId) { await loadEvidence() }
        .confirmationDialog("Attach Evidence", isPresented: $showAttachOptions, titleVisibility: .visible) {
            Button("Scan Document") { showScanner = true }
            Button("Choose Photo") { showPhotoPicker = true }
            Button("Choose File") { showFileImporter = true }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showScanner) {
            DocumentScannerView(scan: $scannedDocument)
                .ignoresSafeArea()
        }
        .onChange(of: scannedDocument) { _, newScan in
            guard let newScan else { return }
            scannedDocument = nil
            guard let jpeg = newScan.image.jpegData(compressionQuality: 0.85) else {
                attachError = "Could not read the scanned image."
                return
            }
            let payload = CapturePayload(
                data: jpeg,
                contentType: "image/jpeg",
                originalName: "evidence-\(Int(Date().timeIntervalSince1970)).jpg"
            )
            Task { await attach(payload) }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                photoPickerItem = nil
                guard let data = try? await newItem.loadTransferable(type: Data.self) else {
                    attachError = "Could not load the selected photo."
                    return
                }
                guard let payload = InvoicesView.makeCapturePayload(fileData: data, fileName: "evidence") else {
                    attachError = "Unsupported file. Choose an image or a PDF."
                    return
                }
                await attach(payload)
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image, .pdf]
        ) { result in
            switch result {
            case .failure(let error):
                attachError = "Import failed: \(error.localizedDescription)"
            case .success(let url):
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url) else {
                    attachError = "Could not read the selected file."
                    return
                }
                guard let payload = InvoicesView.makeCapturePayload(fileData: data, fileName: url.lastPathComponent) else {
                    attachError = "Unsupported file. Choose an image or a PDF."
                    return
                }
                Task { await attach(payload) }
            }
        }
        .sheet(item: $previewItem, onDismiss: {
            // previewItem is already nil here — use the tracked URL.
            if let url = lastPreviewFileURL {
                try? FileManager.default.removeItem(at: url)
                lastPreviewFileURL = nil
            }
        }) { item in
            QuickLookPreview(url: item.fileURL)
                .ignoresSafeArea()
        }
    }

    /// Evidence attached from this app stores the GCS asset UUID in
    /// `location`; anything else has no previewable document.
    private func assetId(for item: GlEvidence) -> String? {
        guard let location = item.location, UUID(uuidString: location) != nil else {
            return nil
        }
        return location
    }

    private func loadEvidence() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            evidence = try await apiService.fetchEvidenceByJournal(journalId)
        } catch {
            loadError = "Could not load evidence."
        }
    }

    private func attach(_ payload: CapturePayload) async {
        isUploading = true
        attachError = nil
        defer { isUploading = false }
        do {
            let asset = try await apiService.uploadAsset(
                payload.data,
                kind: "evidence",
                contentType: payload.contentType,
                originalName: payload.originalName
            )
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            try await apiService.createEvidence(CreateEvidenceRequest(
                journalId: journalId,
                description: payload.originalName,
                location: asset.id,
                dateCreated: dateFormatter.string(from: Date()),
                confirmed: false
            ))
            await loadEvidence()
            await onEvidenceChanged()
        } catch let APIError.serverError(_, message) {
            attachError = message
        } catch {
            attachError = "Could not attach evidence: \(error.localizedDescription)"
        }
    }

    /// Fetches a fresh signed URL, downloads the bytes to a temp file,
    /// and presents QuickLook (same lifecycle as BillDocumentsView).
    private func preview(_ item: GlEvidence, assetId: String) async {
        loadingEvidenceId = item.id
        attachError = nil
        defer { loadingEvidenceId = nil }

        do {
            let signedURL = try await apiService.assetDownloadURL(id: assetId)
            let (data, response) = try await URLSession.shared.data(from: signedURL)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                attachError = "Could not download the document."
                return
            }

            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("evidence-\(assetId)")
                .appendingPathExtension(fileExtension(sniffing: data))
            // Encrypted at rest while it exists; removed on dismiss.
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            lastPreviewFileURL = fileURL
            previewItem = EvidencePreviewItem(fileURL: fileURL)
        } catch {
            attachError = error.localizedDescription
        }
    }

    /// gl_evidence rows don't carry a content type, so pick the QuickLook
    /// extension from the downloaded bytes.
    private func fileExtension(sniffing data: Data) -> String {
        if data.starts(with: Array("%PDF".utf8)) { return "pdf" }
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "png" }
        return "jpg"
    }
}

private struct EvidencePreviewItem: Identifiable {
    let id = UUID()
    let fileURL: URL
}
