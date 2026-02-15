//
//  AskDetailSheetView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Combine
import Kingfisher
import MapKit
import SwiftUI

/// 詢問詳情 Sheet
struct AskDetailSheetView: View {
    let askId: String
    let askRepository: AskRepository
    let replyRepository: ReplyRepository

    @Environment(\.dismiss) private var dismiss
    @Environment(\.globalDetailSheetContentTopSpacing) private var globalDetailSheetContentTopSpacing
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var detailSheetRouter: DetailSheetRouter
    @EnvironmentObject var container: DIContainer
    @StateObject private var viewModel: AskDetailViewModel

    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    @State private var showReplySheet = false
    @State private var showReportSheet = false

    init(askId: String, askRepository: AskRepository, replyRepository: ReplyRepository) {
        self.askId = askId
        self.askRepository = askRepository
        self.replyRepository = replyRepository
        _viewModel = StateObject(
            wrappedValue: AskDetailViewModel(
                askId: askId,
                askRepository: askRepository,
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
                .padding(.bottom, 4 + globalDetailSheetContentTopSpacing)

            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if viewModel.isLoading {
                            AskDetailSkeleton()
                        } else if let ask = viewModel.ask {
                            askContent(ask)
                        } else if let error = viewModel.errorMessage {
                            errorView(error)
                        } else {
                            // Fallback: 確保不會有空白狀態
                            AskDetailSkeleton()
                        }
                    }
                    .padding()
                }
                .navigationTitle("詢問詳情")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            // 作者可編輯/刪除/標記已解決
                            if viewModel.ask?.userId == viewModel.currentUserId {
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
                            } else {
                                // 非作者可檢舉
                                Button(role: .destructive) {
                                    showReportSheet = true
                                } label: {
                                    Label("檢舉", systemImage: "flag")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
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
                .sheet(isPresented: $showReportSheet) {
                    ReportSheetView(
                        target: .ask(id: askId),
                        apiClient: container.apiClient
                    )
                }
            }
            .task {
                await viewModel.loadAsk()
            }
        }  // VStack
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

                // 在地圖上查看按鈕
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        navigationCoordinator.navigateToMap(
                            coordinate: ask.center.clLocationCoordinate, mapMode: .ask)
                    }
                } label: {
                    Label("在地圖上查看", systemImage: "map")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.orange)
                }

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
                        KFImage(URL(string: image.thumbnailPublicUrl ?? ""))
                            .placeholder {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(8)
                            }
                            .retry(maxCount: 2, interval: .seconds(1))
                            .cacheOriginalImage()
                            .fade(duration: 0.2)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipped()
                            .cornerRadius(8)
                    }
                }
            }
        }

        Divider()

        // 作者資訊
        if let author = ask.author {
            Button {
                detailSheetRouter.open(.userProfile(id: author.id))
            } label: {
                HStack(spacing: 12) {
                    KFImage(URL(string: author.avatarUrl ?? ""))
                        .placeholder {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 40, height: 40)
                        }
                        .retry(maxCount: 2, interval: .seconds(1))
                        .cacheOriginalImage()
                        .fade(duration: 0.2)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(author.displayName)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)

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
            .buttonStyle(PlainButtonStyle())
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
                ForEach(0..<2, id: \.self) { _ in
                    ReplyRowSkeleton()
                }
            } else if viewModel.replies.isEmpty {
                Text("目前沒有回覆")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(viewModel.replies) { reply in
                    ReplyRowView(reply: reply) { replyId in
                        Task { await viewModel.toggleReplyLike(replyId: replyId) }
                    }
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
    @Published var isLoading = true
    @Published var isLoadingReplies = false
    @Published var errorMessage: String?

    let askId: String
    
    /// 當前使用者 ID（從 AuthService 取得）
    var currentUserId: String? {
        return AuthService.shared.currentUserId
    }

    private let askRepository: AskRepository
    private let replyRepository: ReplyRepository

    init(askId: String, askRepository: AskRepository, replyRepository: ReplyRepository) {
        self.askId = askId
        self.askRepository = askRepository
        self.replyRepository = replyRepository
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
        let previousLikeCount = currentAsk.likeCount

        // 樂觀更新
        currentAsk.userHasLiked = !wasLiked
        currentAsk = Ask(
            id: currentAsk.id,
            userId: currentAsk.userId,
            center: currentAsk.center,
            radiusMeters: currentAsk.radiusMeters,
            question: currentAsk.question,
            mainImageUrl: currentAsk.mainImageUrl,
            status: currentAsk.status,
            likeCount: wasLiked ? previousLikeCount - 1 : previousLikeCount + 1,
            viewCount: currentAsk.viewCount,
            createdAt: currentAsk.createdAt,
            updatedAt: currentAsk.updatedAt,
            author: currentAsk.author,
            images: currentAsk.images,
            userHasLiked: !wasLiked
        )
        ask = currentAsk

        do {
            let response = try await replyRepository.toggleLikeForAsk(id: askId)
            // 用伺服器回傳的計數更新
            if var updatedAsk = ask {
                updatedAsk = Ask(
                    id: updatedAsk.id,
                    userId: updatedAsk.userId,
                    center: updatedAsk.center,
                    radiusMeters: updatedAsk.radiusMeters,
                    question: updatedAsk.question,
                    mainImageUrl: updatedAsk.mainImageUrl,
                    status: updatedAsk.status,
                    likeCount: response.likeCount,
                    viewCount: updatedAsk.viewCount,
                    createdAt: updatedAsk.createdAt,
                    updatedAt: updatedAsk.updatedAt,
                    author: updatedAsk.author,
                    images: updatedAsk.images,
                    userHasLiked: response.action == "liked"
                )
                ask = updatedAsk
            }
        } catch {
            // 回滾
            ask = Ask(
                id: currentAsk.id,
                userId: currentAsk.userId,
                center: currentAsk.center,
                radiusMeters: currentAsk.radiusMeters,
                question: currentAsk.question,
                mainImageUrl: currentAsk.mainImageUrl,
                status: currentAsk.status,
                likeCount: previousLikeCount,
                viewCount: currentAsk.viewCount,
                createdAt: currentAsk.createdAt,
                updatedAt: currentAsk.updatedAt,
                author: currentAsk.author,
                images: currentAsk.images,
                userHasLiked: wasLiked
            )
        }
    }

    func resolveAsk() async {
        do {
            _ = try await askRepository.updateAsk(
                id: askId, question: nil, status: .resolved, sortedImages: nil)
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

    func toggleReplyLike(replyId: String) async {
        guard let index = replies.firstIndex(where: { $0.id == replyId }) else { return }

        let wasLiked = replies[index].userHasLiked ?? false
        let previousCount = replies[index].likeCount

        // 樂觀更新
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

        do {
            let response = try await replyRepository.toggleLikeForReply(id: replyId)
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
        } catch {
            // 回滾
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
