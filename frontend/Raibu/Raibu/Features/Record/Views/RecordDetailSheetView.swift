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
    @State private var showMoreOptions = false
    @State private var showReportSheet = false
    @State private var replyText = ""
    @State private var isDescriptionExpanded = false
    @State private var isHeartAnimating = false
    @State private var hasStartedInitialLoad = false
    @State private var keepBackButtonVisibleDuringDismiss = false

    private let onOpenUserProfile: ((String) -> Void)?
    private let onOpenRecordEdit: ((String, Record?, @escaping () -> Void) -> Void)?
    private let showsBackButtonOverride: Bool?
    
    // Fullscreen Image Viewer
    @State private var showFullScreenImage = false
    @State private var fullScreenImages: [ImageMedia] = []
    @State private var fullScreenImageIndex: Int = 0
    @State private var scrolledImageId: String?
    
    private let descriptionFont = Font.system(size: 16, weight: .regular, design: .rounded)
    private let imageCardWidth: CGFloat = 300
    private let imageCardHeight: CGFloat = 375
    private let moreOptionsMenuWidth: CGFloat = 186
    private let contentTopPaddingWithoutBackButton: CGFloat = 10
    private let contentTopPaddingWithBackButton: CGFloat = 2
    
    init(
        recordId: String,
        initialImageIndex: Int = 0,
        recordRepository: RecordRepository,
        replyRepository: ReplyRepository,
        onOpenUserProfile: ((String) -> Void)? = nil,
        onOpenRecordEdit: ((String, Record?, @escaping () -> Void) -> Void)? = nil,
        showsBackButtonOverride: Bool? = nil
    ) {
        self.onOpenUserProfile = onOpenUserProfile
        self.onOpenRecordEdit = onOpenRecordEdit
        self.showsBackButtonOverride = showsBackButtonOverride
        _viewModel = StateObject(wrappedValue: RecordDetailViewModel(
            recordId: recordId,
            initialImageIndex: initialImageIndex,
            recordRepository: recordRepository,
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
                        loadingView
                    } else if let record = viewModel.record {
                        VStack(spacing: 0) {
                            contentView(record: record)
                            Divider()
                            DetailReplyInputBar(
                                replyText: $replyText,
                                isSubmitting: viewModel.isSubmittingReply,
                                currentUserAvatarURL: DetailSheetHelpers.currentUserAvatarURL(from: container.authService),
                                onSubmit: { submitReply() }
                            )
                        }
                    } else if let error = viewModel.errorMessage {
                        errorView(message: error)
                    } else {
                        loadingView
                    }
                }
            }
        )
        .background(Color.appSurface)
        .overlayPreferenceValue(MoreOptionsButtonAnchorPreferenceKey.self) { anchor in
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
            if viewModel.showDeleteConfirmation {
                DetailDeleteConfirmation(
                    isPresented: $viewModel.showDeleteConfirmation,
                    onDelete: {
                        Task {
                            if await viewModel.deleteRecord() {
                                dismiss()
                            }
                        }
                    }
                )
            }
        }
        .fullScreenImageViewer(
            isPresented: $showFullScreenImage,
            images: fullScreenImages,
            initialIndex: fullScreenImageIndex
        )
        .task {
            guard !hasStartedInitialLoad else { return }
            hasStartedInitialLoad = true
            viewModel.loadRecord()
        }
        .sheet(isPresented: $showReportSheet) {
            ReportSheetView(
                target: .record(id: viewModel.recordId),
                apiClient: container.apiClient
            )
        }
        .onChange(of: viewModel.record?.id) { _, _ in
            isDescriptionExpanded = false
        }
        .onChange(of: detailSheetRouter.recordRefreshVersion(for: viewModel.recordId)) { _, _ in
            viewModel.loadRecord()
        }
        .onDisappear {
            viewModel.cancelAllTasks()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var shouldShowBackButton: Bool {
        if let showsBackButtonOverride {
            return showsBackButtonOverride
        }
        if keepBackButtonVisibleDuringDismiss {
            return true
        }
        guard case .record(let currentRouteRecordId, _) = detailSheetRouter.path.last else {
            return false
        }
        return currentRouteRecordId == viewModel.recordId
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
    
    // MARK: - Content View
    
    private func contentView(record: Record) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                recordBodySection(record: record)
                
                Divider()
                    .padding(.horizontal, 16)
                
                DetailRepliesSection(
                    replies: viewModel.replies,
                    isLoadingReplies: false,
                    onAuthorTap: { userId in
                        if let onOpenUserProfile {
                            onOpenUserProfile(userId)
                        } else {
                            detailSheetRouter.open(.userProfile(id: userId))
                        }
                    },
                    onLikeToggle: { replyId in
                        Task { await viewModel.toggleReplyLike(replyId: replyId) }
                    },
                    onImageTapForFullScreen: { images, index in
                        fullScreenImages = images
                        fullScreenImageIndex = index
                        showFullScreenImage = true
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .padding(.top, contentTopPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func recordBodySection(record: Record) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. 用戶資訊列
            if let author = record.author {
                DetailAuthorHeaderView(
                    author: author,
                    createdAt: record.createdAt,
                    anchorKey: MoreOptionsButtonAnchorPreferenceKey.self,
                    onBackTap: { dismiss() },
                    onAvatarTap: {
                        if let onOpenUserProfile {
                            onOpenUserProfile(author.id)
                        } else {
                            detailSheetRouter.open(.userProfile(id: author.id))
                        }
                    },
                    showMoreOptions: $showMoreOptions
                )
            }

            // 2. 圖片輪播
            if let images = record.images, !images.isEmpty {
                DetailImageCarouselView(
                    images: images,
                    initialImageIndex: viewModel.initialImageIndex,
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
                                navigationCoordinator.navigateToMap(coordinate: coordinate, mapMode: .record)
                            }
                        }
                    }
                )
                .padding(.top, 14)
            }

            let hasImages = !(record.images?.isEmpty ?? true)
            VStack(alignment: .leading, spacing: 14) {
                // 3. 內容描述（有圖片才顯示分隔線）
                if hasImages { Divider() }
                DetailDescriptionSection(
                    description: record.description,
                    isExpanded: $isDescriptionExpanded,
                    font: descriptionFont
                )
                
                DetailInteractionRow(
                    isLiked: viewModel.isLiked,
                    likeCount: viewModel.likeCount,
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
        return images[min(viewModel.initialImageIndex, images.count - 1)]
    }

    // MARK: - Reply Submission

    private func submitReply() {
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !viewModel.isSubmittingReply else { return }
        Task {
            let success = await viewModel.createReply(content: trimmed)
            if success {
                await MainActor.run { replyText = "" }
            }
        }
    }

    // MARK: - More Options Menu Content

    @ViewBuilder
    private var moreOptionsMenuContent: some View {
        if viewModel.isOwner {
            DetailOptionRow(title: "編輯", systemImage: "pencil") {
                showMoreOptions = false
                if let onOpenRecordEdit {
                    onOpenRecordEdit(viewModel.recordId, viewModel.record) {
                        viewModel.loadRecord()
                    }
                } else {
                    detailSheetRouter.openRecordEdit(
                        id: viewModel.recordId,
                        prefetchedRecord: viewModel.record
                    )
                }
            }
            DetailOptionDivider()
            DetailOptionRow(title: "刪除", systemImage: "trash", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.12)) {
                    showMoreOptions = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                        viewModel.showDeleteConfirmation = true
                    }
                }
            }
        } else {
            DetailOptionRow(title: "檢舉", systemImage: "flag", role: .destructive) {
                showMoreOptions = false
                showReportSheet = true
            }
        }
    }
    
    // MARK: - Supporting Views

    private var loadingView: some View {
        DetailSheetSkeleton(
            showImageCarousel: true,
            contentTopPadding: contentTopPadding
        )
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text(message)
                .foregroundColor(.secondary)
            
            Button("重試") {
                viewModel.loadRecord()
            }
        }
    }
}

// MARK: - Reply Row View

struct ReplyRowView: View {
    let reply: Reply
    var onAuthorTap: ((String) -> Void)? = nil
    var onLikeToggle: ((String) -> Void)? = nil
    var onImageTapForFullScreen: ((_ images: [ImageMedia], _ index: Int) -> Void)? = nil
    @Environment(\.displayScale) private var displayScale
    private let replyImageWidth: CGFloat = 96
    private let replyImageHeight: CGFloat = 96 * 375 / 260
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            avatarButton
            
            VStack(alignment: .leading, spacing: 5) {
                Text(displayName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                
                Text(reply.content)
                    .font(.system(size: 17, weight: .regular, design: .default))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)

                if let images = reply.images, !images.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                                KFImage(URL(string: image.originalPublicUrl))
                                    .placeholder {
                                        Rectangle().fill(Color(.systemGray5))
                                    }
                                    .retry(maxCount: 2, interval: .seconds(1))
                                    .setProcessor(
                                        DownsamplingImageProcessor(
                                            size: CGSize(
                                                width: replyImageWidth * displayScale,
                                                height: replyImageHeight * displayScale
                                            )
                                        )
                                    )
                                    .scaleFactor(displayScale)
                                    .cacheOriginalImage()
                                    .fade(duration: 0.2)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: replyImageWidth, height: replyImageHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .onTapGesture {
                                        onImageTapForFullScreen?(images, index)
                                    }
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    Text(formatTimeAgo(reply.createdAt))
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)

                    if reply.likeCount > 0 {
                        Text("\(reply.likeCount)個讚")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer(minLength: 8)
            
            Button {
                onLikeToggle?(reply.id)
            } label: {
                Image(systemName: (reply.userHasLiked ?? false) ? "heart.fill" : "heart")
                    .font(.system(size: 20))
                    .foregroundColor((reply.userHasLiked ?? false) ? .red : .secondary)
                    .padding(.top, 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
    }
    
    private var avatarView: some View {
        Group {
            if let avatarUrl = reply.author?.avatarUrl,
               !avatarUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                KFImage(URL(string: avatarUrl))
                    .placeholder {
                        Circle().fill(Color(.systemGray4))
                    }
                    .retry(maxCount: 2, interval: .seconds(1))
                    .cacheOriginalImage()
                    .fade(duration: 0.2)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Color(.systemGray4))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.appOnPrimary)
                    )
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
    }
    
    private var avatarButton: some View {
        Button {
            let userId = reply.author?.id ?? reply.userId
            onAuthorTap?(userId)
        } label: {
            avatarView
        }
        .buttonStyle(.plain)
    }
    
    private var displayName: String {
        let candidate = reply.author?.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let candidate, !candidate.isEmpty {
            return candidate
        }
        return "使用者"
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

struct MoreOptionsButtonAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
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
