//
//  AskDetailSheetView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI
import Combine

/// 詢問詳情 Sheet
struct AskDetailSheetView: View {
    let askId: String
    let askRepository: AskRepository
    let replyRepository: ReplyRepository
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AskDetailViewModel
    
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    @State private var showReplySheet = false
    
    init(askId: String, askRepository: AskRepository, replyRepository: ReplyRepository) {
        self.askId = askId
        self.askRepository = askRepository
        self.replyRepository = replyRepository
        _viewModel = StateObject(wrappedValue: AskDetailViewModel(
            askId: askId,
            askRepository: askRepository,
            replyRepository: replyRepository
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let ask = viewModel.ask {
                        askContent(ask)
                    } else if let error = viewModel.errorMessage {
                        errorView(error)
                    }
                }
                .padding()
            }
            .navigationTitle("詢問詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("關閉") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.ask?.userId == viewModel.currentUserId {
                        Menu {
                            Button {
                                showEditSheet = true
                            } label: {
                                Label("編輯", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("刪除", systemImage: "trash")
                            }
                            
                            if viewModel.ask?.status == .active {
                                Button {
                                    Task { await viewModel.resolveAsk() }
                                } label: {
                                    Label("標記為已解決", systemImage: "checkmark.circle")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .alert("確定刪除？", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) {}
                Button("刪除", role: .destructive) {
                    Task {
                        await viewModel.deleteAsk()
                        dismiss()
                    }
                }
            } message: {
                Text("確定要刪除此詢問嗎？此動作無法復原。")
            }
            .sheet(isPresented: $showReplySheet) {
                ReplyCreateView(
                    recordId: nil,
                    askId: askId,
                    onReplyCreated: {
                        Task { await viewModel.loadReplies() }
                    }
                )
                .environmentObject(DIContainer())
            }
        }
        .task {
            await viewModel.loadAsk()
        }
    }
    
    // MARK: - Ask Content
    
    @ViewBuilder
    private func askContent(_ ask: Ask) -> some View {
        // 問題
        VStack(alignment: .leading, spacing: 12) {
            Text(ask.question)
                .font(.title3.weight(.medium))
            
            // 範圍資訊
            HStack(spacing: 8) {
                Image(systemName: "scope")
                    .foregroundColor(.orange)
                Text("詢問範圍：\(ask.radiusMeters)m")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if ask.status == .resolved {
                    Label("已解決", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.green)
                }
            }
        }
        
        // 附圖
        if let images = ask.images, !images.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(images) { image in
                        AsyncImage(url: URL(string: image.thumbnailPublicUrl ?? "")) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipped()
                                    .cornerRadius(8)
                            default:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
        
        Divider()
        
        // 作者資訊
        if let author = ask.author {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: author.avatarUrl ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    default:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 40)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(author.displayName)
                        .font(.subheadline.weight(.medium))
                    
                    Text(formatDate(ask.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 愛心按鈕
                LikeButtonLarge(
                    count: ask.likeCount,
                    isLiked: ask.userHasLiked ?? false,
                    action: {
                        Task { await viewModel.toggleLike() }
                    }
                )
            }
        }
        
        Divider()
        
        // 回覆區
        repliesSection
    }
    
    // MARK: - Replies Section
    
    private var repliesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("回覆")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showReplySheet = true
                } label: {
                    Label("新增回覆", systemImage: "plus")
                        .font(.subheadline)
                }
            }
            
            if viewModel.isLoadingReplies {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if viewModel.replies.isEmpty {
                Text("目前沒有回覆")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(viewModel.replies) { reply in
                    ReplyRowView(reply: reply)
                }
            }
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("重試") {
                Task { await viewModel.loadAsk() }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - View Model

@MainActor
class AskDetailViewModel: ObservableObject {
    @Published var ask: Ask?
    @Published var replies: [Reply] = []
    @Published var isLoading = false
    @Published var isLoadingReplies = false
    @Published var errorMessage: String?
    
    let askId: String
    let currentUserId: String?
    
    private let askRepository: AskRepository
    private let replyRepository: ReplyRepository
    
    init(askId: String, askRepository: AskRepository, replyRepository: ReplyRepository) {
        self.askId = askId
        self.askRepository = askRepository
        self.replyRepository = replyRepository
        self.currentUserId = KeychainManager().getAccessToken() // 簡化：實際應從 AuthService 取得
    }
    
    func loadAsk() async {
        isLoading = true
        errorMessage = nil
        
        do {
            ask = try await askRepository.getAskDetail(id: askId)
            isLoading = false
            
            // 載入回覆
            await loadReplies()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func loadReplies() async {
        isLoadingReplies = true
        
        do {
            replies = try await replyRepository.getRepliesForAsk(askId: askId)
        } catch {
            // 靜默處理回覆載入錯誤
        }
        
        isLoadingReplies = false
    }
    
    func toggleLike() async {
        guard var currentAsk = ask else { return }
        
        let wasLiked = currentAsk.userHasLiked ?? false
        
        // 樂觀更新
        currentAsk.userHasLiked = !wasLiked
        ask = currentAsk
        
        do {
            _ = try await replyRepository.toggleLikeForAsk(id: askId)
        } catch {
            // 回滾
            currentAsk.userHasLiked = wasLiked
            ask = currentAsk
        }
    }
    
    func resolveAsk() async {
        do {
            _ = try await askRepository.updateAsk(id: askId, question: nil, status: .resolved, sortedImages: nil)
            await loadAsk()
        } catch {
            errorMessage = "無法更新狀態"
        }
    }
    
    func deleteAsk() async {
        do {
            try await askRepository.deleteAsk(id: askId)
        } catch {
            errorMessage = "刪除失敗"
        }
    }
}

