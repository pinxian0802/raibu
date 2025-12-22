//
//  RecordDetailViewModel.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation
import Combine

/// 紀錄詳情視圖模型
class RecordDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var record: Record?
    @Published var replies: [Reply] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 互動
    @Published var isLiked = false
    @Published var likeCount = 0
    
    // 刪除確認
    @Published var showDeleteConfirmation = false
    @Published var isDeleting = false
    
    // MARK: - Properties
    
    let recordId: String
    let initialImageIndex: Int
    
    // MARK: - Dependencies
    
    private let recordRepository: RecordRepository
    private let replyRepository: ReplyRepository
    
    // MARK: - Initialization
    
    init(
        recordId: String,
        initialImageIndex: Int = 0,
        recordRepository: RecordRepository,
        replyRepository: ReplyRepository
    ) {
        self.recordId = recordId
        self.initialImageIndex = initialImageIndex
        self.recordRepository = recordRepository
        self.replyRepository = replyRepository
    }
    
    // MARK: - Public Methods
    
    /// 載入紀錄詳情
    func loadRecord() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let loadedRecord = try await recordRepository.getRecordDetail(id: recordId)
            let loadedReplies = try await replyRepository.getRepliesForRecord(recordId: recordId)
            
            await MainActor.run {
                record = loadedRecord
                replies = loadedReplies
                isLiked = loadedRecord.userHasLiked ?? false
                likeCount = loadedRecord.likeCount
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    /// 切換點讚狀態
    func toggleLike() async {
        // 先樂觀更新 UI
        await MainActor.run {
            isLiked.toggle()
            likeCount += isLiked ? 1 : -1
        }
        
        do {
            let response = try await replyRepository.toggleLikeForRecord(id: recordId)
            
            await MainActor.run {
                isLiked = response.liked
                likeCount = response.newCount
            }
        } catch {
            // 恢復原狀態
            await MainActor.run {
                isLiked.toggle()
                likeCount += isLiked ? 1 : -1
            }
        }
    }
    
    /// 刪除紀錄
    func deleteRecord() async -> Bool {
        await MainActor.run {
            isDeleting = true
        }
        
        do {
            try await recordRepository.deleteRecord(id: recordId)
            return true
        } catch {
            await MainActor.run {
                errorMessage = "刪除失敗: \(error.localizedDescription)"
                isDeleting = false
            }
            return false
        }
    }
    
    /// 檢查是否為作者
    func isAuthor(userId: String) -> Bool {
        record?.userId == userId
    }
}
