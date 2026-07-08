//
//  AssetService.swift
//  nbledger
//
//  Swift client for the Go server's direct-to-GCS asset flow
//  (noble-go-server api/assets.go, mirrored from the Angular
//  noble-web asset.service.ts):
//
//    1. POST /:company/v1/assets/upload_url   -> { id, upload_url, http_method, headers }
//    2. PUT  <upload_url> <bytes>             -> direct to GCS, no backend bandwidth
//    3. POST /:company/v1/assets/:id/confirm  -> updated asset row
//
//  Downloads are short-lived signed URLs from
//    GET /:company/v1/assets/:id/download_url -> { download_url }
//
//  Signed URLs are minted by the backend; the app never sees GCS credentials.
//  All API paths ride APIService.request, which already targets the
//  tenant-aware {host}/{slug}/v1 base — nothing tenant-specific lives here.
//

import Foundation

// MARK: - Models (mirror noble-go-server api/assets.go JSON)

/// Response of `POST assets/upload_url` — a minted asset row plus a
/// short-lived signed PUT URL.
struct AssetUploadTicket: Codable {
    let id: String
    let uploadURL: String
    let objectKey: String?
    let expiresAt: String?
    let httpMethod: String?
    let headers: [String: String]?

    private enum CodingKeys: String, CodingKey {
        case id
        case uploadURL = "upload_url"
        case objectKey = "object_key"
        case expiresAt = "expires_at"
        case httpMethod = "http_method"
        case headers
    }
}

/// A row of `public.assets` as returned by confirm/list endpoints.
struct AssetRecord: Identifiable, Codable {
    let id: String
    let kind: String?
    let objectKey: String?
    let contentType: String?
    let originalName: String?
    let sizeBytes: Int?
    let uploaded: Bool?
    let createdAt: String?
    let confirmedAt: String?

    private enum CodingKeys: String, CodingKey {
        case id, kind
        case objectKey = "object_key"
        case contentType = "content_type"
        case originalName = "original_name"
        case sizeBytes = "size_bytes"
        case uploaded
        case createdAt = "created_at"
        case confirmedAt = "confirmed_at"
    }
}

/// Response of `GET assets/:id/download_url`.
struct AssetDownloadURL: Codable {
    let downloadURL: String
    let expiresAt: String?

    private enum CodingKeys: String, CodingKey {
        case downloadURL = "download_url"
        case expiresAt = "expires_at"
    }
}

// MARK: - Asset endpoints

extension APIService {

    /// Step 1 — ask the backend to mint a signed upload URL.
    /// `kind` groups objects in the bucket (e.g. "receipt", "invoice").
    func requestAssetUploadURL(kind: String, contentType: String, originalName: String? = nil) async throws -> AssetUploadTicket {
        struct UploadURLRequest: Encodable {
            let kind: String
            let contentType: String
            let originalName: String?

            private enum CodingKeys: String, CodingKey {
                case kind
                case contentType = "content_type"
                case originalName = "original_name"
            }
        }

        let body = try JSONEncoder().encode(UploadURLRequest(
            kind: kind,
            contentType: contentType,
            originalName: originalName
        ))
        let data = try await request("/assets/upload_url", method: "POST", body: body)
        do {
            return try decoder.decode(AssetUploadTicket.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    /// Step 3 — tell the backend the PUT to GCS completed. The server
    /// verifies the object exists in the bucket before confirming.
    @discardableResult
    func confirmAsset(id: String, sizeBytes: Int) async throws -> AssetRecord {
        struct ConfirmRequest: Encodable {
            let sizeBytes: Int

            private enum CodingKeys: String, CodingKey {
                case sizeBytes = "size_bytes"
            }
        }

        let body = try JSONEncoder().encode(ConfirmRequest(sizeBytes: sizeBytes))
        let data = try await request("/assets/\(escapePathComponent(id))/confirm", method: "POST", body: body)
        do {
            return try decoder.decode(AssetRecord.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    /// Fetch a short-lived signed GET URL for a confirmed asset.
    func assetDownloadURL(id: String) async throws -> URL {
        let data = try await request("/assets/\(escapePathComponent(id))/download_url")
        guard let decoded = try? decoder.decode(AssetDownloadURL.self, from: data),
              let url = URL(string: decoded.downloadURL) else {
            throw APIError.decodingFailed
        }
        return url
    }

    /// List assets for the current user in the current tenant, optionally
    /// filtered by kind (kind-filtered listing is tenant-wide server-side).
    func listAssets(kind: String? = nil) async throws -> [AssetRecord] {
        var path = "/assets"
        if let kind, !kind.isEmpty,
           let encoded = kind.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "?kind=\(encoded)"
        }
        let data = try await request(path)
        do {
            return try decoder.decode([AssetRecord].self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    /// Delete an asset (the backend soft-deletes the row and removes the
    /// GCS object).
    func deleteAsset(id: String) async throws {
        _ = try await request("/assets/\(escapePathComponent(id))", method: "DELETE")
    }

    /// One-shot upload: mint the signed URL, PUT the bytes to GCS, and
    /// confirm. A successful confirm IS success — the asset is stored
    /// server-side and this returns the confirmed row. Callers that need to
    /// display the document fetch a fresh signed URL via
    /// `assetDownloadURL(id:)` at display time (signed URLs expire in ~15
    /// minutes, and a failure minting one must not read as a failed upload).
    @discardableResult
    func uploadAsset(_ data: Data, kind: String, contentType: String, originalName: String? = nil) async throws -> AssetRecord {
        let ticket = try await requestAssetUploadURL(
            kind: kind,
            contentType: contentType,
            originalName: originalName
        )
        try await putAssetBytes(data, ticket: ticket, fallbackContentType: contentType)
        return try await confirmAsset(id: ticket.id, sizeBytes: data.count)
    }

    /// Step 2 — PUT the bytes directly to GCS. The signed URL carries its own
    /// auth, so no Authorization header is sent here.
    private func putAssetBytes(_ data: Data, ticket: AssetUploadTicket, fallbackContentType: String) async throws {
        guard let url = URL(string: ticket.uploadURL) else {
            throw APIError.serverError(statusCode: 0, message: "Invalid upload URL.")
        }

        var req = URLRequest(url: url)
        req.httpMethod = (ticket.httpMethod ?? "PUT").uppercased()
        var headers = ticket.headers ?? [:]
        if headers["Content-Type"] == nil {
            headers["Content-Type"] = fallbackContentType
        }
        for (field, value) in headers {
            req.setValue(value, forHTTPHeaderField: field)
        }

        do {
            let (_, response) = try await session.upload(for: req, from: data)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.serverError(statusCode: 0, message: "Invalid storage response.")
            }
            guard (200..<300).contains(http.statusCode) else {
                throw APIError.serverError(statusCode: http.statusCode, message: "Upload to storage failed (\(http.statusCode)).")
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func escapePathComponent(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}
