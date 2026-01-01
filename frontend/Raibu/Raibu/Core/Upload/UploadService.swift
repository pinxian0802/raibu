//
//  UploadService.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation
import Photos
import Combine

/// 上傳情境
enum UploadContext {
    case record      // 紀錄模式 (需要 GPS)
    case ask         // 詢問模式 (不需要 GPS)
    case reply       // 回覆 (不需要 GPS)
}

/// 兩階段上傳服務
class UploadService: ObservableObject {
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Public Methods
    
    /// 批次上傳圖片
    /// - Parameters:
    ///   - photos: 選取的照片陣列
    ///   - context: 上傳情境
    /// - Returns: 上傳完成的圖片資訊陣列
    func uploadPhotos(_ photos: [SelectedPhoto], context: UploadContext) async throws -> [UploadedImage] {
        guard !photos.isEmpty else { return [] }
        
        await MainActor.run {
            isUploading = true
            uploadProgress = 0
        }
        
        defer {
            Task { @MainActor in
                isUploading = false
            }
        }
        
        // Step 1: 請求上傳憑證 (API A-1)
        let imageRequests = photos.map { photo in
            ImageUploadRequest(
                clientKey: photo.id,
                fileType: photo.mimeType,
                fileSize: photo.fileSize
            )
        }
        
        let credentialsResponse: UploadCredentialsResponse = try await apiClient.post(
            .uploadRequest,
            body: UploadCredentialsRequest(imageRequests: imageRequests)
        )
        
        let credentials = credentialsResponse.uploadCredentials
        
        await MainActor.run {
            uploadProgress = 0.2  // 20% - 取得憑證完成
        }
        
        // Step 2: 並行上傳至 R2
        let totalUploads = Double(photos.count * 2)  // 每張圖片 = 原圖 + 縮圖
        var completedUploads = 0
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for photo in photos {
                guard let cred = credentials[photo.id] else {
                    throw UploadError.missingCredential(clientKey: photo.id)
                }
                
                // 上傳原圖
                group.addTask {
                    guard let originalUrl = URL(string: cred.originalUploadUrl) else {
                        throw UploadError.invalidURL
                    }
                    try await self.apiClient.uploadToPresignedURL(
                        data: photo.originalData,
                        url: originalUrl,
                        contentType: photo.mimeType
                    )
                }
                
                // 上傳縮圖
                group.addTask {
                    guard let thumbnailUrl = URL(string: cred.thumbnailUploadUrl) else {
                        throw UploadError.invalidURL
                    }
                    try await self.apiClient.uploadToPresignedURL(
                        data: photo.thumbnailData,
                        url: thumbnailUrl,
                        contentType: "image/jpeg"
                    )
                }
            }
            
            // 等待所有上傳完成並更新進度
            for try await _ in group {
                completedUploads += 1
                await MainActor.run {
                    uploadProgress = 0.2 + (Double(completedUploads) / totalUploads) * 0.8
                }
            }
        }
        
        // Step 3: 組裝結果
        return photos.enumerated().map { index, photo in
            let cred = credentials[photo.id]!
            return UploadedImage(
                uploadId: cred.uploadId,
                originalPublicUrl: cred.originalPublicUrl,
                thumbnailPublicUrl: cred.thumbnailPublicUrl,
                location: photo.location,
                capturedAt: photo.capturedAt,
                displayOrder: index,
                address: photo.address
            )
        }
    }
}

// MARK: - Request/Response Models

struct UploadCredentialsRequest: Codable {
    let imageRequests: [ImageUploadRequest]
    
    enum CodingKeys: String, CodingKey {
        case imageRequests = "image_requests"
    }
}

struct ImageUploadRequest: Codable {
    let clientKey: String
    let fileType: String
    let fileSize: Int
    
    enum CodingKeys: String, CodingKey {
        case clientKey = "client_key"
        case fileType
        case fileSize
    }
}

struct UploadCredentialsResponse: Codable {
    let uploadCredentials: [String: UploadCredential]
    
    enum CodingKeys: String, CodingKey {
        case uploadCredentials = "upload_credentials"
    }
}

struct UploadCredential: Codable {
    let uploadId: String
    let originalUploadUrl: String
    let thumbnailUploadUrl: String
    let originalPublicUrl: String
    let thumbnailPublicUrl: String
    
    enum CodingKeys: String, CodingKey {
        case uploadId = "upload_id"
        case originalUploadUrl = "original_upload_url"
        case thumbnailUploadUrl = "thumbnail_upload_url"
        case originalPublicUrl = "original_public_url"
        case thumbnailPublicUrl = "thumbnail_public_url"
    }
}

// MARK: - Local Models

/// 選取的照片（前端本地使用）
struct SelectedPhoto: Identifiable, Equatable {
    let id: String  // client_key
    let asset: PHAsset
    let originalData: Data
    let thumbnailData: Data
    let mimeType: String
    let fileSize: Int
    let location: Coordinate?
    let capturedAt: Date?
    var address: String?  // 逆向地理編碼後的地址
    
    static func == (lhs: SelectedPhoto, rhs: SelectedPhoto) -> Bool {
        lhs.id == rhs.id
    }
}

/// 上傳完成的圖片（用於建立標點 API）
struct UploadedImage {
    let uploadId: String
    let originalPublicUrl: String
    let thumbnailPublicUrl: String
    let location: Coordinate?
    let capturedAt: Date?
    let displayOrder: Int
    let address: String?
    
    /// 轉換為 API 請求格式
    func toCreateRequest() -> CreateImageRequest {
        CreateImageRequest(
            uploadId: uploadId,
            originalPublicUrl: originalPublicUrl,
            thumbnailPublicUrl: thumbnailPublicUrl,
            location: location,
            capturedAt: capturedAt,
            displayOrder: displayOrder,
            address: address
        )
    }
}

// MARK: - Upload Errors

enum UploadError: LocalizedError {
    case missingCredential(clientKey: String)
    case invalidURL
    case uploadFailed
    
    var errorDescription: String? {
        switch self {
        case .missingCredential(let key):
            return "找不到圖片憑證: \(key)"
        case .invalidURL:
            return "無效的上傳 URL"
        case .uploadFailed:
            return "圖片上傳失敗"
        }
    }
}
