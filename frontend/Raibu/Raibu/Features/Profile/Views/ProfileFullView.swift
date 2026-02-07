//
//  ProfileFullView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI
import Combine
import Kingfisher

/// 個人頁面視圖
struct ProfileFullView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var container: DIContainer
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @StateObject private var viewModel: ProfileViewModel
    
    @State private var selectedTab = 0
    @State private var showLogoutConfirmation = false
    
    // 詳情 Sheet 狀態
    @State private var selectedDetailItem: DetailSheetItem?
    
    init(userRepository: UserRepository) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(userRepository: userRepository))
    }
    
    var body: some View {
        NavigationView {
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
                // 下拉刷新
                await viewModel.refreshAll()
            }
            .navigationTitle("個人資訊")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showLogoutConfirmation = true
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .confirmationDialog("確定要登出嗎？", isPresented: $showLogoutConfirmation) {
                Button("登出", role: .destructive) {
                    Task {
                        await authService.signOut()
                    }
                }
                Button("取消", role: .cancel) {}
            }
        }
        .onAppear {
            // 首次進入頁面時重置到「我的紀錄」標籤
            selectedTab = 0
            
            // 首次進入頁面時刷新統計資料和紀錄列表
            Task {
                await viewModel.loadProfile(forceRefresh: true)
                await viewModel.loadMyRecords(forceRefresh: true)
            }
        }
        .onChange(of: navigationCoordinator.selectedTab) { _, newTab in
            // 當從其他頁面切換到個人頁面時，刷新資料
            if newTab == 2 {
                selectedTab = 0  // 重置到「我的紀錄」標籤
                Task {
                    await viewModel.loadProfile(forceRefresh: true)
                    await viewModel.loadMyRecords(forceRefresh: true)
                }
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            // Tab 切換時載入對應資料
            Task {
                await loadCurrentTabData()
            }
        }
        .sheet(item: $selectedDetailItem, onDismiss: {
            // 關閉詳情頁後刷新列表
            Task {
                await viewModel.refreshLists()
            }
        }) { item in
            switch item {
            case .record(let recordId, let imageIndex):
                RecordDetailSheetView(
                    recordId: recordId,
                    initialImageIndex: imageIndex,
                    recordRepository: container.recordRepository,
                    replyRepository: container.replyRepository
                )
                .environmentObject(navigationCoordinator)
            case .ask(let askId):
                AskDetailSheetView(
                    askId: askId,
                    askRepository: container.askRepository,
                    replyRepository: container.replyRepository
                )
                .environmentObject(navigationCoordinator)
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadCurrentTabData() async {
        if selectedTab == 0 {
            await viewModel.loadMyRecords()
        } else {
            await viewModel.loadMyAsks()
        }
    }
    
    // MARK: - Profile Header (頭像左邊、資訊右邊的水平排版)
    
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
    
    /// 個人頁面統計項目（簡潔版）
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
            tabButton(title: "我的紀錄", index: 0)
                .frame(width: 80)
            Spacer()
                .frame(width: 24)
            tabButton(title: "我的詢問", index: 1)
                .frame(width: 80)
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
                    .font(.body.weight(selectedTab == index ? .semibold : .regular))
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
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .opacity
                ))
        } else {
            asksGrid
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
        }
    }
    
    private var recordsGrid: some View {
        Group {
            if viewModel.isLoadingRecords && viewModel.myRecords.isEmpty {
                // 載入中骨架屏
                LazyVGrid(columns: gridColumns, spacing: 2) {
                    ForEach(0..<9, id: \.self) { _ in
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
                .padding(.horizontal, 2)
            } else if viewModel.myRecords.isEmpty {
                emptyStateView(
                    icon: "camera",
                    title: "還沒有紀錄",
                    subtitle: "開始分享你的第一個紀錄吧！"
                )
            } else {
                LazyVGrid(columns: gridColumns, spacing: 2) {
                    ForEach(viewModel.myRecords) { record in
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
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.myRecords.count)
    }
    
    private var asksGrid: some View {
        Group {
            if viewModel.isLoadingAsks && viewModel.myAsks.isEmpty {
                // 載入中骨架屏
                LazyVGrid(columns: gridColumns, spacing: 2) {
                    ForEach(0..<9, id: \.self) { _ in
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
                .padding(.horizontal, 2)
            } else if viewModel.myAsks.isEmpty {
                emptyStateView(
                    icon: "questionmark.circle",
                    title: "還沒有詢問",
                    subtitle: "在地圖上長按開始提問！"
                )
            } else {
                LazyVGrid(columns: gridColumns, spacing: 2) {
                    ForEach(viewModel.myAsks) { ask in
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
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.5))
                .cornerRadius(4)
                .padding(6)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    /// 詢問九宮格項目（問號圖示 + 左下角愛心數）
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
                .background(Color.black.opacity(0.5))
                .cornerRadius(4)
                .padding(6)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
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
    .environmentObject(AuthService())
}
