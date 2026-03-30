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
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var detailSheetRouter: DetailSheetRouter
    @EnvironmentObject var container: DIContainer
    @StateObject private var viewModel: AskDetailViewModel

    @State private var showReportSheet = false
    @State private var showReplyReportSheet = false
    @State private var reportReplyId: String?
    @State private var pendingDeleteReplyId: String?
    @State private var showReplyDeleteConfirmation = false
    @State private var replyActionErrorMessage: String?
    @State private var showMoreOptions = false
    @State private var showDeleteConfirmation = false
    @State private var replyText = ""
    @State private var replySelectedPhotos: [SelectedPhoto] = []
    @State private var showReplyPhotoPicker = false
    @State private var isHeartAnimating = false
    @State private var isDescriptionExpanded = false
    @State private var hasStartedInitialLoad = false
    @State private var keepBackButtonVisibleDuringDismiss = false

    // Fullscreen Image Viewer
    @State private var showFullScreenImage = false
    @State private var fullScreenImages: [ImageMedia] = []
    @State private var fullScreenImageIndex: Int = 0
    @State private var scrolledImageId: String?

    private let askTitleFont = Font.custom("PingFangTC-Medium", size: 24)
    private let askBodyFont = Font.system(size: 16, weight: .regular, design: .rounded)
    private let imageCardWidth: CGFloat = 300
    private let imageCardHeight: CGFloat = 375
    private let moreOptionsMenuWidth: CGFloat = 186
    private let contentTopPaddingWithoutBackButton: CGFloat = 10
    private let contentTopPaddingWithBackButton: CGFloat = 2
    private let showsResolveAction = false

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
        BottomSheetScaffold(
            showsTopBar: shouldShowBackButton,
            topBarBottomPadding: shouldShowBackButton ? 0 : BottomSheetLayoutMetrics.topBarBottomPadding,
            leading: {
                leadingBackButton
            },
            title: {
                EmptyView()
            },
            trailing: {
                EmptyView()
            },
            content: {
                ZStack {
                    if viewModel.isLoading {
                        DetailSheetSkeleton(
                            showImageCarousel: true,
                            contentTopPadding: contentTopPadding
                        )
                    } else if let ask = viewModel.ask {
                        VStack(spacing: 0) {
                            contentView(ask: ask)
                            Divider()
                            DetailReplyInputBar(
                                replyText: $replyText,
                                selectedPhotos: $replySelectedPhotos,
                                isSubmitting: viewModel.isSubmittingReply,
                                currentUserAvatarURL: DetailSheetHelpers.currentUserAvatarURL(from: container.authService),
                                onPhotoPickerTap: { showReplyPhotoPicker = true },
                                onSubmit: { submitReply() }
                            )
                        }
                    } else if let error = viewModel.errorMessage {
                        errorView(error)
                    } else {
                        DetailSheetSkeleton(
                            showImageCarousel: true,
                            contentTopPadding: contentTopPadding
                        )
                    }
                }
            }
        )
        .background(Color.appSurface)
        .overlayPreferenceValue(AskMoreOptionsButtonAnchorPreferenceKey.self) { anchor in
            GeometryReader { proxy in
                if showMoreOptions, let anchor {
                    let buttonFrame = proxy[anchor]
                    DetailMoreOptionsOverlay(
                        buttonFrame: buttonFrame,
                        menuWidth: moreOptionsMenuWidth,
                        onDismiss: { showMoreOptions = false }
                    ) {
                        moreOptionsMenuContent
                    }
                }
            }
        }
        .overlay {
            if showDeleteConfirmation {
                DetailDeleteConfirmation(
                    isPresented: $showDeleteConfirmation,
                    onDelete: {
                        Task {
                            if await viewModel.deleteAsk() {
                                dismiss()
                            }
                        }
                    }
                )
            }

            if showReplyDeleteConfirmation, pendingDeleteReplyId != nil {
                DetailDeleteConfirmation(
                    isPresented: $showReplyDeleteConfirmation,
                    message: "確定要刪除此留言嗎？此動作無法復原",
                    onDelete: {
                        guard let replyId = pendingDeleteReplyId else { return }
                        pendingDeleteReplyId = nil
                        Task {
                            let success = await viewModel.deleteReply(replyId: replyId)
                            if !success {
                                replyActionErrorMessage = viewModel.errorMessage ?? "刪除留言失敗"
                            }
                        }
                    }
                )
            }
        }
        .overlay {
            if showReportSheet {
                DetailReportPopup(
                    isPresented: $showReportSheet,
                    target: .ask(id: askId),
                    apiClient: container.apiClient
                )
            }

            if showReplyReportSheet, let reportReplyId {
                DetailReportPopup(
                    isPresented: $showReplyReportSheet,
                    target: .reply(id: reportReplyId),
                    apiClient: container.apiClient,
                    onDismiss: { self.reportReplyId = nil }
                )
            }
        }
        .sheet(isPresented: $showReplyPhotoPicker) {
            CustomPhotoPickerView(
                photoPickerService: container.photoPickerService,
                requireGPS: false,
                maxSelection: 5,
                initialSelectedPhotos: replySelectedPhotos
            ) { photos in
                replySelectedPhotos = photos
            }
        }
        .alert("操作失敗", isPresented: Binding(
            get: { replyActionErrorMessage != nil },
            set: { if !$0 { replyActionErrorMessage = nil } }
        )) {
            Button("確定") {
                replyActionErrorMessage = nil
            }
        } message: {
            Text(replyActionErrorMessage ?? "")
        }
        .task {
            guard !hasStartedInitialLoad else { return }
            hasStartedInitialLoad = true
            await viewModel.loadAsk()
        }
        .onChange(of: detailSheetRouter.askRefreshVersion(for: askId)) { _, _ in
            Task { await viewModel.loadAsk() }
        }
        .fullScreenImageViewer(
            isPresented: $showFullScreenImage,
            images: fullScreenImages,
            initialIndex: fullScreenImageIndex
        )
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var shouldShowBackButton: Bool {
        if keepBackButtonVisibleDuringDismiss {
            return true
        }

        guard case .ask(let currentRouteAskId) = detailSheetRouter.path.last else {
            return false
        }

        return currentRouteAskId == askId
    }

    private var leadingBackButton: some View {
        Button {
            keepBackButtonVisibleDuringDismiss = true
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }

    private var contentTopPadding: CGFloat {
        shouldShowBackButton ? contentTopPaddingWithBackButton : contentTopPaddingWithoutBackButton
    }

    private var trimmedReplyText: String {
        replyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submitReply() {
        let trimmed = trimmedReplyText
        // allow submit when there's text or photos
        guard (!trimmed.isEmpty || !replySelectedPhotos.isEmpty), !viewModel.isSubmittingReply else { return }
        let photosToSubmit = replySelectedPhotos

        // Immediately clear input so user sees it's submitted
        replyText = ""
        replySelectedPhotos = []

        // Insert optimistic reply immediately and get a tempId
        let tempId = viewModel.insertOptimisticReply(content: trimmed, selectedPhotos: photosToSubmit)

        Task {
            var uploadedImages: [UploadedImage]?

            if !photosToSubmit.isEmpty {
                do {
                    uploadedImages = try await container.uploadService.uploadPhotos(photosToSubmit, context: .reply)
                } catch {
                    // mark optimistic as failed
                    await MainActor.run {
                        if let idx = viewModel.optimisticReplies.firstIndex(where: { $0.id == tempId }) {
                            let item = viewModel.optimisticReplies[idx]
                            viewModel.optimisticReplies[idx] = OptimisticReply(
                                id: tempId,
                                content: item.content,
                                author: item.author,
                                selectedPhotos: item.selectedPhotos,
                                status: .failed(error)
                            )
                        }
                        viewModel.isSubmittingReply = false
                    }
                    return
                }
            }

            // Finish creating reply on server; this will remove optimistic on success or mark failed
            await viewModel.finishCreateReply(tempId: tempId, content: trimmed, images: uploadedImages)
        }
    }

    // MARK: - Content View

    private func contentView(ask: Ask) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    askBodySection(ask: ask)

                    Divider()
                        .padding(.horizontal, 16)

                    DetailRepliesSection(
                        replies: viewModel.replies,
                        optimisticReplies: viewModel.optimisticReplies,
                        isLoadingReplies: viewModel.isLoadingReplies,
                        onAuthorTap: { userId in
                            detailSheetRouter.open(.userProfile(id: userId))
                        },
                        onLikeToggle: { replyId in
                            Task { await viewModel.toggleReplyLike(replyId: replyId) }
                        },
                        onReplyReport: { replyId in
                            guard let reply = viewModel.replies.first(where: { $0.id == replyId }),
                                  canReportReply(reply) else { return }
                            reportReplyId = replyId
                            showReplyReportSheet = true
                        },
                        canReportReply: { reply in canReportReply(reply) },
                        onReplyDelete: { replyId in
                            pendingDeleteReplyId = replyId
                            showReplyDeleteConfirmation = true
                        },
                        canDeleteReply: { reply in
                            reply.userId == viewModel.currentUserId
                        },
                        onRetry: { tempId in
                            Task { await viewModel.retryOptimisticReply(id: tempId) }
                        },
                        onRemoveFailed: { tempId in
                            viewModel.removeOptimisticReply(id: tempId)
                        },
                        onImageTapForFullScreen: { images, index in
                            fullScreenImages = images
                            fullScreenImageIndex = index
                            showFullScreenImage = true
                        }
                    )
                    .id("replies-top")
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .padding(.top, contentTopPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: viewModel.optimisticReplies.count) { _, newCount in
                if newCount > 0 {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("replies-top", anchor: .top)
                    }
                }
            }
        }
    }

    private func askBodySection(ask: Ask) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. 用戶資訊列
            if let author = ask.author {
                DetailAuthorHeaderView(
                    author: author,
                    createdAt: ask.createdAt,
                    anchorKey: AskMoreOptionsButtonAnchorPreferenceKey.self,
                    onBackTap: { dismiss() },
                    onAvatarTap: { detailSheetRouter.open(.userProfile(id: author.id)) },
                    showMoreOptions: $showMoreOptions
                )
            }

            // 2. 圖片輪播
            if let images = ask.images, !images.isEmpty {
                DetailImageCarouselView(
                    images: images,
                    initialImageIndex: 0,
                    cardWidth: imageCardWidth,
                    cardHeight: imageCardHeight,
                    scrolledImageId: $scrolledImageId,
                    onImageTap: { imgs, index in
                        fullScreenImages = imgs
                        fullScreenImageIndex = index
                        showFullScreenImage = true
                    }
                )

                // 圖片 metadata
                DetailImageMetaRowView(
                    image: currentVisibleImage(in: images),
                    scrolledImageId: scrolledImageId,
                    onLocationTap: { image in
                        if let coordinate = image.clLocationCoordinate {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                navigationCoordinator.navigateToMap(coordinate: coordinate, mapMode: .ask)
                            }
                        }
                    }
                )
                .padding(.top, 14)
            }

            let hasImages = !(ask.images?.isEmpty ?? true)
            VStack(alignment: .leading, spacing: 14) {
                // 3. 標題
                if let title = ask.title, !title.isEmpty {
                    Text(title)
                        .font(askTitleFont)
                        .foregroundColor(.primary)
                }

                // 4. 內容描述
                DetailDescriptionSection(
                    description: ask.question,
                    isExpanded: $isDescriptionExpanded,
                    font: askBodyFont
                )

                if ask.status == .resolved {
                    Label("已解決", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.appSuccess)
                }

                DetailInteractionRow(
                    isLiked: viewModel.ask?.userHasLiked ?? false,
                    likeCount: viewModel.ask?.likeCount ?? 0,
                    replyCount: viewModel.replies.count,
                    onLikeTap: { Task { await viewModel.toggleLike() } },
                    isHeartAnimating: $isHeartAnimating
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, hasImages ? 12 : 4)
            .padding(.bottom, 10)
        }
    }

    private func currentVisibleImage(in images: [ImageMedia]) -> ImageMedia {
        if let scrolledId = scrolledImageId,
           let image = images.first(where: { $0.id == scrolledId }) {
            return image
        }
        return images.first!
    }

    // MARK: - More Options Menu Content

    @ViewBuilder
    private var moreOptionsMenuContent: some View {
        if viewModel.isOwner {
            DetailOptionRow(title: "編輯", systemImage: "pencil") {
                showMoreOptions = false
                if let ask = viewModel.ask {
                    detailSheetRouter.openAskEdit(id: askId, prefetchedAsk: ask)
                } else {
                    detailSheetRouter.open(.askEdit(id: askId))
                }
            }

            if showsResolveAction, viewModel.ask?.status == .active {
                DetailOptionDivider()
                DetailOptionRow(title: "標記為已解決", systemImage: "checkmark.circle") {
                    showMoreOptions = false
                    Task { await viewModel.resolveAsk() }
                }
            }

            DetailOptionDivider()
            DetailOptionRow(title: "刪除", systemImage: "trash", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.12)) {
                    showMoreOptions = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                        showDeleteConfirmation = true
                    }
                }
            }
        } else if canReportCurrentAsk {
            DetailOptionRow(title: "檢舉", systemImage: "flag", role: .destructive) {
                showMoreOptions = false
                showReportSheet = true
            }
        }
    }

    private var canReportCurrentAsk: Bool {
        guard let ask = viewModel.ask,
              let currentUserId = viewModel.currentUserId else { return false }
        return ask.userId != currentUserId
    }

    private func canReportReply(_ reply: Reply) -> Bool {
        guard let currentUserId = viewModel.currentUserId else { return false }
        return reply.userId != currentUserId
    }

    // MARK: - Supporting Views

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.brandOrange)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("重試") {
                Task { await viewModel.loadAsk() }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - View Model

@MainActor
class AskDetailViewModel: ObservableObject {
    @Published var ask: Ask?
    @Published var replies: [Reply] = []
    @Published var optimisticReplies: [OptimisticReply] = []
    @Published var isLoading = true
    @Published var isLoadingReplies = false
    @Published var isSubmittingReply = false
    @Published var errorMessage: String?

    let askId: String

    var currentUserId: String? {
        AuthService.shared.currentUserId
    }

    var isOwner: Bool {
        guard let ask else { return false }
        guard let currentUserId else { return false }
        return ask.userId == currentUserId
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
            async let loadedAsk = askRepository.getAskDetail(id: askId)
            async let loadedReplies = replyRepository.getRepliesForAsk(askId: askId)

            let (fetchedAsk, fetchedReplies) = try await (loadedAsk, loadedReplies)

            ask = fetchedAsk
            replies = fetchedReplies.reversed()   // 最新在前
            isLoading = false
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

    func createReply(content: String, images: [UploadedImage]? = nil, selectedPhotos: [SelectedPhoto] = []) async -> Bool {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return false }

        let tempId = UUID().uuidString
        let currentUser = AuthService.shared.currentUser
        let optimistic = OptimisticReply(
            id: tempId,
            content: trimmedContent,
            author: currentUser,
            selectedPhotos: selectedPhotos,
            status: .pending
        )

        optimisticReplies.insert(optimistic, at: 0)
        isSubmittingReply = true
        errorMessage = nil

        do {
            let reply = try await replyRepository.createReplyForAsk(
                askId: askId,
                content: trimmedContent,
                images: images,
                currentLocation: nil
            )
            optimisticReplies.removeAll { $0.id == tempId }
            replies.insert(reply, at: 0)
            isSubmittingReply = false
            return true
        } catch {
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
            return false
        }
    }

    func retryOptimisticReply(id: String, images: [UploadedImage]? = nil) async {
        guard let item = optimisticReplies.first(where: { $0.id == id }) else { return }

        if let idx = optimisticReplies.firstIndex(where: { $0.id == id }) {
            optimisticReplies[idx] = OptimisticReply(
                id: id, content: item.content,
                author: item.author, selectedPhotos: item.selectedPhotos,
                status: .pending
            )
        }

        do {
            let reply = try await replyRepository.createReplyForAsk(
                askId: askId, content: item.content,
                images: images, currentLocation: nil
            )
            optimisticReplies.removeAll { $0.id == id }
            replies.insert(reply, at: 0)
        } catch {
            if let idx = optimisticReplies.firstIndex(where: { $0.id == id }) {
                optimisticReplies[idx] = OptimisticReply(
                    id: id, content: item.content,
                    author: item.author, selectedPhotos: item.selectedPhotos,
                    status: .failed(error)
                )
            }
        }
    }

    func removeOptimisticReply(id: String) {
        optimisticReplies.removeAll { $0.id == id }
    }

    /// 立即插入 optimistic reply，回傳 tempId
    func insertOptimisticReply(content: String, selectedPhotos: [SelectedPhoto]) -> String {
        let tempId = UUID().uuidString
        let optimistic = OptimisticReply(
            id: tempId,
            content: content,
            author: AuthService.shared.currentUser,
            selectedPhotos: selectedPhotos,
            status: .pending
        )
        // @MainActor class — assign directly, no dispatch needed
        optimisticReplies.insert(optimistic, at: 0)
        isSubmittingReply = true
        return tempId
    }

    /// 完成 server 建立，替換或標記失敗
    func finishCreateReply(tempId: String, content: String, images: [UploadedImage]?) async {
        do {
            let reply = try await replyRepository.createReplyForAsk(
                askId: askId,
                content: content,
                images: images,
                currentLocation: nil
            )
            optimisticReplies.removeAll { $0.id == tempId }
            replies.insert(reply, at: 0)
            isSubmittingReply = false
        } catch {
            if let idx = optimisticReplies.firstIndex(where: { $0.id == tempId }) {
                let item = optimisticReplies[idx]
                optimisticReplies[idx] = OptimisticReply(
                    id: tempId,
                    content: item.content,
                    author: item.author,
                    selectedPhotos: item.selectedPhotos,
                    status: .failed(error)
                )
            }
            isSubmittingReply = false
        }
    }

    func toggleLike() async {
        guard var currentAsk = ask else { return }

        let wasLiked = currentAsk.userHasLiked ?? false
        let previousLikeCount = currentAsk.likeCount

        currentAsk.userHasLiked = !wasLiked
        currentAsk = Ask(
            id: currentAsk.id,
            userId: currentAsk.userId,
            center: currentAsk.center,
            radiusMeters: currentAsk.radiusMeters,
            title: currentAsk.title,
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
            if var updatedAsk = ask {
                updatedAsk = Ask(
                    id: updatedAsk.id,
                    userId: updatedAsk.userId,
                    center: updatedAsk.center,
                    radiusMeters: updatedAsk.radiusMeters,
                    title: updatedAsk.title,
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
            ask = Ask(
                id: currentAsk.id,
                userId: currentAsk.userId,
                center: currentAsk.center,
                radiusMeters: currentAsk.radiusMeters,
                title: currentAsk.title,
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
                id: askId,
                question: nil,
                status: .resolved,
                sortedImages: nil
            )
            await loadAsk()
        } catch {
            errorMessage = "無法更新狀態"
        }
    }

    func deleteAsk() async -> Bool {
        do {
            try await askRepository.deleteAsk(id: askId)
            return true
        } catch {
            errorMessage = "刪除失敗"
            return false
        }
    }

    func toggleReplyLike(replyId: String) async {
        guard let index = replies.firstIndex(where: { $0.id == replyId }) else { return }

        let wasLiked = replies[index].userHasLiked ?? false
        let previousCount = replies[index].likeCount

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

    func deleteReply(replyId: String) async -> Bool {
        do {
            try await replyRepository.deleteReply(id: replyId)
            replies.removeAll { $0.id == replyId }
            return true
        } catch {
            errorMessage = "刪除留言失敗: \(error.localizedDescription)"
            return false
        }
    }
}

struct AskMoreOptionsButtonAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}
