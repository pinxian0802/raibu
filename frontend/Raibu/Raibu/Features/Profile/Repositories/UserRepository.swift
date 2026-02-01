//
//  UserRepository.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation

/// 使用者 Repository
class UserRepository: UserRepositoryProtocol {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Public Methods (Protocol Conformance)
    
    /// 取得使用者資訊
    func getUserProfile(id: String) async throws -> User {
        // 目前 API 只支援取得當前用戶
        let profile: UserProfile = try await apiClient.get(.getMe)
        return profile.toUser()
    }
    
    /// 更新個人資料
    func updateProfile(displayName: String?, avatarUrl: String?) async throws -> User {
        let request = UpdateProfileRequest(
            displayName: displayName,
            avatarUrl: avatarUrl
        )
        let profile: UserProfile = try await apiClient.patch(.updateMe, body: request)
        return profile.toUser()
    }
    
    /// 取得使用者的紀錄列表
    func getUserRecords(userId: String, page: Int, limit: Int) async throws -> [Record] {
        // 目前 API 只支援取得當前用戶的紀錄
        let response: UserRecordsResponse = try await apiClient.get(.getMyRecords)
        return response.records
    }
    
    /// 取得使用者的詢問列表
    func getUserAsks(userId: String, page: Int, limit: Int) async throws -> [Ask] {
        // 目前 API 只支援取得當前用戶的詢問
        let response: UserAsksResponse = try await apiClient.get(.getMyAsks)
        return response.asks
    }
    
    // MARK: - Legacy Methods (保持相容)
    
    /// 取得當前使用者資訊
    func getMe() async throws -> UserProfile {
        return try await apiClient.get(.getMe)
    }
    
    /// 取得當前使用者的紀錄列表
    func getMyRecords() async throws -> [Record] {
        let response: UserRecordsResponse = try await apiClient.get(.getMyRecords)
        return response.records
    }
    
    /// 取得當前使用者的詢問列表
    func getMyAsks() async throws -> [Ask] {
        let response: UserAsksResponse = try await apiClient.get(.getMyAsks)
        return response.asks
    }
}

// MARK: - Helper Models

struct UpdateProfileRequest: Codable {
    let displayName: String?
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
    }
}

extension UserProfile {
    func toUser() -> User {
        return User(
            id: id,
            displayName: displayName,
            avatarUrl: avatarUrl,
            totalViews: totalViews,
            createdAt: createdAt
        )
    }
}
