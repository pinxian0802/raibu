//
//  Reply.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation

/// 回覆模型
struct Reply: Codable, Identifiable, Equatable {
    let id: String
    let recordId: String?
    let askId: String?
    let userId: String
    let content: String
    let isOnsite: Bool?
    let likeCount: Int
    let createdAt: Date
    
    // 關聯資料
    var author: User?
    var images: [ImageMedia]?
    var userHasLiked: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case recordId = "record_id"
        case askId = "ask_id"
        case userId = "user_id"
        case content
        case isOnsite = "is_onsite"
        case likeCount = "like_count"
        case createdAt = "created_at"
        case author
        case images
        case userHasLiked = "user_has_liked"
    }
    
    static func == (lhs: Reply, rhs: Reply) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - API Request Models

/// 建立回覆請求
struct CreateReplyRequest: Codable {
    let recordId: String?
    let askId: String?
    let content: String
    let images: [CreateImageRequest]?
    let currentLocation: Coordinate?
    
    enum CodingKeys: String, CodingKey {
        case recordId = "record_id"
        case askId = "ask_id"
        case content
        case images
        case currentLocation = "current_location"
    }
}

// MARK: - API Response Models

/// 回覆列表回應
struct RepliesResponse: Codable {
    let replies: [Reply]
}
