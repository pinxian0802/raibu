//
//  Ask.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation

/// 詢問標點狀態
enum AskStatus: String, Codable {
    case active = "ACTIVE"
    case resolved = "RESOLVED"
}

/// 詢問標點模型
struct Ask: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let center: Coordinate
    let radiusMeters: Int
    let title: String?
    let question: String
    let mainImageUrl: String?
    let status: AskStatus
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
        case center
        case radiusMeters = "radius_meters"
        case title
        case question
        case mainImageUrl = "main_image_url"
        case status
        case likeCount = "like_count"
        case viewCount = "view_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case author
        case images
        case userHasLiked = "user_has_liked"
    }
    
    /// 檢查是否在 48 小時內 (前端顯示規則)
    var isWithin48Hours: Bool {
        let cutoff = Date().addingTimeInterval(-48 * 60 * 60)
        return createdAt >= cutoff
    }
    
    static func == (lhs: Ask, rhs: Ask) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - API Request Models

/// 建立詢問請求
struct CreateAskRequest: Codable {
    let center: Coordinate
    let radiusMeters: Int
    let title: String?
    let question: String
    let images: [CreateImageRequest]?
    
    enum CodingKeys: String, CodingKey {
        case center
        case radiusMeters = "radius_meters"
        case title
        case question
        case images
    }
}

/// 編輯詢問請求
struct UpdateAskRequest: Codable {
    let title: String?
    let question: String?
    let status: AskStatus?
    let sortedImages: [SortedImageItem]?
    
    enum CodingKeys: String, CodingKey {
        case title
        case question
        case status
        case sortedImages = "sorted_images"
    }
}

// MARK: - API Response Models

/// 地圖詢問回應
struct MapAsk: Codable, Identifiable {
    let id: String
    let center: Coordinate
    let radiusMeters: Int
    let title: String?
    let question: String
    let mainImageUrl: String?
    let authorAvatarUrl: String?
    let status: AskStatus
    let createdAt: Date
    let likeCount: Int?
    let viewCount: Int?

    init(
        id: String,
        center: Coordinate,
        radiusMeters: Int,
        title: String? = nil,
        question: String,
        mainImageUrl: String? = nil,
        authorAvatarUrl: String? = nil,
        status: AskStatus,
        createdAt: Date,
        likeCount: Int? = nil,
        viewCount: Int? = nil
    ) {
        self.id = id
        self.center = center
        self.radiusMeters = radiusMeters
        self.title = title
        self.question = question
        self.mainImageUrl = mainImageUrl
        self.authorAvatarUrl = authorAvatarUrl
        self.status = status
        self.createdAt = createdAt
        self.likeCount = likeCount
        self.viewCount = viewCount
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case center
        case radiusMeters = "radius_meters"
        case title
        case question
        case mainImageUrl = "main_image_url"
        case authorAvatarUrl = "author_avatar_url"
        case status
        case createdAt = "created_at"
        case likeCount = "like_count"
        case viewCount = "view_count"
    }
    
    /// 檢查是否在 48 小時內 (前端顯示規則)
    var isWithin48Hours: Bool {
        let cutoff = Date().addingTimeInterval(-48 * 60 * 60)
        return createdAt >= cutoff
    }
}

/// 地圖詢問列表回應
struct MapAsksResponse: Codable {
    let asks: [MapAsk]
}

/// 使用者詢問列表回應
struct UserAsksResponse: Codable {
    let asks: [Ask]
}
