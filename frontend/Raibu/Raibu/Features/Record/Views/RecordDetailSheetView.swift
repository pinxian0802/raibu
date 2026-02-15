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
    @Environment(\.globalDetailSheetContentTopSpacing) private var globalDetailSheetContentTopSpacing
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var detailSheetRouter: DetailSheetRouter
    @EnvironmentObject var container: DIContainer
    @StateObject private var viewModel: RecordDetailViewModel
    @State private var showReplyInput = false
    @State private var showMoreOptions = false
    @State private var showEditSheet = false
    @State private var showReportSheet = false
    @State private var replyText = ""
    @State private var currentUserAvatarURLFromProfile: String?
    @State private var isDescriptionExpanded = false
    @State private var isHeartAnimating = false
    @State private var isLoadingPulseActive = false
    @State private var hasStartedInitialLoad = false
    
    private let descriptionCollapsedLineLimit = 3
    private let descriptionExpandThreshold = 90
    
    private let authorNameFont = Font.system(size: 18, weight: .semibold, design: .rounded)
    private let metaCaptionFont = Font.system(size: 12, weight: .regular, design: .rounded)
    private let descriptionFont = Font.system(size: 16, weight: .regular, design: .rounded)
    private let actionFont = Font.system(size: 14, weight: .medium, design: .rounded)
    private let moreOptionsMenuWidth: CGFloat = 186
    
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
                .padding(.bottom, 4 + globalDetailSheetContentTopSpacing)
            
            ZStack {
                if viewModel.isLoading {
                    loadingView
                } else if let record = viewModel.record {
                    VStack(spacing: 0) {
                        contentView(record: record)
                        Divider()
                        bottomReplyInputBar
                    }
                } else if let error = viewModel.errorMessage {
                    errorView(message: error)
                } else {
                    loadingView
                }
            }
        }
        .overlayPreferenceValue(MoreOptionsButtonAnchorPreferenceKey.self) { anchor in
            GeometryReader { proxy in
                if showMoreOptions, let anchor {
                    let buttonFrame = proxy[anchor]
                    moreOptionsOverlay(buttonFrame: buttonFrame)
                }
            }
        }
        .overlay {
            if viewModel.showDeleteConfirmation {
                deleteConfirmationOverlay
            }
        }
        .task {
            guard !hasStartedInitialLoad else { return }
            hasStartedInitialLoad = true
            viewModel.loadRecord()
            await loadCurrentUserAvatarIfNeeded()
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
                            viewModel.loadRecord()
                        }
                    }
                )
            }
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
        .onDisappear {
            viewModel.cancelAllTasks()
        }
    }
    
    // MARK: - Content View
    
    private func contentView(record: Record) -> some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    recordBodySection(record: record)
                        .frame(minHeight: proxy.size.height * 0.82, alignment: .top)
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    if !viewModel.replies.isEmpty {
                        repliesSection
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 24)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private func recordBodySection(record: Record) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. 圖片輪播 (置頂，無 Padding)
            if let images = record.images, !images.isEmpty {
                ImageCarouselView(
                    images: images,
                    initialIndex: viewModel.initialImageIndex,
                    imageContentMode: .fill,
                    imageHeight: 400,
                    onLocationTap: { image in
                        if let coordinate = image.clLocationCoordinate {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                navigationCoordinator.navigateToMap(coordinate: coordinate, mapMode: .record)
                            }
                        }
                    }
                )
            }

            VStack(alignment: .leading, spacing: 16) {
                // 2. 用戶資訊列 (頭像、名字、時間、追蹤按鈕)
                if let author = record.author {
                    userInfoRow(author: author, createdAt: record.createdAt)
                }
                
                // 3. 內容描述
                descriptionTextSection(record.description)
                
                interactionSummaryRow
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 10)
        }
    }
    
    private func descriptionTextSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(description)
                .font(descriptionFont)
                .foregroundColor(.primary)
                .lineLimit(isDescriptionExpanded ? nil : descriptionCollapsedLineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
            
            if shouldShowDescriptionToggle(description) {
                Button(isDescriptionExpanded ? "收起" : "更多") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDescriptionExpanded.toggle()
                    }
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
            }
        }
        .frame(minHeight: 70, alignment: .topLeading)
    }
    
    private func shouldShowDescriptionToggle(_ description: String) -> Bool {
        let lineBreakCount = description.filter { $0 == "\n" }.count
        return lineBreakCount >= descriptionCollapsedLineLimit || description.count > descriptionExpandThreshold
    }
    
    private var interactionSummaryRow: some View {
        HStack(spacing: 18) {
            Button {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.45)) {
                    isHeartAnimating = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                        isHeartAnimating = false
                    }
                }
                Task {
                    await viewModel.toggleLike()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isLiked ? "heart.fill" : "heart")
                        .foregroundColor(viewModel.isLiked ? .red : .secondary)
                        .scaleEffect(isHeartAnimating ? 1.24 : (viewModel.isLiked ? 1.08 : 1.0))
                        .animation(.spring(response: 0.28, dampingFraction: 0.6), value: isHeartAnimating)
                        .animation(.easeInOut(duration: 0.15), value: viewModel.isLiked)
                    Text("\(viewModel.likeCount)")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            HStack(spacing: 6) {
                Image(systemName: "message")
                    .foregroundColor(.secondary)
                Text("\(viewModel.replies.count)")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .font(actionFont)
        .padding(.top, 2)
    }
    
    // MARK: - User Info Row
    
    private func userInfoRow(author: User, createdAt: Date) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Avatar
            Button {
                detailSheetRouter.open(.userProfile(id: author.id))
            } label: {
                KFImage(URL(string: author.avatarUrl ?? ""))
                    .placeholder {
                        Circle().fill(Color(.systemGray4))
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Name & Time
            VStack(alignment: .leading, spacing: 2) {
                Text(author.displayName)
                    .font(authorNameFont)
                    .foregroundColor(.primary)
                
                Text(formatTimeAgo(createdAt))
                    .font(metaCaptionFont)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // More Options (replaces old profile button position)
            moreOptionsButton
        }
    }
    
    // MARK: - Bottom Reply Bar
    
    private var trimmedReplyText: String {
        replyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var showSendReplyButton: Bool {
        !trimmedReplyText.isEmpty
    }
    
    private var canSendReply: Bool {
        showSendReplyButton && !viewModel.isSubmittingReply
    }
    
    private func submitReply() {
        guard canSendReply else { return }
        
        Task {
            let success = await viewModel.createReply(content: trimmedReplyText)
            if success {
                await MainActor.run {
                    replyText = ""
                }
            }
        }
    }
    
    private var bottomReplyInputBar: some View {
        HStack(spacing: 12) {
            // Current User Avatar
            if let avatarURL = currentUserAvatarURL {
                KFImage(URL(string: avatarURL))
                    .placeholder {
                        Circle().fill(Color(.systemGray4))
                    }
                    .retry(maxCount: 2, interval: .seconds(1))
                    .cacheOriginalImage()
                    .fade(duration: 0.2)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.gray)
            }
            
            ZStack(alignment: .trailing) {
                TextField("說些什麼吧", text: $replyText)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.send)
                    .onSubmit {
                        submitReply()
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, showSendReplyButton ? 44 : 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
                
                if showSendReplyButton {
                    Button {
                        submitReply()
                    } label: {
                        if viewModel.isSubmittingReply {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.blue)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSendReply)
                    .padding(.trailing, 14)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
    }
    
    // MARK: - Replies Section
    
    private var repliesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.replies) { reply in
                ReplyRowView(
                    reply: reply,
                    onAuthorTap: { userId in
                        detailSheetRouter.open(.userProfile(id: userId))
                    },
                    onLikeToggle: { replyId in
                        Task { await viewModel.toggleReplyLike(replyId: replyId) }
                    }
                )
                
                if reply.id != viewModel.replies.last?.id {
                    Divider()
                }
            }
        }
    }
    
    // MARK: - Supporting Views
    
    private var loadingView: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        loadingRecordBodySection
                            .frame(minHeight: proxy.size.height * 0.82, alignment: .top)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollDisabled(true)
                
                Divider()
                loadingReplyInputBar
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .opacity(isLoadingPulseActive ? 0.84 : 1.0)
        .onAppear {
            guard !isLoadingPulseActive else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isLoadingPulseActive = true
            }
        }
        .onDisappear {
            isLoadingPulseActive = false
        }
    }
    
    private var loadingRecordBodySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 圖片輪播區
            skeletonBox(height: 400, cornerRadius: 0)
            
            VStack(alignment: .leading, spacing: 16) {
                loadingUserInfoRow
                loadingDescriptionSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 10)
        }
    }
    
    private var loadingUserInfoRow: some View {
        HStack(alignment: .center, spacing: 12) {
            skeletonCircle(size: 40)
            
            VStack(alignment: .leading, spacing: 6) {
                skeletonBox(width: 110, height: 16)
                skeletonBox(width: 70, height: 12)
            }
            
            Spacer()
        }
    }
    
    private var loadingDescriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            skeletonBox(height: 16)
            skeletonBox(width: 260, height: 16)
            skeletonBox(width: 180, height: 16)
        }
        .frame(minHeight: 70, alignment: .topLeading)
    }
    
    private var loadingReplyInputBar: some View {
        HStack(spacing: 12) {
            skeletonCircle(size: 32)
            
            Capsule()
                .fill(Color(.systemGray5))
                .frame(height: 40)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
    }
    
    private func skeletonBox(
        width: CGFloat? = nil,
        height: CGFloat,
        cornerRadius: CGFloat = 4
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
    }
    
    private func skeletonCircle(size: CGFloat) -> some View {
        Circle()
            .fill(Color(.systemGray5))
            .frame(width: size, height: size)
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
                    viewModel.loadRecord()
                }
            }
        }
    }
    
    private var moreOptionsButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                showMoreOptions.toggle()
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundColor(.primary)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
        }
        .buttonStyle(.plain)
        .frame(width: 32, height: 32, alignment: .center)
        .contentShape(Rectangle())
        .anchorPreference(key: MoreOptionsButtonAnchorPreferenceKey.self, value: .bounds) {
            $0
        }
    }
    
    private func moreOptionsOverlay(buttonFrame: CGRect) -> some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showMoreOptions = false
                    }
                }
            
            moreOptionsFloatingMenu
                .offset(x: max(12, buttonFrame.maxX - moreOptionsMenuWidth), y: buttonFrame.maxY + 10)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
                .zIndex(100)
        }
    }
    
    private var moreOptionsFloatingMenu: some View {
        VStack(spacing: 0) {
            if viewModel.isOwner {
                optionRow(title: "編輯", systemImage: "pencil") {
                    showMoreOptions = false
                    showEditSheet = true
                }
                optionDivider
                optionRow(title: "刪除", systemImage: "trash", role: .destructive) {
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
                optionRow(title: "檢舉", systemImage: "flag", role: .destructive) {
                    showMoreOptions = false
                    showReportSheet = true
                }
            }
        }
        .frame(width: 186)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 3)
    }
    
    private var deleteConfirmationOverlay: some View {
        GeometryReader { proxy in
            let popupWidth = min(max(proxy.size.width - 40, 260), 320)
            
            ZStack {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.showDeleteConfirmation = false
                        }
                    }
                
                VStack(spacing: 0) {
                    VStack(spacing: 10) {
                        Text("確認刪除")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("確定要刪除此標點嗎？此動作無法復原")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    
                    Divider()
                    
                    HStack(spacing: 0) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.showDeleteConfirmation = false
                            }
                        } label: {
                            Text("取消")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        Divider()
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.showDeleteConfirmation = false
                            }
                            Task {
                                if await viewModel.deleteRecord() {
                                    dismiss()
                                }
                            }
                        } label: {
                            Text("刪除")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(height: 54)
                }
                .frame(width: popupWidth)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(.systemGray5), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 14, x: 0, y: 5)
                .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .transition(.scale(scale: 0.94).combined(with: .opacity))
        .zIndex(200)
    }
    
    private var optionDivider: some View {
        Divider()
            .padding(.leading, 14)
    }
    
    private func optionRow(
        title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role) {
            action()
        } label: {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(role == .destructive ? Color.red : Color.primary)
                
                Spacer()
                
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(role == .destructive ? Color.red : Color.primary)
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
    
    private var currentUserAvatarURL: String? {
        if let avatar = container.authService.currentUser?.avatarUrl,
           !avatar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return avatar
        }
        
        if let fallback = currentUserAvatarURLFromProfile,
           !fallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fallback
        }
        
        return nil
    }
    
    private func loadCurrentUserAvatarIfNeeded() async {
        guard let currentUserId = container.authService.currentUserId else { return }
        
        if let avatar = container.authService.currentUser?.avatarUrl,
           !avatar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }
        
        do {
            let profile = try await container.userRepository.getUserProfile(id: currentUserId)
            let avatar = profile.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let avatar, !avatar.isEmpty else { return }
            await MainActor.run {
                currentUserAvatarURLFromProfile = avatar
            }
        } catch {
            // 保持靜默，失敗時沿用預設頭像
        }
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let now = Date()
        let diff = now.timeIntervalSince(date)
        
        if diff < 60 {
            return "Now"
        } else if diff < 3600 {
            return "\(Int(diff / 60))m ago"
        } else if diff < 86400 {
            return "\(Int(diff / 3600))h ago"
        } else {
            return "\(Int(diff / 86400))d ago"
        }
    }
}

// MARK: - Reply Row View

struct ReplyRowView: View {
    let reply: Reply
    var onAuthorTap: ((String) -> Void)? = nil
    var onLikeToggle: ((String) -> Void)? = nil
    
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
                            .foregroundColor(.white)
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

private struct MoreOptionsButtonAnchorPreferenceKey: PreferenceKey {
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
