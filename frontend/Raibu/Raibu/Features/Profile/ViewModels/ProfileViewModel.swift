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
    @Published private(set) var hasLoadedProfile = false
    @Published private(set) var hasLoadedRecords = false
    @Published private(set) var hasLoadedAsks = false
    
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
        
        // 如果正在載入中
        if isLoadingProfile {
            if forceRefresh {
                // forceRefresh 時，等待當前載入完成
                while isLoadingProfile {
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                }
                // 當前載入完成後，繼續執行新的載入
            } else {
                // 非強制刷新時，直接返回避免重複請求
                return
            }
        }
        
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
        } catch let error as URLError where error.code == .cancelled {
            // 網路請求被取消，不視為錯誤
            #if DEBUG
            print("⚠️ 載入個人資料的網路請求被取消")
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
        
        // 如果正在載入中
        if isLoadingRecords {
            if forceRefresh {
                // forceRefresh 時，等待當前載入完成
                while isLoadingRecords {
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                }
                // 當前載入完成後，繼續執行新的載入
            } else {
                // 非強制刷新時，直接返回避免重複請求
                return
            }
        }
        
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
        } catch let error as URLError where error.code == .cancelled {
            // 網路請求被取消，不視為錯誤
            #if DEBUG
            print("⚠️ 載入紀錄的網路請求被取消")
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
        
        // 如果正在載入中
        if isLoadingAsks {
            if forceRefresh {
                // forceRefresh 時，等待當前載入完成
                while isLoadingAsks {
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                }
                // 當前載入完成後，繼續執行新的載入
            } else {
                // 非強制刷新時，直接返回避免重複請求
                return
            }
        }
        
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
        } catch let error as URLError where error.code == .cancelled {
            // 網路請求被取消，不視為錯誤
            #if DEBUG
            print("⚠️ 載入詢問的網路請求被取消")
            #endif
        } catch {
            #if DEBUG
            print("❌ 載入詢問失敗: \(error.localizedDescription)")
            #endif
        }
        
        isLoadingAsks = false
    }
    
    /// 刷新所有資料（根據當前 tab 決定載入哪些資料）
    /// - Parameter currentTab: 當前選中的 tab (0: 紀錄, 1: 詢問)
    func refreshAll(currentTab: Int) async {
        // 並行載入 profile 和當前 tab 的資料
        async let profileResult: () = loadProfile(forceRefresh: true)
        
        if currentTab == 0 {
            // 載入紀錄
            async let recordsResult: () = loadMyRecords(forceRefresh: true)
            _ = await (profileResult, recordsResult)
        } else {
            // 載入詢問
            async let asksResult: () = loadMyAsks(forceRefresh: true)
            _ = await (profileResult, asksResult)
        }
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
