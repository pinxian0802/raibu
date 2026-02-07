//
//  ProfileViewModel.swift
//  Raibu
//
//  Profile page view model - handles user data loading and state management
//

import Foundation
import Combine

/// 個人頁面視圖模型
@MainActor
class ProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var profile: UserProfile?
    @Published var myRecords: [Record] = []
    @Published var myAsks: [Ask] = []
    
    // Loading States
    @Published private(set) var isLoadingProfile = false
    @Published private(set) var isLoadingRecords = false
    @Published private(set) var isLoadingAsks = false
    
    // Error States
    @Published var errorMessage: String?
    
    // Data Loaded Flags (避免重複載入)
    private var hasLoadedProfile = false
    private var hasLoadedRecords = false
    private var hasLoadedAsks = false
    
    // MARK: - Computed Properties
    
    var isLoading: Bool {
        isLoadingProfile
    }
    
    // MARK: - Dependencies
    
    private let userRepository: UserRepository
    
    // MARK: - Initialization
    
    init(userRepository: UserRepository) {
        self.userRepository = userRepository
    }
    
    // MARK: - Public Methods
    
    /// 載入個人資料（帶快取檢查）
    func loadProfile(forceRefresh: Bool = false) async {
        // 如果已載入且不強制刷新，跳過
        guard !hasLoadedProfile || forceRefresh else { return }
        
        isLoadingProfile = true
        errorMessage = nil
        
        do {
            let loadedProfile = try await userRepository.getMe()
            profile = loadedProfile
            hasLoadedProfile = true
        } catch is CancellationError {
            // Task 被取消，不視為錯誤
            #if DEBUG
            print("⚠️ 載入個人資料被取消")
            #endif
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoadingProfile = false
    }
    
    /// 載入我的紀錄（帶快取檢查）
    func loadMyRecords(forceRefresh: Bool = false) async {
        // 如果已載入且不強制刷新，跳過
        guard !hasLoadedRecords || forceRefresh else { return }
        
        isLoadingRecords = true
        
        do {
            let records = try await userRepository.getMyRecords()
            myRecords = records
            hasLoadedRecords = true
        } catch is CancellationError {
            // Task 被取消，不視為錯誤
            #if DEBUG
            print("⚠️ 載入紀錄被取消")
            #endif
        } catch {
            #if DEBUG
            print("❌ 載入紀錄失敗: \(error.localizedDescription)")
            #endif
        }
        
        isLoadingRecords = false
    }
    
    /// 載入我的詢問（帶快取檢查）
    func loadMyAsks(forceRefresh: Bool = false) async {
        // 如果已載入且不強制刷新，跳過
        guard !hasLoadedAsks || forceRefresh else { return }
        
        isLoadingAsks = true
        
        do {
            let asks = try await userRepository.getMyAsks()
            myAsks = asks
            hasLoadedAsks = true
        } catch is CancellationError {
            // Task 被取消，不視為錯誤
            #if DEBUG
            print("⚠️ 載入詢問被取消")
            #endif
        } catch {
            #if DEBUG
            print("❌ 載入詢問失敗: \(error.localizedDescription)")
            #endif
        }
        
        isLoadingAsks = false
    }
    
    /// 刷新所有資料
    func refreshAll() async {
        // 順序載入避免 Task 被取消時的競爭條件
        await loadProfile(forceRefresh: true)
        await loadMyRecords(forceRefresh: true)
        await loadMyAsks(forceRefresh: true)
    }
    
    /// 刷新列表與統計資料（用於詳情頁關閉後）
    func refreshLists() async {
        // 同時刷新 profile 以更新統計數據（紀錄數、詢問數、觀看數、愛心數）
        await loadProfile(forceRefresh: true)
        await loadMyRecords(forceRefresh: true)
        await loadMyAsks(forceRefresh: true)
    }
    
    /// 重置所有載入狀態（用於登出後）
    func reset() {
        profile = nil
        myRecords = []
        myAsks = []
        hasLoadedProfile = false
        hasLoadedRecords = false
        hasLoadedAsks = false
        errorMessage = nil
    }
}
