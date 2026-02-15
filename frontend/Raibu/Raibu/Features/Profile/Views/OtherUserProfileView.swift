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
    @EnvironmentObject var detailSheetRouter: DetailSheetRouter
    @StateObject private var viewModel: OtherUserProfileViewModel
    
    let userId: String
    
    /// 是否顯示左上角關閉按鈕（用於獨立 sheet 模式）
    let showCloseButton: Bool
    
    @State private var selectedTab = 0
    
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
        Group {
            if viewModel.isLoading && viewModel.profile == nil {
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
                            value: viewModel.profile?.totalRecords ?? viewModel.userRecords.count,
                            label: "紀錄"
                        )
                        .frame(maxWidth: .infinity)
                        
                        statSeparator
                        
                        profileStatItem(
                            value: viewModel.profile?.totalAsks ?? viewModel.userAsks.count,
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
    
    /// 他人頁面頭部骨架屏（與個人頁一致）
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
                        ShimmerBox(width: 40, height: 16)
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
            if viewModel.isLoadingRecords && viewModel.userRecords.isEmpty {
                LazyVGrid(columns: gridColumns, spacing: 2) {
                    ForEach(0..<9, id: \.self) { _ in
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
                .padding(.horizontal, 2)
            } else if viewModel.userRecords.isEmpty {
                emptyStateView(
                    icon: "camera",
                    title: "還沒有紀錄",
                    subtitle: "這位使用者還沒發布紀錄。"
                )
            } else {
                LazyVGrid(columns: gridColumns, spacing: 2) {
                    ForEach(viewModel.userRecords) { record in
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
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.userRecords.count)
    }
    
    private var asksGrid: some View {
        Group {
            if viewModel.isLoadingAsks && viewModel.userAsks.isEmpty {
                LazyVGrid(columns: gridColumns, spacing: 2) {
                    ForEach(0..<9, id: \.self) { _ in
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
                .padding(.horizontal, 2)
            } else if viewModel.userAsks.isEmpty {
                emptyStateView(
                    icon: "questionmark.circle",
                    title: "還沒有詢問",
                    subtitle: "這位使用者還沒提出詢問。"
                )
            } else {
                LazyVGrid(columns: gridColumns, spacing: 2) {
                    ForEach(viewModel.userAsks) { ask in
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
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.userAsks.count)
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
                .background(Color.black.opacity(0.5))
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
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.5))
                .cornerRadius(4)
                .padding(6)
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
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
    .environmentObject(DetailSheetRouter())
    .environmentObject(DIContainer())
    .environmentObject(AuthService())
}
