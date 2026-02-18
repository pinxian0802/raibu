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
    @EnvironmentObject var detailSheetRouter: DetailSheetRouter
    @StateObject private var viewModel: ProfileViewModel
    
    @State private var selectedTab = 0
    @State private var showLogoutConfirmation = false
    @State private var showMoreOptions = false
    init(userRepository: UserRepository) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(userRepository: userRepository))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 個人資料區塊（頭像 + 名字 + 統計）
                    profileHeader
                    
                    VStack(spacing: 2) {
                        // 標籤切換
                        tabSection
                        
                        // 列表內容
                        listContent
                    }
                }
                .padding(.vertical)
            }
            .refreshable {
                // 下拉刷新：只載入 profile 和當前 tab 的資料
                await viewModel.refreshAll(currentTab: selectedTab)
            }
            .navigationTitle("個人資訊")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showLogoutConfirmation = true
                        } label: {
                            Label("登出", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
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
                selectedTab = 0  // 重置到「我的紀錄」標籤
                
                Task {
                    // 背景更新資料（並行執行）
                    async let profileTask: () = viewModel.loadProfile(forceRefresh: true)
                    async let recordsTask: () = viewModel.loadMyRecords(forceRefresh: true)
                    _ = await (profileTask, recordsTask)
                }
            }
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            // 只有當 tab 真正改變時才載入
            guard oldTab != newTab else { return }
            
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
    
    // MARK: - Profile Header (頭像左邊、資訊右邊的水平排版)
    
    private var profileHeader: some View {
        Group {
            if !viewModel.hasLoadedProfile {
                profileHeaderSkeleton
                    .transition(.opacity)
            } else {
                VStack(spacing: 36) {
                    // 上方：頭像 + 名字 (名片樣式)
                    HStack(spacing: 16) {
                        // 頭像
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
                        
                        // 名稱與描述
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.profile?.displayName ?? "使用者")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            
                            if let bio = viewModel.profile?.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(20)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    // 下方：統計數據
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
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
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
        .padding(.vertical, 20)
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
                // 載入完成且為空
                emptyStateView(
                    icon: "questionmark.circle",
                    title: "還沒有詢問",
                    subtitle: "在地圖上長按開始提問！"
                )
            } else {
                // 載入完成且有資料
                LazyVGrid(columns: gridColumns, spacing: 2) {
                    ForEach(viewModel.myAsks) { ask in
                        Button {
                            detailSheetRouter.open(.ask(id: ask.id))
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
    
    /// 詢問九宮格項目（問號圖示 + 左下角愛心數）
    private func askGridItem(_ ask: Ask) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // 背景
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.brandOrange.opacity(0.3), Color.brandOrange.opacity(0.1)],
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
                            .foregroundColor(.brandOrange)
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
    .environmentObject(DIContainer())
    .environmentObject(NavigationCoordinator())
    .environmentObject(DetailSheetRouter())
    .environmentObject(AuthService())
}
