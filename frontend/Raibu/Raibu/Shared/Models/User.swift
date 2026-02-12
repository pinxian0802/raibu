//
//  User.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation

/// 使用者模型
struct User: Codable, Identifiable, Equatable {
    let id: String
    let displayName: String
    let avatarUrl: String?
    let bio: String?
    let totalViews: Int?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case bio
        case totalViews = "total_views"
        case createdAt = "created_at"
    }
    
    // 明確初始化器
    init(id: String, displayName: String, avatarUrl: String? = nil, bio: String? = nil, totalViews: Int? = nil, createdAt: Date? = nil) {
        self.id = id
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.bio = bio
        self.totalViews = totalViews
        self.createdAt = createdAt
    }
}

/// 個人資訊 API 回應
struct UserProfile: Codable {
    let id: String
    let displayName: String
    let avatarUrl: String?
    let bio: String?
    let totalRecords: Int
    let totalAsks: Int
    let totalViews: Int
    let totalLikes: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case bio
        case totalRecords = "total_records"
        case totalAsks = "total_asks"
        case totalViews = "total_views"
        case totalLikes = "total_likes"
        case createdAt = "created_at"
    }
}

