//
//  ClusterGridSheetView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI
import Kingfisher

/// 群集 Sheet 視圖 - 使用 NavigationStack 管理內部導航
struct ClusterGridSheetView: View {
    let items: [ClusterItem]
    let recordRepository: RecordRepository
    let askRepository: AskRepository
    let replyRepository: ReplyRepository
    
    @State private var navigationPath = NavigationPath()
    
    // 3 columns grid
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    /// 過濾並排序紀錄圖片（最新的在前面）
    private var recordImageItems: [ClusterItem] {
        items.filter { item in
            if case .recordImage = item { return true }
            return false
        }.sorted { item1, item2 in
            guard case .recordImage(let img1) = item1,
                  case .recordImage(let img2) = item2 else { return false }
            
            if let date1 = img1.createdAt, let date2 = img2.createdAt {
                return date1 > date2
            }
            if img1.createdAt != nil { return true }
            if img2.createdAt != nil { return false }
            return img1.id > img2.id
        }
    }
    
    /// 過濾詢問標點
    private var askItems: [ClusterItem] {
        items.filter { item in
            if case .ask = item { return true }
            return false
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            gridContent
                .navigationTitle("標點列表")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: ClusterDetailDestination.self) { destination in
                    detailView(for: destination)
                }
        }
    }
    
    // MARK: - Grid Content
    
    private var gridContent: some View {
        GeometryReader { geometry in
            let itemSize = (geometry.size.width - 4) / 3 // 3 columns with 2pt spacing
            
            ScrollView {
                VStack(spacing: 16) {
                    // 如果有圖片，顯示九宮格
                    if !recordImageItems.isEmpty {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(recordImageItems) { item in
                                Button {
                                    if case .recordImage(let image) = item {
                                        navigationPath.append(
                                            ClusterDetailDestination.record(
                                                id: image.recordId,
                                                imageIndex: image.displayOrder
                                            )
                                        )
                                    }
                                } label: {
                                    gridImageView(item, size: itemSize)
                                }
                            }
                        }
                    }
                    
                    // 如果有詢問標點，顯示列表
                    if !askItems.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(askItems) { item in
                                Button {
                                    if case .ask(let ask) = item {
                                        navigationPath.append(
                                            ClusterDetailDestination.ask(id: ask.id)
                                        )
                                    }
                                } label: {
                                    askRowView(item)
                                }
                                
                                if item.id != askItems.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 如果完全沒有資料，顯示提示
                    if recordImageItems.isEmpty && askItems.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("沒有可顯示的標點")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }
                }
            }
        }
    }
    
    // MARK: - Detail View
    
    @ViewBuilder
    private func detailView(for destination: ClusterDetailDestination) -> some View {
        switch destination {
        case .record(let id, let imageIndex):
            RecordDetailContentView(
                recordId: id,
                initialImageIndex: imageIndex,
                recordRepository: recordRepository,
                replyRepository: replyRepository
            )
        case .ask(let id):
            AskDetailSheetView(
                askId: id,
                askRepository: askRepository,
                replyRepository: replyRepository
            )
        }
    }
    
    // MARK: - Grid Image View
    
    @ViewBuilder
    private func gridImageView(_ item: ClusterItem, size: CGFloat) -> some View {
        if case .recordImage(let image) = item {
            KFImage(URL(string: image.thumbnailPublicUrl))
                .placeholder {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .shimmer()
                }
                .retry(maxCount: 2, interval: .seconds(1))
                .cacheOriginalImage()
                .fade(duration: 0.2)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipped()
        }
    }
    
    // MARK: - Ask Row View
    
    @ViewBuilder
    private func askRowView(_ item: ClusterItem) -> some View {
        if case .ask(let ask) = item {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "questionmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("詢問標點")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    Text(ask.question)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Navigation Destination

enum ClusterDetailDestination: Hashable {
    case record(id: String, imageIndex: Int)
    case ask(id: String)
}

// MARK: - Record Detail Content View (嵌入式版本，用於 NavigationStack)

struct RecordDetailContentView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var container: DIContainer
    @StateObject private var viewModel: RecordDetailViewModel
    @State private var showReplyInput = false
    @State private var showMoreOptions = false
    @State private var showEditSheet = false
    
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
        ZStack {
            if viewModel.isLoading {
                loadingView
            } else if let record = viewModel.record {
                contentView(record: record)
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else {
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
        .task {
            await viewModel.loadRecord()
        }
        .confirmationDialog("管理", isPresented: $showMoreOptions) {
            Button("編輯", role: nil) {
                showEditSheet = true
            }
            Button("刪除", role: .destructive) {
                viewModel.showDeleteConfirmation = true
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
                    await viewModel.deleteRecord()
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
                        initialIndex: viewModel.initialImageIndex,
                        onLocationTap: { image in
                            // 點擊「查看位置」按鈕跳轉到地圖位置
                            if let coordinate = image.clLocationCoordinate {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
        NavigationLink {
            OtherUserProfileContentView(
                userId: author.id,
                userRepository: container.userRepository
            )
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
