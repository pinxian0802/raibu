//
//  RecordDetailSheetView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI
import MapKit
import Kingfisher

/// 紀錄詳情 Sheet 視圖
struct RecordDetailSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var detailSheetRouter: DetailSheetRouter
    @EnvironmentObject var container: DIContainer
    @StateObject private var viewModel: RecordDetailViewModel
    @State private var showReplyInput = false
    @State private var showMoreOptions = false
    @State private var showEditSheet = false
    @State private var showReportSheet = false
    
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
        VStack(spacing: 0) {
            // 拖曳指示條
            Capsule()
                .fill(Color(.systemGray3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 4)
            
            NavigationView {
                ZStack {
                    if viewModel.isLoading {
                    loadingView
                } else if let record = viewModel.record {
                    contentView(record: record)
                } else if let error = viewModel.errorMessage {
                    errorView(message: error)
                } else {
                    // Fallback: 確保不會有空白狀態
                    loadingView
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
            // 只有作者才能編輯/刪除
            if viewModel.isOwner {
                Button("編輯", role: nil) {
                    showEditSheet = true
                }
                Button("刪除", role: .destructive) {
                    viewModel.showDeleteConfirmation = true
                }
            }
            // 非作者才能檢舉
            if !viewModel.isOwner {
                Button("檢舉", role: .destructive) {
                    showReportSheet = true
                }
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showEditSheet) {
            if let record = viewModel.record {
                EditRecordView(
                    recordId: viewModel.recordId,
                    record: record,
                    uploadService: container.uploadService,
                    recordRepository: container.recordRepository,
                    onComplete: {
                        Task {
                            await viewModel.loadRecord()
                        }
                    }
                )
            }
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
        .sheet(isPresented: $showReportSheet) {
            ReportSheetView(
                target: .record(id: viewModel.recordId),
                apiClient: container.apiClient
            )
        }
        } // VStack
    }
    
    // MARK: - Content View
    
    private func contentView(record: Record) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 圖片輪播
                if let images = record.images, !images.isEmpty {
                    ImageCarouselView(
                        images: images,
                        initialIndex: viewModel.initialImageIndex,
                        onLocationTap: { image in
                            // 點擊「查看位置」按鈕跳轉到地圖位置
                            if let coordinate = image.clLocationCoordinate {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    // 跳轉到地圖並切換到紀錄模式
                                    navigationCoordinator.navigateToMap(coordinate: coordinate, mapMode: .record)
                                }
                            }
                        }
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
        Button {
            detailSheetRouter.open(.userProfile(id: author.id))
        } label: {
            HStack(spacing: 10) {
                KFImage(URL(string: author.avatarUrl ?? ""))
                    .placeholder {
                        Circle()
                            .fill(Color(.systemGray4))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.secondary)
                            )
                    }
                    .retry(maxCount: 2, interval: .seconds(1))
                    .cacheOriginalImage()
                    .fade(duration: 0.2)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                
                Text(author.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
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
                    ReplyRowView(reply: reply) { replyId in
                        Task { await viewModel.toggleReplyLike(replyId: replyId) }
                    }
                    
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
        RecordDetailSkeleton()
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
    var onLikeToggle: ((String) -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 作者 & 時間
            HStack {
                if let author = reply.author {
                    HStack(spacing: 8) {
                        KFImage(URL(string: author.avatarUrl ?? ""))
                            .placeholder {
                                Circle().fill(Color(.systemGray4))
                            }
                            .retry(maxCount: 2, interval: .seconds(1))
                            .cacheOriginalImage()
                            .fade(duration: 0.2)
                            .resizable()
                            .scaledToFill()
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
                            KFImage(URL(string: image.thumbnailPublicUrl))
                                .placeholder {
                                    Rectangle().fill(Color(.systemGray5))
                                }
                                .retry(maxCount: 2, interval: .seconds(1))
                                .cacheOriginalImage()
                                .fade(duration: 0.2)
                                .resizable()
                                .scaledToFill()
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
                    onLikeToggle?(reply.id)
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
    .environmentObject(DetailSheetRouter())
}
