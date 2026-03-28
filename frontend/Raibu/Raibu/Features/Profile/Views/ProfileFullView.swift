//
//  ProfileFullView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI
import Combine
import Kingfisher
import UIKit

/// 個人頁面視圖
struct ProfileFullView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var container: DIContainer
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var detailSheetRouter: DetailSheetRouter
    @StateObject private var viewModel: ProfileViewModel
    
    @State private var selectedTab = 0
    @State private var showMoreOptions = false
    @State private var activeAskMenuContext: ProfileAskMenuContext? = nil
    @State private var draftAvatarImage: UIImage?
    @State private var isSavingProfile = false
    @State private var profileEditError: String?
    @State private var reportAskId: String? = nil
    @State private var pendingDeleteAskId: String? = nil
    @State private var showAskDeleteConfirmation = false
    @State private var askActionErrorMessage: String? = nil
    @State private var localAskRefreshVersions: [String: Int] = [:]
    @State private var hiddenAskIds: Set<String> = []
    @State private var isBioExpanded = false
    @State private var collapsedBioTextWidth: CGFloat = 0
    @FocusState private var focusedEditField: EditField?
    private let moreOptionsMenuWidth: CGFloat = 186
    private let editTransition = Animation.spring(response: 0.38, dampingFraction: 0.88)
    private let askMenuShowAnimation = Animation.spring(response: 0.32, dampingFraction: 0.82)
    private let askMenuHideAnimation = Animation.easeOut(duration: 0.18)
    private let showsResolveAction = false
    private let maxDisplayNameLength = 15
    private let maxBioLength = 100
    private let collapsedBioCharacterLimit = 30
    
    private enum EditField: Hashable {
        case displayName
        case bio
    }

    init(userRepository: UserRepository) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(userRepository: userRepository))
    }

    private var isEditingProfile: Bool {
        get { navigationCoordinator.isProfileEditing }
        nonmutating set { navigationCoordinator.isProfileEditing = newValue }
    }

    private var draftDisplayName: String {
        get { navigationCoordinator.profileEditDraftDisplayName }
        nonmutating set { navigationCoordinator.profileEditDraftDisplayName = newValue }
    }

    private var draftBio: String {
        get { navigationCoordinator.profileEditDraftBio }
        nonmutating set { navigationCoordinator.profileEditDraftBio = newValue }
    }

    private var draftDisplayNameBinding: Binding<String> {
        Binding(
            get: { draftDisplayName },
            set: { draftDisplayName = $0 }
        )
    }

    private var draftBioBinding: Binding<String> {
        Binding(
            get: { draftBio },
            set: { draftBio = $0 }
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            profileTopBar

            ScrollView {
                VStack(spacing: isEditingProfile ? 12 : 24) {
                    // 個人資料區塊（頭像 + 名字 + 統計）
                    profileHeader

                    if isEditingProfile {
                        editProfilePanel
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                                    removal: .opacity.combined(with: .move(edge: .bottom))
                                )
                            )
                    } else {
                        VStack(spacing: 2) {
                            // 標籤切換
                            tabSection

                            // 列表內容
                            listContent
                        }
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity.combined(with: .move(edge: .bottom))
                            )
                        )
                    }
                }
                .padding(.top, 6)
                .padding(.bottom, 16)
            }
            .refreshable {
                // 下拉刷新：只載入 profile 和當前 tab 的資料
                await viewModel.refreshAll(currentTab: selectedTab)
            }
        }
        .animation(editTransition, value: isEditingProfile)
        .overlayPreferenceValue(ProfileMoreOptionsButtonAnchorPreferenceKey.self) { anchor in
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
        .overlayPreferenceValue(ClusterAskMoreOptionsButtonAnchorPreferenceKey.self) { anchors in
            GeometryReader { proxy in
                if selectedTab == 1,
                   let context = activeAskMenuContext,
                   let anchor = anchors[context.askId] {
                    let buttonFrame = proxy[anchor]
                    DetailMoreOptionsOverlay(
                        buttonFrame: buttonFrame,
                        menuWidth: moreOptionsMenuWidth,
                        onDismiss: { closeAskMenu() }
                    ) {
                        askMoreOptionsMenuContent(for: context)
                    }
                }
            }
        }
        .overlay {
            if showAskDeleteConfirmation, pendingDeleteAskId != nil {
                DetailDeleteConfirmation(
                    isPresented: $showAskDeleteConfirmation,
                    onDelete: {
                        Task {
                            await deletePendingAsk()
                        }
                    }
                )
            }
        }
        .sheet(isPresented: isShowingAskReportSheet) {
            if let reportAskId {
                ReportSheetView(
                    target: .ask(id: reportAskId),
                    apiClient: container.apiClient
                )
            }
        }
        .alert("操作失敗", isPresented: isShowingAskActionErrorAlert, actions: {
            Button("確定") {
                askActionErrorMessage = nil
            }
        }, message: {
            Text(askActionErrorMessage ?? "")
        })
        .onAppear {
            // 首次進入頁面時重置到「我的紀錄」標籤
            selectedTab = 0
            isBioExpanded = false
            
            // 首次進入頁面時載入資料
            Task {
                // 並行載入 profile 和 records
                await viewModel.loadProfile(forceRefresh: !viewModel.hasLoadedProfile)
                await viewModel.loadMyRecords(forceRefresh: !viewModel.hasLoadedRecords)
            }
        }
        .onChange(of: navigationCoordinator.selectedTab) { _, newTab in
            // 當從其他頁面切換到個人頁面時，刷新資料
            if newTab == 2 {
                isBioExpanded = false
                selectedTab = 0  // 重置到「我的紀錄」標籤
                
                Task {
                    // 背景更新資料（並行執行）
                    async let profileTask: () = viewModel.loadProfile(forceRefresh: true)
                    async let recordsTask: () = viewModel.loadMyRecords(forceRefresh: true)
                    _ = await (profileTask, recordsTask)
                }
            } else {
                isBioExpanded = false
                resetProfileEditingStateForPageSwitch()
            }
        }
        .onDisappear {
            isBioExpanded = false
            closeAllMenus()
            resetProfileEditingStateForPageSwitch()
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            // 只有當 tab 真正改變時才載入
            guard oldTab != newTab else { return }
            closeAskMenu()
            
            // Tab 切換時載入對應資料
            Task {
                await loadCurrentTabData()
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadCurrentTabData() async {
        if selectedTab == 0 {
            // 載入紀錄
            await viewModel.loadMyRecords(forceRefresh: viewModel.hasLoadedRecords)
        } else {
            // 載入詢問
            await viewModel.loadMyAsks(forceRefresh: viewModel.hasLoadedAsks)
        }
    }

    private var visibleMyAsks: [Ask] {
        viewModel.myAsks.filter { !hiddenAskIds.contains($0.id) }
    }

    private var isShowingAskReportSheet: Binding<Bool> {
        Binding(
            get: { reportAskId != nil },
            set: { isPresented in
                if !isPresented {
                    reportAskId = nil
                }
            }
        )
    }

    private var isShowingAskActionErrorAlert: Binding<Bool> {
        Binding(
            get: { askActionErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    askActionErrorMessage = nil
                }
            }
        )
    }

    private func askRefreshVersion(for askId: String) -> Int {
        detailSheetRouter.askRefreshVersion(for: askId) + localAskRefreshVersions[askId, default: 0]
    }
    
    private var profileTopBar: some View {
        HStack {
            Spacer()
            profileMoreOptionsButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 0)
    }
    
    private var profileMoreOptionsButton: some View {
        Button {
            guard !isEditingProfile else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                activeAskMenuContext = nil
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
        .opacity(isEditingProfile ? 0.35 : 1.0)
        .disabled(isEditingProfile)
        .anchorPreference(key: ProfileMoreOptionsButtonAnchorPreferenceKey.self, value: .bounds) { $0 }
    }
    
    @ViewBuilder
    private var moreOptionsMenuContent: some View {
        DetailOptionRow(title: "編輯個人資料", systemImage: "square.and.pencil") {
            withAnimation(.easeOut(duration: 0.16)) {
                showMoreOptions = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(editTransition) {
                    beginProfileEditing()
                }
            }
        }

        DetailOptionDivider()
        DetailOptionRow(title: "登出", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
            showMoreOptions = false
            Task {
                await authService.signOut()
            }
        }
    }
    
    // MARK: - Profile Header (頭像左邊、資訊右邊的水平排版)
    
    private var profileHeader: some View {
        Group {
            if !viewModel.hasLoadedProfile {
                profileHeaderSkeleton
                    .transition(.opacity)
            } else {
                VStack(spacing: isEditingProfile ? 14 : 36) {
                    // 上方：頭像 + 名字 (名片樣式)
                    HStack(alignment: .top, spacing: 16) {
                        // 頭像
                        profileAvatarView
                        
                        // 名稱與描述
                        VStack(alignment: .leading, spacing: 10) {
                            Text(profileDisplayNameText)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            if isEditingProfile {
                                Text(profileBioPreviewText)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                            } else {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(isBioExpanded ? profileBioPreviewText : collapsedProfileBioText)
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                        .background {
                                            GeometryReader { proxy in
                                                Color.clear
                                                    .onAppear {
                                                        updateCollapsedBioTextWidth(proxy.size.width)
                                                    }
                                                    .onChange(of: proxy.size.width) { _, newWidth in
                                                        updateCollapsedBioTextWidth(newWidth)
                                                    }
                                            }
                                        }

                                    if hasExpandableBio {
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                isBioExpanded.toggle()
                                            }
                                        } label: {
                                            Text(isBioExpanded ? "收合" : "更多...")
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(20)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    // 下方：統計數據
                    if !isEditingProfile {
                        HStack(spacing: 0) {
                            profileStatItem(
                                value: viewModel.profile?.totalRecords ?? 0,
                                label: "紀錄"
                            )
                            .frame(maxWidth: .infinity)
                            
                            statSeparator
                            
                            profileStatItem(
                                value: viewModel.profile?.totalAsks ?? 0,
                                label: "詢問"
                            )
                            .frame(maxWidth: .infinity)
                            
                            statSeparator
                            
                            profileStatItem(
                                value: viewModel.profile?.totalLikes ?? 0,
                                label: "按讚"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 0)
                .padding(.bottom, 20)
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - Loading Skeleton
    
    /// 個人頁面頭部骨架屏（與實際佈局完全一致）
    private var profileHeaderSkeleton: some View {
        VStack(spacing: 36) {
            // 上方：頭像 + 名字 (名片樣式)
            HStack(spacing: 16) {
                // 頭像
                ShimmerCircle(size: 100)
                
                // 名稱與描述
                VStack(alignment: .leading, spacing: 6) {
                    ShimmerBox(width: 120, height: 24, cornerRadius: 4)
                    ShimmerBox(width: 180, height: 16, cornerRadius: 4)
                }
                
                Spacer()
            }
            .padding(20)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            
            // 下方：統計數據
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                    VStack(spacing: 6) {
                        // Label
                        ShimmerBox(width: 40, height: 16)
                        
                        // Value
                        ShimmerBox(width: 60, height: 26)
                    }
                    .frame(maxWidth: .infinity)
                    
                    if index < 2 {
                        statSeparator
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 0)
        .padding(.bottom, 20)
    }
    
    private var statSeparator: some View {
        Rectangle()
            .fill(Color(.systemGray4))
            .frame(width: 1, height: 24)
    }
    
    /// 個人頁面統計項目（簡潔版）
    private func profileStatItem(value: Int, label: String) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            
            Text(formatStatValue(value))
                .font(.custom("Copperplate", size: 22))
                .foregroundColor(.primary)
        }
    }
    
    /// 格式化統計數值（大數字顯示為 k）
    private func formatStatValue(_ value: Int) -> String {
        if value >= 1000 {
            let kValue = Double(value) / 1000.0
            return String(format: "%.1fk", kValue)
        }
        return "\(value)"
    }
    
    // MARK: - Tab Section
    
    private var tabSection: some View {
        HStack(spacing: 0) {
            Spacer()
            tabButton(title: "紀錄", index: 0)
                .frame(width: 120)
            Spacer()
                .frame(width: 24)
            tabButton(title: "詢問", index: 1)
                .frame(width: 120)
            Spacer()
        }
    }
    
    private func tabButton(title: String, index: Int) -> some View {
        Button {
            // 觸覺反饋
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: selectedTab == index ? .bold : .medium))
                    .foregroundColor(selectedTab == index ? .primary : .secondary)
                
                // 底線指示器
                Rectangle()
                    .fill(selectedTab == index ? Color.primary : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - List Content
    
    /// 九宮格列定義 (3列)
    private let gridColumns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    @ViewBuilder
    private var listContent: some View {
        if selectedTab == 0 {
            recordsGrid
        } else {
            asksGrid
        }
    }
    
    private var recordsGrid: some View {
        Group {
            if !viewModel.hasLoadedRecords {
                // 載入中骨架屏 (只要還沒載入完成就顯示這個)
                LazyVGrid(columns: gridColumns, spacing: 2) {
                    ForEach(0..<9, id: \.self) { _ in
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
                .padding(.horizontal, 2)
            } else if viewModel.myRecords.isEmpty {
                // 載入完成且為空 -> 顯示空狀態
                emptyStateView(
                    icon: "camera",
                    title: "還沒有紀錄",
                    subtitle: "開始分享你的第一個紀錄吧！"
                )
            } else {
                // 載入完成且有資料 -> 顯示內容
                LazyVGrid(columns: gridColumns, spacing: 2) {
                    ForEach(viewModel.myRecords) { record in
                        Button {
                            detailSheetRouter.open(.record(id: record.id, imageIndex: 0))
                        } label: {
                            recordGridItem(record)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.myRecords.count)
    }
    
    private var asksGrid: some View {
        Group {
            if !viewModel.hasLoadedAsks {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<3, id: \.self) { index in
                        askListSkeletonItem
                        if index != 2 {
                            Divider()
                        }
                    }
                }
            } else if viewModel.myAsks.isEmpty {
                // 載入完成且為空
                emptyStateView(
                    icon: "questionmark.circle",
                    title: "還沒有詢問",
                    subtitle: "在地圖上長按開始提問！"
                )
            } else if visibleMyAsks.isEmpty {
                // 目前列表已刪除完（等待重新整理）
                emptyStateView(
                    icon: "questionmark.circle",
                    title: "還沒有詢問",
                    subtitle: "在地圖上長按開始提問！"
                )
            } else {
                // 載入完成且有資料：改為和群聚 Sheet 一樣的列表卡片
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(visibleMyAsks.enumerated()), id: \.element.id) { index, ask in
                        ClusterAskDetailPreviewCard(
                            askSummary: askListSummary(from: ask),
                            askRepository: container.askRepository,
                            replyRepository: container.replyRepository,
                            refreshVersion: askRefreshVersion(for: ask.id),
                            showResolvedBadge: false,
                            onMoreOptionsTap: { askId, prefetchedAsk, isOwner, status in
                                openAskMenu(
                                    .init(
                                        askId: askId,
                                        prefetchedAsk: prefetchedAsk,
                                        isOwner: isOwner,
                                        status: status
                                    )
                                )
                            },
                            onOpenDetail: {
                                closeAllMenus()
                                detailSheetRouter.open(.ask(id: ask.id))
                            }
                        )
                        if index != visibleMyAsks.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.myAsks.count)
    }
    
    // MARK: - Grid Item Views
    
    /// 紀錄九宮格項目（圖片 + 左下角愛心數）
    private func recordGridItem(_ record: Record) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // 主圖片
                KFImage(URL(string: record.mainImageUrl ?? ""))
                    .placeholder {
                        Rectangle()
                            .fill(Color(.systemGray5))
                    }
                    .retry(maxCount: 2, interval: .seconds(1))
                    .cacheOriginalImage()
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .clipped()
                
                // 左下角愛心數
                HStack(spacing: 3) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                    Text("\(record.likeCount)")
                        .font(.caption2.weight(.medium))
                }
                .foregroundColor(.appOnPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.appOverlay.opacity(0.5))
                .cornerRadius(4)
                .padding(6)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private var askListSkeletonItem: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ShimmerCircle(size: 40)
                VStack(alignment: .leading, spacing: 6) {
                    ShimmerBox(width: 120, height: 15, cornerRadius: 4)
                    ShimmerBox(width: 78, height: 11, cornerRadius: 4)
                }
                Spacer()
            }

            ShimmerBox(height: 16, cornerRadius: 4)
            ShimmerBox(width: 220, height: 16, cornerRadius: 4)
            ShimmerBox(width: 160, height: 12, cornerRadius: 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private func askListSummary(from ask: Ask) -> MapAsk {
        MapAsk(
            id: ask.id,
            center: ask.center,
            radiusMeters: ask.radiusMeters,
            title: ask.title,
            question: ask.question,
            mainImageUrl: ask.mainImageUrl,
            authorAvatarUrl: viewModel.profile?.avatarUrl,
            status: ask.status,
            createdAt: ask.createdAt,
            likeCount: ask.likeCount,
            viewCount: ask.viewCount
        )
    }

    @ViewBuilder
    private func askMoreOptionsMenuContent(for context: ProfileAskMenuContext) -> some View {
        if context.isOwner {
            DetailOptionRow(title: "編輯", systemImage: "pencil") {
                closeAskMenu()
                detailSheetRouter.openAskEdit(id: context.askId, prefetchedAsk: context.prefetchedAsk)
            }

            if showsResolveAction, context.status == .active {
                DetailOptionDivider()
                DetailOptionRow(title: "標記為已解決", systemImage: "checkmark.circle") {
                    closeAskMenu()
                    Task {
                        await resolveAsk(id: context.askId)
                    }
                }
            }

            DetailOptionDivider()
            DetailOptionRow(title: "刪除", systemImage: "trash", role: .destructive) {
                closeAskMenu()
                pendingDeleteAskId = context.askId
                showAskDeleteConfirmation = true
            }
        } else {
            DetailOptionRow(title: "檢舉", systemImage: "flag", role: .destructive) {
                closeAskMenu()
                reportAskId = context.askId
            }
        }
    }

    private func openAskMenu(_ context: ProfileAskMenuContext) {
        withAnimation(askMenuShowAnimation) {
            showMoreOptions = false
            activeAskMenuContext = context
        }
    }

    private func closeAskMenu() {
        withAnimation(askMenuHideAnimation) {
            activeAskMenuContext = nil
        }
    }

    private func closeAllMenus() {
        withAnimation(askMenuHideAnimation) {
            showMoreOptions = false
            activeAskMenuContext = nil
        }
    }

    private func deletePendingAsk() async {
        guard let askId = pendingDeleteAskId else { return }
        do {
            try await container.askRepository.deleteAsk(id: askId)
            await MainActor.run {
                hiddenAskIds.insert(askId)
                localAskRefreshVersions[askId, default: 0] += 1
                pendingDeleteAskId = nil
                activeAskMenuContext = nil
            }
            await viewModel.loadMyAsks(forceRefresh: true)
            await viewModel.loadProfile(forceRefresh: true)
        } catch {
            await MainActor.run {
                askActionErrorMessage = error.localizedDescription
            }
        }
    }

    private func resolveAsk(id askId: String) async {
        do {
            try await container.askRepository.updateAsk(
                id: askId,
                question: nil,
                status: .resolved,
                sortedImages: nil
            )
            await MainActor.run {
                localAskRefreshVersions[askId, default: 0] += 1
            }
        } catch {
            await MainActor.run {
                askActionErrorMessage = error.localizedDescription
            }
        }
    }
    
    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Helpers
    
    @ViewBuilder
    private var profileAvatarView: some View {
        if let selectedImage = draftAvatarImage, isEditingProfile {
            Image(uiImage: selectedImage)
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(Circle())
        } else {
            KFImage(URL(string: viewModel.profile?.avatarUrl ?? ""))
                .placeholder {
                    Circle()
                        .fill(Color(.systemGray4))
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 65))
                                .foregroundColor(.secondary)
                        )
                }
                .retry(maxCount: 2, interval: .seconds(1))
                .cacheOriginalImage()
                .fade(duration: 0.2)
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(Circle())
        }
    }

    private var profileDisplayNameText: String {
        let text: String
        if isEditingProfile {
            text = draftDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            text = viewModel.profile?.displayName ?? ""
        }
        return text
    }

    private var profileRawBioText: String {
        let raw: String
        if isEditingProfile {
            raw = draftBio
        } else {
            raw = viewModel.profile?.bio ?? ""
        }
        return raw
    }

    private var normalizedProfileBioText: String {
        let raw = profileRawBioText
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed
    }

    private var profileBioPreviewText: String {
        normalizedProfileBioText
    }

    private var hasExpandableBio: Bool {
        let text = normalizedProfileBioText
        guard !text.isEmpty else { return false }
        guard collapsedBioTextWidth > 0 else {
            return text.count > collapsedBioCharacterLimit
        }
        return !doesBioTextFitInTwoLines(text, width: collapsedBioTextWidth)
    }

    private var collapsedProfileBioText: String {
        let text = normalizedProfileBioText
        guard !text.isEmpty else { return "" }
        guard collapsedBioTextWidth > 0 else {
            return String(text.prefix(collapsedBioCharacterLimit))
        }
        guard !doesBioTextFitInTwoLines(text, width: collapsedBioTextWidth) else {
            return text
        }

        let characters = Array(text)
        var low = 0
        var high = characters.count
        var best = 0

        while low <= high {
            let mid = (low + high) / 2
            let candidate = String(characters.prefix(mid))
            if doesBioTextFitInTwoLines(candidate, width: collapsedBioTextWidth) {
                best = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return String(characters.prefix(best)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateCollapsedBioTextWidth(_ width: CGFloat) {
        let normalizedWidth = max(0, width.rounded(.down))
        guard abs(collapsedBioTextWidth - normalizedWidth) > 0.5 else { return }
        collapsedBioTextWidth = normalizedWidth
    }

    private func doesBioTextFitInTwoLines(_ text: String, width: CGFloat) -> Bool {
        guard width > 0 else { return true }
        guard !text.isEmpty else { return true }

        let font = UIFont.systemFont(ofSize: 14)
        let boundingRect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        let maxHeight = font.lineHeight * 2 + 0.5
        return boundingRect.height <= maxHeight
    }

    private var isSaveProfileButtonDisabled: Bool {
        isSavingProfile || draftDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var remainingDisplayNameCount: Int {
        max(0, maxDisplayNameLength - draftDisplayName.count)
    }

    private var remainingBioCount: Int {
        max(0, maxBioLength - draftBio.count)
    }

    private var editProfilePanel: some View {
        VStack(spacing: 0) {
            Color(.systemBackground)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 10) {
                            Button {
                                cancelProfileEditing()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(.plain)
                            .disabled(isSavingProfile)

                            Text("編輯個人資料")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)

                            Spacer()
                        }

                        HStack(alignment: .center, spacing: 12) {
                            Text("頭像")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)

                            Spacer()

                            AvatarPickerView(
                                selectedImage: $draftAvatarImage,
                                currentAvatarURL: viewModel.profile?.avatarUrl,
                                size: 84,
                                showsCameraBadge: false
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("姓名")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)

                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                TextField("請輸入姓名", text: draftDisplayNameBinding)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 16))
                                    .focused($focusedEditField, equals: .displayName)
                                    .onChange(of: draftDisplayName) { _, newValue in
                                        if newValue.count > maxDisplayNameLength {
                                            draftDisplayName = String(newValue.prefix(maxDisplayNameLength))
                                        }
                                    }

                                Text("\(remainingDisplayNameCount)")
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 2)
                            .padding(.bottom, 8)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(focusedEditField == .displayName ? Color.primary : Color(.systemGray3))
                                    .frame(height: 1)
                                }
                            .animation(.easeInOut(duration: 0.16), value: focusedEditField)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("簡介")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)

                            HStack(alignment: .bottom, spacing: 8) {
                                TextField("介紹一下自己", text: draftBioBinding, axis: .vertical)
                                    .lineLimit(3...6)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 16))
                                    .focused($focusedEditField, equals: .bio)
                                    .onChange(of: draftBio) { _, newValue in
                                        if newValue.count > maxBioLength {
                                            draftBio = String(newValue.prefix(maxBioLength))
                                        }
                                    }

                                Text("\(remainingBioCount)")
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 2)
                            }
                            .padding(.top, 2)
                            .padding(.bottom, 8)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(focusedEditField == .bio ? Color.primary : Color(.systemGray3))
                                    .frame(height: 1)
                                }
                            .animation(.easeInOut(duration: 0.16), value: focusedEditField)
                        }

                        if let profileEditError, !profileEditError.isEmpty {
                            Text(profileEditError)
                                .font(.system(size: 13))
                                .foregroundColor(.appDanger)
                        }

                        Button {
                            Task { await saveProfileEdits() }
                        } label: {
                            HStack {
                                Spacer()
                                if isSavingProfile {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("完成")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(isSaveProfileButtonDisabled ? Color.appDisabled : Color.primary)
                            .foregroundColor(.appOnPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .disabled(isSaveProfileButtonDisabled)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
        }
        .frame(maxWidth: .infinity, minHeight: 420, alignment: .topLeading)
    }

    private func beginProfileEditing() {
        guard let profile = viewModel.profile else { return }
        draftDisplayName = String(profile.displayName.prefix(maxDisplayNameLength))
        draftBio = String((profile.bio ?? "").prefix(maxBioLength))
        draftAvatarImage = nil
        profileEditError = nil
        focusedEditField = nil
        isBioExpanded = false
        isEditingProfile = true
    }

    private func cancelProfileEditing() {
        guard !isSavingProfile else { return }
        focusedEditField = nil
        profileEditError = nil
        draftAvatarImage = nil
        isBioExpanded = false
        withAnimation(editTransition) {
            isEditingProfile = false
        }
    }

    private func resetProfileEditingStateForPageSwitch() {
        guard isEditingProfile else { return }
        focusedEditField = nil
        profileEditError = nil
        draftAvatarImage = nil
        draftDisplayName = ""
        draftBio = ""
        isEditingProfile = false
    }

    private func saveProfileEdits() async {
        guard !isSavingProfile else { return }
        focusedEditField = nil

        let trimmedName = draftDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            profileEditError = "姓名不可為空"
            return
        }
        guard trimmedName.count <= maxDisplayNameLength else {
            profileEditError = "姓名最多 \(maxDisplayNameLength) 字"
            return
        }
        let trimmedBio = draftBio.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedBio.count <= maxBioLength else {
            profileEditError = "簡介最多 \(maxBioLength) 字"
            return
        }

        isSavingProfile = true
        profileEditError = nil

        do {
            var uploadedAvatarURL: String?
            if let avatarImage = draftAvatarImage {
                uploadedAvatarURL = try await uploadAvatarImage(avatarImage)
            }

            let request = ProfileEditUpdateRequest(
                displayName: trimmedName,
                avatarUrl: uploadedAvatarURL,
                bio: trimmedBio
            )
            let _: ProfileEditUpdateResponse = try await container.apiClient.patch(.updateMe, body: request)

            await viewModel.loadProfile(forceRefresh: true)
            if let refreshedProfile = viewModel.profile {
                authService.cacheCurrentUserProfile(refreshedProfile.toUser())
            }

            draftAvatarImage = nil
            isBioExpanded = false
            withAnimation(editTransition) {
                isEditingProfile = false
            }
        } catch {
            profileEditError = "儲存失敗：\(error.localizedDescription)"
        }

        isSavingProfile = false
    }

    private func uploadAvatarImage(_ image: UIImage) async throws -> String {
        let credential: AvatarUploadCredential = try await container.apiClient.post(
            .uploadAvatar,
            body: AvatarUploadRequest(fileType: "image/jpeg")
        )

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ProfileEditError.imageConversionFailed
        }

        guard let uploadURL = URL(string: credential.uploadUrl) else {
            throw ProfileEditError.invalidUploadUrl
        }

        try await container.apiClient.uploadToPresignedURL(
            data: imageData,
            url: uploadURL,
            contentType: "image/jpeg"
        )

        return credential.publicUrl
    }
}

private struct ProfileEditUpdateRequest: Encodable {
    let displayName: String
    let avatarUrl: String?
    let bio: String

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case bio
    }
}

private struct ProfileEditUpdateResponse: Decodable {
    let success: Bool
}

private enum ProfileEditError: LocalizedError {
    case imageConversionFailed
    case invalidUploadUrl

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "圖片轉換失敗"
        case .invalidUploadUrl:
            return "無效的上傳網址"
        }
    }
}

private struct ProfileAskMenuContext: Equatable {
    let askId: String
    let prefetchedAsk: Ask?
    let isOwner: Bool
    let status: AskStatus?
}

private struct ProfileMoreOptionsButtonAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

// MARK: - Card Button Style

/// 卡片按鈕樣式（帶點擊動畫）
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    ProfileFullView(
        userRepository: UserRepository(apiClient: APIClient(baseURL: "", authService: AuthService()))
    )
    .environmentObject(DIContainer())
    .environmentObject(NavigationCoordinator())
    .environmentObject(DetailSheetRouter())
    .environmentObject(AuthService())
}
