//
//  Like.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation

/// 點讚模型
struct Like: Codable, Identifiable {
    let id: String
    let userId: String
    let recordId: String?
    let askId: String?
    let replyId: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case recordId = "record_id"
        case askId = "ask_id"
        case replyId = "reply_id"
        case createdAt = "created_at"
    }
}

// MARK: - API Request Models

/// 點讚/取消點讚請求
struct ToggleLikeRequest: Codable {
    let recordId: String?
    let askId: String?
    let replyId: String?
    
    enum CodingKeys: String, CodingKey {
        case recordId = "record_id"
        case askId = "ask_id"
        case replyId = "reply_id"
    }
    
    /// 對紀錄點讚
    static func forRecord(_ id: String) -> ToggleLikeRequest {
        ToggleLikeRequest(recordId: id, askId: nil, replyId: nil)
    }
    
    /// 對詢問點讚
    static func forAsk(_ id: String) -> ToggleLikeRequest {
        ToggleLikeRequest(recordId: nil, askId: id, replyId: nil)
    }
    
    /// 對回覆點讚
    static func forReply(_ id: String) -> ToggleLikeRequest {
        ToggleLikeRequest(recordId: nil, askId: nil, replyId: id)
    }
}

/// 點讚回應
struct ToggleLikeResponse: Codable {
    let success: Bool
    let action: String  // "liked" or "unliked"
    let likeCount: Int
    
    enum CodingKeys: String, CodingKey {
        case success
        case action
        case likeCount = "like_count"
    }
}
