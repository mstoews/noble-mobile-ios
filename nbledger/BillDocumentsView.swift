//
//  BillDocumentsView.swift
//  nbledger
//
//  "Documents" section for a saved bill: lists the assets attached to its
//  journal entry (GET list_bill_assets/:journal_id) and previews one on
//  tap. Signed download URLs expire in ~15 minutes, so a fresh URL is
//  fetched for every preview and never cached, persisted, or logged.
//

import SwiftUI
import QuickLook

struct BillDocumentsView: View {
    @Environment(APIService.self) private var apiService

    let journalId: Int

    @State private var assets: [AssetRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var previewItem: DocumentPreviewItem?
    @State private var lastPreviewFileURL: URL?
    @State private var loadingAssetId: String?
    @State private var previewError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Documents")
                .font(.headline)

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading documents...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else if let errorMessage {
                VStack(spacing: 8) {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    Button("Retry") { Task { await loadAssets() } }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
            } else if assets.isEmpty {
                Text("No documents attached.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(assets) { asset in
                        Button {
                            Task { await preview(asset) }
                        } label: {
                            documentRow(asset)
                        }
                        .buttonStyle(.plain)
                        .disabled(loadingAssetId != nil)

                        if asset.id != assets.last?.id {
                            Divider()
                        }
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            if let previewError {
                Text(previewError)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
        }
        .task(id: journalId) { await loadAssets() }
        .sheet(item: $previewItem, onDismiss: {
            // previewItem is already nil here — use the tracked URL.
            if let url = lastPreviewFileURL {
                removePreviewFile(at: url)
                lastPreviewFileURL = nil
            }
        }) { item in
            QuickLookPreview(url: item.fileURL)
                .ignoresSafeArea()
        }
    }

    private func documentRow(_ asset: AssetRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconName(for: asset))
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.originalName ?? "Document")
                    .font(.subheadline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let contentType = asset.contentType {
                        Text(contentType)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let size = asset.sizeBytes {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if loadingAssetId == asset.id {
                ProgressView()
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }

    private func iconName(for asset: AssetRecord) -> String {
        switch asset.contentType {
        case .some(let type) where type.hasPrefix("image/"):
            return "photo"
        case .some("application/pdf"):
            return "doc.richtext"
        default:
            return "doc"
        }
    }

    private func loadAssets() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            assets = try await apiService.listBillAssets(journalId: journalId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Fetches a fresh signed URL (they expire in ~15 min — never reuse),
    /// downloads the bytes to a temporary file, and presents QuickLook.
    private func preview(_ asset: AssetRecord) async {
        loadingAssetId = asset.id
        previewError = nil
        defer { loadingAssetId = nil }

        do {
            let signedURL = try await apiService.assetDownloadURL(id: asset.id)
            let (data, response) = try await URLSession.shared.data(from: signedURL)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                previewError = "Could not download the document."
                return
            }

            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("bill-doc-\(asset.id)")
                .appendingPathExtension(fileExtension(for: asset))
            // Encrypted at rest while it exists; removed on dismiss.
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            lastPreviewFileURL = fileURL
            previewItem = DocumentPreviewItem(fileURL: fileURL)
        } catch {
            previewError = error.localizedDescription
        }
    }

    /// Deletes the temporary preview file once the QuickLook sheet is
    /// dismissed — document bytes never accumulate on disk.
    private func removePreviewFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// A file extension QuickLook can use to pick a renderer.
    private func fileExtension(for asset: AssetRecord) -> String {
        if let name = asset.originalName {
            let ext = (name as NSString).pathExtension
            if !ext.isEmpty { return ext }
        }
        switch asset.contentType {
        case .some("image/jpeg"): return "jpg"
        case .some("image/png"):  return "png"
        case .some("image/gif"):  return "gif"
        case .some("image/webp"): return "webp"
        case .some("application/pdf"): return "pdf"
        default: return "dat"
        }
    }
}

// MARK: - Preview plumbing

private struct DocumentPreviewItem: Identifiable {
    let id = UUID()
    let fileURL: URL
}

/// QLPreviewController wrapper for a local temporary file.
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        uiViewController.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
