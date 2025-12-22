//
//  RecordDetailSheetView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI

/// 紀錄詳情 Sheet 視圖
struct RecordDetailSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: RecordDetailViewModel
    @State private var showReplyInput = false
    @State private var showMoreOptions = false
    
    init(
        recordId: String,
        initialImageIndex: Int = 0,
        recordRepository: RecordRepository,
        replyRepository: ReplyRepository
    ) {
        _viewModel = StateObject(wrappedValue: RecordDetailViewModel(
            recordId: recordId,
            initialImageIndex: initialImageIndex,
            recordRepository: recordRepository,
            replyRepository: replyRepository
        ))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    loadingView
                } else if let record = viewModel.record {
                    contentView(record: record)
                } else if let error = viewModel.errorMessage {
                    errorView(message: error)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    moreOptionsButton
                }
            }
        }
        .task {
            await viewModel.loadRecord()
        }
        .confirmationDialog("管理", isPresented: $showMoreOptions) {
            Button("編輯", role: nil) {
                // 導航至編輯頁
            }
            Button("刪除", role: .destructive) {
                viewModel.showDeleteConfirmation = true
            }
            Button("取消", role: .cancel) {}
        }
        .alert("確認刪除", isPresented: $viewModel.showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("刪除", role: .destructive) {
                Task {
                    if await viewModel.deleteRecord() {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("確定要刪除此標點嗎？此動作無法復原。")
        }
    }
    
    // MARK: - Content View
    
    private func contentView(record: Record) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 圖片輪播
                if let images = record.images, !images.isEmpty {
                    ImageCarouselView(
                        images: images,
                        initialIndex: viewModel.initialImageIndex
                    )
                    .frame(height: 280)
                }
                
                // 內容區
                VStack(alignment: .leading, spacing: 16) {
                    // 描述
                    Text(record.description)
                        .font(.body)
                    
                    // 時間
                    Text(formatDate(record.createdAt))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // 作者資訊 & 愛心
                    HStack {
                        if let author = record.author {
                            authorView(author: author)
                        }
                        
                        Spacer()
                        
                        LikeButtonLarge(
                            count: viewModel.likeCount,
                            isLiked: viewModel.isLiked
                        ) {
                            Task {
                                await viewModel.toggleLike()
                            }
                        }
                    }
                    
                    Divider()
                    
                    // 回覆區
                    repliesSection
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Author View
    
    private func authorView(author: User) -> some View {
        HStack(spacing: 10) {
            AsyncImage(url: URL(string: author.avatarUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Circle()
                        .fill(Color(.systemGray4))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.secondary)
                        )
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            
            Text(author.displayName)
                .font(.subheadline.weight(.medium))
        }
    }
    
    // MARK: - Replies Section
    
    private var repliesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("回覆")
                    .font(.headline)
                
                Text("(\(viewModel.replies.count))")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            if viewModel.replies.isEmpty {
                Text("還沒有回覆")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                ForEach(viewModel.replies) { reply in
                    ReplyRowView(reply: reply)
                    
                    if reply.id != viewModel.replies.last?.id {
                        Divider()
                    }
                }
            }
            
            // 新增回覆按鈕
            Button {
                showReplyInput = true
            } label: {
                HStack {
                    Image(systemName: "plus.bubble")
                    Text("新增回覆")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - Supporting Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("載入中...")
                .foregroundColor(.secondary)
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text(message)
                .foregroundColor(.secondary)
            
            Button("重試") {
                Task {
                    await viewModel.loadRecord()
                }
            }
        }
    }
    
    private var moreOptionsButton: some View {
        Button {
            showMoreOptions = true
        } label: {
            Image(systemName: "ellipsis")
                .font(.title3)
        }
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Reply Row View

struct ReplyRowView: View {
    let reply: Reply
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 作者 & 時間
            HStack {
                if let author = reply.author {
                    HStack(spacing: 8) {
                        AsyncImage(url: URL(string: author.avatarUrl ?? "")) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                Circle().fill(Color(.systemGray4))
                            }
                        }
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                        
                        Text(author.displayName)
                            .font(.subheadline.weight(.medium))
                    }
                }
                
                Spacer()
                
                Text(formatTimeAgo(reply.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 內容
            Text(reply.content)
                .font(.body)
            
            // 圖片
            if let images = reply.images, !images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(images) { image in
                            AsyncImage(url: URL(string: image.thumbnailPublicUrl)) { phase in
                                switch phase {
                                case .success(let loadedImage):
                                    loadedImage
                                        .resizable()
                                        .scaledToFill()
                                default:
                                    Rectangle().fill(Color(.systemGray5))
                                }
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }
            
            // 愛心
            HStack {
                Spacer()
                LikeButton(
                    count: reply.likeCount,
                    isLiked: reply.userHasLiked ?? false
                ) {
                    // Toggle like
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let now = Date()
        let diff = now.timeIntervalSince(date)
        
        if diff < 60 {
            return "剛剛"
        } else if diff < 3600 {
            return "\(Int(diff / 60)) 分鐘前"
        } else if diff < 86400 {
            return "\(Int(diff / 3600)) 小時前"
        } else {
            return "\(Int(diff / 86400)) 天前"
        }
    }
}

#Preview {
    RecordDetailSheetView(
        recordId: "preview-id",
        initialImageIndex: 0,
        recordRepository: RecordRepository(apiClient: APIClient(baseURL: "", authService: AuthService())),
        replyRepository: ReplyRepository(apiClient: APIClient(baseURL: "", authService: AuthService()))
    )
}
