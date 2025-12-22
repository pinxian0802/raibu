//
//  Record.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation

/// 紀錄標點模型
struct Record: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let description: String
    let mainImageUrl: String?
    let mediaCount: Int
    let likeCount: Int
    let viewCount: Int
    let createdAt: Date
    let updatedAt: Date?
    
    // 關聯資料 (詳情 API 回傳)
    var author: User?
    var images: [ImageMedia]?
    var userHasLiked: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case description
        case mainImageUrl = "main_image_url"
        case mediaCount = "media_count"
        case likeCount = "like_count"
        case viewCount = "view_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case author
        case images
        case userHasLiked = "user_has_liked"
    }
    
    static func == (lhs: Record, rhs: Record) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - API Request Models

/// 建立紀錄請求
struct CreateRecordRequest: Codable {
    let description: String
    let images: [CreateImageRequest]
}

/// 編輯紀錄請求
struct UpdateRecordRequest: Codable {
    let description: String?
    let sortedImages: [SortedImageItem]
    
    enum CodingKeys: String, CodingKey {
        case description
        case sortedImages = "sorted_images"
    }
}

/// 排序圖片項目
struct SortedImageItem: Codable {
    let type: ImageItemType
    let imageId: String?      // EXISTING 時使用
    let uploadId: String?     // NEW 時使用
    let location: Coordinate?
    let capturedAt: Date?
    
    enum ImageItemType: String, Codable {
        case existing = "EXISTING"
        case new = "NEW"
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case imageId = "image_id"
        case uploadId = "upload_id"
        case location
        case capturedAt = "captured_at"
    }
}

// MARK: - API Response Models

/// 地圖紀錄圖片回應
struct MapRecordImage: Codable, Identifiable {
    let imageId: String
    let recordId: String
    let thumbnailPublicUrl: String
    let lat: Double
    let lng: Double
    let displayOrder: Int
    
    var id: String { imageId }
    
    var coordinate: Coordinate {
        Coordinate(lat: lat, lng: lng)
    }
    
    enum CodingKeys: String, CodingKey {
        case imageId = "image_id"
        case recordId = "record_id"
        case thumbnailPublicUrl = "thumbnail_public_url"
        case lat
        case lng
        case displayOrder = "display_order"
    }
}

/// 地圖紀錄回應
struct MapRecordsResponse: Codable {
    let images: [MapRecordImage]
}

/// 紀錄詳情回應 (直接使用 Record)

/// 使用者紀錄列表回應
struct UserRecordsResponse: Codable {
    let records: [Record]
}
