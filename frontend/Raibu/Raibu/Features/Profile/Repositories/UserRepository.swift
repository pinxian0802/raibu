//
//  UserRepository.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation

/// 使用者 Repository
class UserRepository {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Public Methods
    
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
