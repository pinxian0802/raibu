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
    @Published var optimisticReplies: [OptimisticReply] = []   // 送出中 / 失敗的暫時回覆
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var isSubmittingReply = false
    
    // 互動
    @Published var isLiked = false
    @Published var likeCount = 0
    
    // 刪除確認
    @Published var showDeleteConfirmation = false
    @Published var isDeleting = false
    
    // 關注 (Mock)
    @Published var isFollowed = false
    
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

    var currentUserId: String? {
        authService.currentUserId
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
                replies = loadedReplies.reversed()   // 最新在前
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
    
    /// 建立留言（含 optimistic insert）
    func createReply(content: String, images: [UploadedImage]? = nil, selectedPhotos: [SelectedPhoto] = []) async -> Bool {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return false }
        // If this call was initiated after an optimistic insert, a tempId will be provided
        // (we'll use a separate overload that accepts a tempId). This implementation
        // keeps backward compatibility by performing the full flow if no tempId exists.

        // Default behavior when called directly: perform optimistic insert here
        let tempId = UUID().uuidString
        let currentUser = authService.currentUser
        let optimistic = OptimisticReply(
            id: tempId,
            content: trimmedContent,
            author: currentUser,
            selectedPhotos: selectedPhotos,
            status: .pending
        )

        await MainActor.run {
            optimisticReplies.insert(optimistic, at: 0)
            isSubmittingReply = true
        }

        do {
            let reply = try await replyRepository.createReplyForRecord(
                recordId: recordId,
                content: trimmedContent,
                images: images
            )

            await MainActor.run {
                // 移除 optimistic，插入真實回覆到最前面
                optimisticReplies.removeAll { $0.id == tempId }
                replies.insert(reply, at: 0)
                isSubmittingReply = false
            }
            return true
        } catch {
            await MainActor.run {
                // 標記失敗
                if let idx = optimisticReplies.firstIndex(where: { $0.id == tempId }) {
                    optimisticReplies[idx] = OptimisticReply(
                        id: tempId,
                        content: trimmedContent,
                        author: currentUser,
                        selectedPhotos: selectedPhotos,
                        status: .failed(error)
                    )
                }
                isSubmittingReply = false
            }
            return false
        }
    }

    /// 直接插入一個 optimistic reply 並回傳 tempId（用於立即顯示）
    @MainActor
    func insertOptimisticReply(content: String, selectedPhotos: [SelectedPhoto]) -> String {
        let tempId = UUID().uuidString
        let optimistic = OptimisticReply(
            id: tempId,
            content: content,
            author: authService.currentUser,
            selectedPhotos: selectedPhotos,
            status: .pending
        )
        // Insert synchronously on main actor — callers from SwiftUI views are already on main thread
        optimisticReplies.insert(optimistic, at: 0)
        isSubmittingReply = true
        return tempId
    }

    /// 完成 create（用於在完成 upload 後用 tempId 替換）
    func finishCreateReply(tempId: String, content: String, images: [UploadedImage]?) async {
        do {
            let reply = try await replyRepository.createReplyForRecord(
                recordId: recordId,
                content: content,
                images: images
            )
            await MainActor.run {
                self.optimisticReplies.removeAll { $0.id == tempId }
                self.replies.insert(reply, at: 0)
                self.isSubmittingReply = false
            }
        } catch {
            await MainActor.run {
                if let idx = self.optimisticReplies.firstIndex(where: { $0.id == tempId }) {
                    let item = self.optimisticReplies[idx]
                    self.optimisticReplies[idx] = OptimisticReply(
                        id: tempId,
                        content: item.content,
                        author: item.author,
                        selectedPhotos: item.selectedPhotos,
                        status: .failed(error)
                    )
                }
                self.isSubmittingReply = false
            }
        }
    }

    /// 重新傳送失敗的 optimistic reply
    func retryOptimisticReply(id: String, images: [UploadedImage]? = nil) async {
        guard let item = optimisticReplies.first(where: { $0.id == id }) else { return }

        // 重置狀態為 pending
        await MainActor.run {
            if let idx = optimisticReplies.firstIndex(where: { $0.id == id }) {
                optimisticReplies[idx] = OptimisticReply(
                    id: id,
                    content: item.content,
                    author: item.author,
                    selectedPhotos: item.selectedPhotos,
                    status: .pending
                )
            }
        }

        do {
            let reply = try await replyRepository.createReplyForRecord(
                recordId: recordId,
                content: item.content,
                images: images
            )
            await MainActor.run {
                optimisticReplies.removeAll { $0.id == id }
                replies.insert(reply, at: 0)
            }
        } catch {
            await MainActor.run {
                if let idx = optimisticReplies.firstIndex(where: { $0.id == id }) {
                    optimisticReplies[idx] = OptimisticReply(
                        id: id,
                        content: item.content,
                        author: item.author,
                        selectedPhotos: item.selectedPhotos,
                        status: .failed(error)
                    )
                }
            }
        }
    }

    /// 刪除失敗的 optimistic reply
    func removeOptimisticReply(id: String) {
        optimisticReplies.removeAll { $0.id == id }
    }

    /// 刪除留言
    func deleteReply(replyId: String) async -> Bool {
        do {
            try await replyRepository.deleteReply(id: replyId)
            await MainActor.run {
                replies.removeAll { $0.id == replyId }
            }
            return true
        } catch {
            await MainActor.run {
                errorMessage = "刪除留言失敗: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    /// 切換關注狀態 (Mock)
    func toggleFollow() {
        isFollowed.toggle()
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
