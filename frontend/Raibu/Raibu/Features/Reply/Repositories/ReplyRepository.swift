//
//  ReplyRepository.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation

/// 回覆 Repository
class ReplyRepository: ReplyRepositoryProtocol {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Public Methods
    
    /// 建立回覆 (通用方法)
    func createReply(
        recordId: String?,
        askId: String?,
        content: String,
        images: [UploadedImage]?
    ) async throws -> Reply {
        let request = CreateReplyRequest(
            recordId: recordId,
            askId: askId,
            content: content,
            images: images?.map { $0.toCreateRequest() },
            currentLocation: nil
        )
        
        return try await apiClient.post(.createReply, body: request)
    }
    
    /// 建立紀錄的回覆
    func createReplyForRecord(
        recordId: String,
        content: String,
        images: [UploadedImage]?
    ) async throws -> Reply {
        let request = CreateReplyRequest(
            recordId: recordId,
            askId: nil,
            content: content,
            images: images?.map { $0.toCreateRequest() },
            currentLocation: nil
        )
        
        return try await apiClient.post(.createReply, body: request)
    }
    
    /// 建立詢問的回覆
    func createReplyForAsk(
        askId: String,
        content: String,
        images: [UploadedImage]?,
        currentLocation: Coordinate?
    ) async throws -> Reply {
        let request = CreateReplyRequest(
            recordId: nil,
            askId: askId,
            content: content,
            images: images?.map { $0.toCreateRequest() },
            currentLocation: currentLocation
        )
        
        return try await apiClient.post(.createReply, body: request)
    }
    
    /// 取得紀錄的回覆列表
    func getRepliesForRecord(recordId: String) async throws -> [Reply] {
        let response: RepliesResponse = try await apiClient.get(
            .getReplies(recordId: recordId, askId: nil)
        )
        return response.replies
    }
    
    /// 取得詢問的回覆列表
    func getRepliesForAsk(askId: String) async throws -> [Reply] {
        let response: RepliesResponse = try await apiClient.get(
            .getReplies(recordId: nil, askId: askId)
        )
        return response.replies
    }
    
    /// 刪除回覆
    func deleteReply(id: String) async throws {
        try await apiClient.delete(.deleteReply(id: id))
    }
    
    // MARK: - Like Methods (保留原有功能)
    
    /// 點讚/取消點讚 (通用)
    func toggleLike(request: ToggleLikeRequest) async throws -> ToggleLikeResponse {
        return try await apiClient.post(.toggleLike, body: request)
    }
    
    /// 對紀錄點讚
    func toggleLikeForRecord(id: String) async throws -> ToggleLikeResponse {
        return try await toggleLike(request: .forRecord(id))
    }
    
    /// 對詢問點讚
    func toggleLikeForAsk(id: String) async throws -> ToggleLikeResponse {
        return try await toggleLike(request: .forAsk(id))
    }
    
    /// 對回覆點讚
    func toggleLikeForReply(id: String) async throws -> ToggleLikeResponse {
        return try await toggleLike(request: .forReply(id))
    }
}
