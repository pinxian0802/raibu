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
                    // 個人資料卡片
                    profileCard
                    
                    // 統計資料
                    statsSection
                    
                    // 標籤切換
                    tabSection
                    
                    // 列表內容
                    listContent
                }
                .padding(.vertical)
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
        .task {
            await viewModel.loadProfile()
        }
        .sheet(item: $selectedDetailItem, onDismiss: {
            // 關閉詳情頁後重新載入列表，確保愛心數量等資料同步
            Task {
                await viewModel.loadMyRecords()
                await viewModel.loadMyAsks()
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
    
    // MARK: - Profile Card
    
    private var profileCard: some View {
        VStack(spacing: 16) {
            // 頭像
            KFImage(URL(string: viewModel.profile?.avatarUrl ?? ""))
                .placeholder {
                    Circle()
                        .fill(Color(.systemGray4))
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
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
            
            // 名稱
            Text(viewModel.profile?.displayName ?? "使用者")
                .font(.title2.weight(.semibold))
            
            // 加入時間
            if let createdAt = viewModel.profile?.createdAt {
                Text("加入於 \(formatDate(createdAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        HStack(spacing: 0) {
            statItem(
                value: viewModel.profile?.totalRecords ?? 0,
                label: "紀錄",
                color: .blue
            )
            
            Divider()
                .frame(height: 40)
            
            statItem(
                value: viewModel.profile?.totalAsks ?? 0,
                label: "詢問",
                color: .orange
            )
            
            Divider()
                .frame(height: 40)
            
            statItem(
                value: viewModel.profile?.totalViews ?? 0,
                label: "被觀看",
                color: .green
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func statItem(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2.weight(.bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Tab Section
    
    private var tabSection: some View {
        HStack(spacing: 0) {
            tabButton(title: "我的紀錄", index: 0)
            tabButton(title: "我的詢問", index: 1)
        }
        .padding(4)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private func tabButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedTab = index
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(selectedTab == index ? .white : .primary)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    selectedTab == index ?
                    (index == 0 ? Color.blue : Color.orange) : Color.clear
                )
                .cornerRadius(8)
        }
    }
    
    // MARK: - List Content
    
    @ViewBuilder
    private var listContent: some View {
        if selectedTab == 0 {
            recordsList
        } else {
            asksList
        }
    }
    
    private var recordsList: some View {
        VStack(spacing: 12) {
            if viewModel.isLoadingRecords {
                ForEach(0..<3, id: \.self) { _ in
                    RecordRowSkeleton()
                }
            } else if viewModel.myRecords.isEmpty {
                emptyStateView(
                    icon: "camera",
                    title: "還沒有紀錄",
                    subtitle: "開始分享你的第一個紀錄吧！"
                )
            } else {
                ForEach(viewModel.myRecords) { record in
                    Button {
                        // 從個人頁面進入時從第一張圖片開始
                        selectedDetailItem = .record(id: record.id, imageIndex: 0)
                    } label: {
                        recordRow(record)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
        .task {
            await viewModel.loadMyRecords()
        }
    }
    
    private var asksList: some View {
        VStack(spacing: 12) {
            if viewModel.isLoadingAsks {
                ForEach(0..<3, id: \.self) { _ in
                    AskRowSkeleton()
                }
            } else if viewModel.myAsks.isEmpty {
                emptyStateView(
                    icon: "questionmark.circle",
                    title: "還沒有詢問",
                    subtitle: "在地圖上長按開始提問！"
                )
            } else {
                ForEach(viewModel.myAsks) { ask in
                    Button {
                        selectedDetailItem = .ask(id: ask.id)
                    } label: {
                        askRow(ask)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
        .task {
            await viewModel.loadMyAsks()
        }
    }
    
    // MARK: - Row Views
    
    private func recordRow(_ record: Record) -> some View {
        HStack(spacing: 12) {
            SquareThumbnailView(
                url: record.mainImageUrl ?? "",
                size: 60
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(record.description)
                    .font(.subheadline)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    Label("\(record.likeCount)", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("\(record.viewCount)", systemImage: "eye.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5)
    }
    
    private func askRow(_ ask: Ask) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "questionmark")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(ask.question)
                    .font(.subheadline)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    Text(ask.status == .active ? "進行中" : "已解決")
                        .font(.caption)
                        .foregroundColor(ask.status == .active ? .green : .secondary)
                    
                    Label("\(ask.likeCount)", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5)
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

// MARK: - Profile ViewModel

class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var myRecords: [Record] = []
    @Published var myAsks: [Ask] = []
    @Published var isLoading = false
    @Published var isLoadingRecords = false
    @Published var isLoadingAsks = false
    @Published var errorMessage: String?
    
    private let userRepository: UserRepository
    
    init(userRepository: UserRepository) {
        self.userRepository = userRepository
    }
    
    func loadProfile() async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let loadedProfile = try await userRepository.getMe()
            await MainActor.run {
                profile = loadedProfile
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func loadMyRecords() async {
        await MainActor.run {
            isLoadingRecords = true
        }
        
        do {
            let records = try await userRepository.getMyRecords()
            await MainActor.run {
                myRecords = records
                isLoadingRecords = false
            }
        } catch {
            await MainActor.run {
                isLoadingRecords = false
            }
        }
    }
    
    func loadMyAsks() async {
        await MainActor.run {
            isLoadingAsks = true
        }
        
        do {
            let asks = try await userRepository.getMyAsks()
            await MainActor.run {
                myAsks = asks
                isLoadingAsks = false
            }
        } catch {
            await MainActor.run {
                isLoadingAsks = false
            }
        }
    }
}

#Preview {
    ProfileFullView(
        userRepository: UserRepository(apiClient: APIClient(baseURL: "", authService: AuthService()))
    )
    .environmentObject(AuthService())
}
