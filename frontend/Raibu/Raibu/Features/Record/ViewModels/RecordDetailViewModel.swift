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
    @Published var isLoading = true
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
    
    /// 是否為作者（可操作編輯/刪除）
    var isOwner: Bool {
        guard let record = record else {
            print("⚠️ isOwner: record is nil")
            return false
        }
        guard let currentUserId = authService.currentUserId else {
            print("⚠️ isOwner: currentUserId is nil")
            return false
        }
        let isOwner = record.userId == currentUserId
        print("✅ isOwner check: recordUserId=\(record.userId), currentUserId=\(currentUserId), isOwner=\(isOwner)")
        return isOwner
    }
    
    // MARK: - Dependencies
    
    private let recordRepository: RecordRepository
    private let replyRepository: ReplyRepository
    private let authService: AuthService
    
    // MARK: - Task Management
    
    private var loadTask: Task<Void, Never>?
    private var likeTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(
        recordId: String,
        initialImageIndex: Int = 0,
        recordRepository: RecordRepository,
        replyRepository: ReplyRepository,
        authService: AuthService = AuthService.shared
    ) {
        self.recordId = recordId
        self.initialImageIndex = initialImageIndex
        self.recordRepository = recordRepository
        self.replyRepository = replyRepository
        self.authService = authService
    }
    
    deinit {
        // 取消所有進行中的 Tasks
        cancelAllTasks()
    }
    
    // MARK: - Public Methods
    
    /// 載入紀錄詳情
    func loadRecord() {
        // 取消之前的載入任務
        loadTask?.cancel()
        
        loadTask = Task { @MainActor in
            isLoading = true
            errorMessage = nil
            
            do {
                // 檢查是否已被取消
                try Task.checkCancellation()
                
                let loadedRecord = try await recordRepository.getRecordDetail(id: recordId)
                
                try Task.checkCancellation()
                
                let loadedReplies = try await replyRepository.getRepliesForRecord(recordId: recordId)
                
                try Task.checkCancellation()
                
                record = loadedRecord
                replies = loadedReplies
                isLiked = loadedRecord.userHasLiked ?? false
                likeCount = loadedRecord.likeCount
                isLoading = false
            } catch is CancellationError {
                // Task 被取消，不做任何處理
                print("📛 loadRecord task was cancelled")
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    /// 取消所有進行中的任務
    func cancelAllTasks() {
        loadTask?.cancel()
        likeTask?.cancel()
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
                isLiked = response.action == "liked"
                likeCount = response.likeCount
            }
        } catch {
            // 恢復原狀態
            await MainActor.run {
                isLiked.toggle()
                likeCount += isLiked ? 1 : -1
            }
        }
    }
    
    /// 切換回覆點讚狀態
    func toggleReplyLike(replyId: String) async {
        guard let index = replies.firstIndex(where: { $0.id == replyId }) else { return }
        
        let wasLiked = replies[index].userHasLiked ?? false
        let previousCount = replies[index].likeCount
        
        // 樂觀更新
        await MainActor.run {
            replies[index] = Reply(
                id: replies[index].id,
                recordId: replies[index].recordId,
                askId: replies[index].askId,
                userId: replies[index].userId,
                content: replies[index].content,
                isOnsite: replies[index].isOnsite,
                likeCount: wasLiked ? previousCount - 1 : previousCount + 1,
                createdAt: replies[index].createdAt,
                author: replies[index].author,
                images: replies[index].images,
                userHasLiked: !wasLiked
            )
        }
        
        do {
            let response = try await replyRepository.toggleLikeForReply(id: replyId)
            await MainActor.run {
                if let idx = replies.firstIndex(where: { $0.id == replyId }) {
                    replies[idx] = Reply(
                        id: replies[idx].id,
                        recordId: replies[idx].recordId,
                        askId: replies[idx].askId,
                        userId: replies[idx].userId,
                        content: replies[idx].content,
                        isOnsite: replies[idx].isOnsite,
                        likeCount: response.likeCount,
                        createdAt: replies[idx].createdAt,
                        author: replies[idx].author,
                        images: replies[idx].images,
                        userHasLiked: response.action == "liked"
                    )
                }
            }
        } catch {
            // 回滾
            await MainActor.run {
                if let idx = replies.firstIndex(where: { $0.id == replyId }) {
                    replies[idx] = Reply(
                        id: replies[idx].id,
                        recordId: replies[idx].recordId,
                        askId: replies[idx].askId,
                        userId: replies[idx].userId,
                        content: replies[idx].content,
                        isOnsite: replies[idx].isOnsite,
                        likeCount: previousCount,
                        createdAt: replies[idx].createdAt,
                        author: replies[idx].author,
                        images: replies[idx].images,
                        userHasLiked: wasLiked
                    )
                }
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
