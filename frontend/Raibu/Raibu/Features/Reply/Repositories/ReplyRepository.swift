//
//  ReplyRepository.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation

/// 回覆 Repository
class ReplyRepository {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Public Methods
    
    /// 建立回覆
    func createReply(
        recordId: String? = nil,
        askId: String? = nil,
        content: String,
        images: [UploadedImage]?
    ) async throws -> Reply {
        let request = CreateReplyRequest(
            recordId: recordId,
            askId: askId,
            content: content,
            images: images?.map { $0.toCreateRequest() }
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
