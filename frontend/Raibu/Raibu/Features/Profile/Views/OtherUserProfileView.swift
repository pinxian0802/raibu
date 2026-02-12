//
//  OtherUserProfileView.swift
//  Raibu
//
//  查看其他用戶的個人資訊頁面
//

import SwiftUI
import Kingfisher

// MARK: - OtherUserProfileContentView（可嵌入 NavigationView/NavigationStack 內使用）

/// 其他用戶個人頁面的內容視圖（不包含 NavigationView 外殼）
/// 可在既有的 NavigationView 內以 push 方式呈現
struct OtherUserProfileContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var container: DIContainer
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @StateObject private var viewModel: OtherUserProfileViewModel
    
    let userId: String
    
    /// 是否顯示左上角關閉按鈕（用於獨立 sheet 模式）
    let showCloseButton: Bool
    
    @State private var selectedTab = 0
    
    // 詳情 Sheet 狀態
    @State private var selectedDetailItem: DetailSheetItem?
    
    /// 外部傳入的 dismiss 閉包（用於 sheet 模式）
    var onDismiss: (() -> Void)?
    
    init(userId: String, userRepository: UserRepository, showCloseButton: Bool = false, onDismiss: (() -> Void)? = nil) {
        self.userId = userId
        self.showCloseButton = showCloseButton
        self.onDismiss = onDismiss
        _viewModel = StateObject(wrappedValue: OtherUserProfileViewModel(
            userId: userId,
            userRepository: userRepository
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 個人資料區塊（頭像 + 名字 + 統計）
                profileHeader
                
                // 標籤切換
                tabSection
                
                // 列表內容
                listContent
            }
            .padding(.vertical)
        }
        .refreshable {
            await viewModel.refreshAll()
        }
        .navigationTitle("個人資訊")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showCloseButton {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onDismiss?()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .task {
            await viewModel.loadProfile()
            await loadCurrentTabData()
        }
        .onChange(of: selectedTab) { _, newTab in
            Task {
                await loadCurrentTabData()
            }
        }
        .sheet(item: $selectedDetailItem) { item in
            switch item {
            case .record(let recordId, let imageIndex):
                RecordDetailSheetView(
                    recordId: recordId,
                    initialImageIndex: imageIndex,
                    recordRepository: container.recordRepository,
                    replyRepository: container.replyRepository
                )
                .environmentObject(navigationCoordinator)
                .environmentObject(container)
                .environmentObject(authService)
            case .ask(let askId):
                AskDetailSheetView(
                    askId: askId,
                    askRepository: container.askRepository,
                    replyRepository: container.replyRepository
                )
                .environmentObject(navigationCoordinator)
                .environmentObject(container)
                .environmentObject(authService)
            }
        }
    }
    
    // MARK: - Load Data
    
    private func loadCurrentTabData() async {
        if selectedTab == 0 {
            await viewModel.loadUserRecords()
        } else {
            await viewModel.loadUserAsks()
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        HStack(alignment: .center, spacing: 24) {
            // 左側：頭像
            KFImage(URL(string: viewModel.profile?.avatarUrl ?? ""))
                .placeholder {
                    Circle()
                        .fill(Color(.systemGray4))
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 45))
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
            
            // 右側：名字 + 統計數據
            VStack(alignment: .leading, spacing: 16) {
                // 名稱
                Text(viewModel.profile?.displayName ?? "使用者")
                    .font(.title.weight(.bold))
                    .foregroundColor(.primary)
                
                // 統計數據（水平排列）
                HStack(spacing: 24) {
                    profileStatItem(
                        value: viewModel.profile?.totalRecords ?? 0,
                        label: "紀錄"
                    )
                    
                    profileStatItem(
                        value: viewModel.profile?.totalAsks ?? 0,
                        label: "詢問"
                    )
                    
                    profileStatItem(
                        value: viewModel.profile?.totalViews ?? 0,
                        label: "觀看"
                    )
                    
                    profileStatItem(
                        value: viewModel.profile?.totalLikes ?? 0,
                        label: "按讚"
                    )
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
    
    /// 個人頁面統計項目
    private func profileStatItem(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text(formatStatValue(value))
                .font(.title3.weight(.bold))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    /// 格式化統計數值
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
                .frame(width: 80)
            Spacer()
                .frame(width: 24)
            tabButton(title: "詢問", index: 1)
                .frame(width: 80)
            Spacer()
        }
    }
    
    private func tabButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 8) {
                Text(title)
                    .font(.body.weight(selectedTab == index ? .semibold : .regular))
                    .foregroundColor(selectedTab == index ? .primary : .secondary)
                
                Rectangle()
                    .fill(selectedTab == index ? Color.orange : Color.clear)
                    .frame(height: 2)
            }
        }
    }
    
    // MARK: - List Content
    
    private var listContent: some View {
        Group {
            if selectedTab == 0 {
                recordsGrid
            } else {
                asksGrid
            }
        }
    }
    
    private var recordsGrid: some View {
        Group {
            if viewModel.isLoadingRecords {
                ProgressView()
                    .padding(.top, 40)
            } else if viewModel.userRecords.isEmpty {
                emptyStateView(message: "還沒有紀錄")
            } else {
                LazyVGrid(columns: gridColumns, spacing: 2) {
                    ForEach(viewModel.userRecords) { record in
                        Button {
                            selectedDetailItem = .record(id: record.id, imageIndex: 0)
                        } label: {
                            recordGridItem(record)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
    
    private var asksGrid: some View {
        Group {
            if viewModel.isLoadingAsks {
                ProgressView()
                    .padding(.top, 40)
            } else if viewModel.userAsks.isEmpty {
                emptyStateView(message: "還沒有詢問")
            } else {
                LazyVGrid(columns: gridColumns, spacing: 2) {
                    ForEach(viewModel.userAsks) { ask in
                        Button {
                            selectedDetailItem = .ask(id: ask.id)
                        } label: {
                            askGridItem(ask)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
    
    // MARK: - Grid Configuration
    
    private let gridColumns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    // MARK: - Grid Item Views
    
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
                    .fade(duration: 0.2)
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
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.6))
                .cornerRadius(4)
                .padding(6)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func askGridItem(_ ask: Ask) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // 背景
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // 中央問號圖示
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "questionmark")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    Spacer()
                }
                
                // 左下角愛心數
                HStack(spacing: 3) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                    Text("\(ask.likeCount)")
                        .font(.caption2.weight(.medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.6))
                .cornerRadius(4)
                .padding(6)
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func emptyStateView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(message)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - OtherUserProfileView（Sheet 模式的薄包裝器）

/// 以獨立 Sheet 模式顯示其他用戶個人頁面（包含 NavigationView 外殼）
struct OtherUserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    
    let userId: String
    let userRepository: UserRepository
    
    var body: some View {
        NavigationView {
            OtherUserProfileContentView(
                userId: userId,
                userRepository: userRepository,
                showCloseButton: true,
                onDismiss: { dismiss() }
            )
        }
    }
}

// MARK: - Preview

#Preview {
    OtherUserProfileView(
        userId: "test-user-id",
        userRepository: UserRepository(apiClient: APIClient(baseURL: "", authService: AuthService()))
    )
    .environmentObject(NavigationCoordinator())
    .environmentObject(DIContainer())
    .environmentObject(AuthService())
}
