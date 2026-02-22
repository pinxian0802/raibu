//
//  OtherUserProfileViewModel.swift
//  Raibu
//
//  查看其他用戶個人頁面的 ViewModel
//

import Foundation
import Combine

/// 其他用戶個人頁面視圖模型
@MainActor
class OtherUserProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var profile: UserProfile?
    @Published var userRecords: [Record] = []
    @Published var userAsks: [Ask] = []
    
    // Loading States
    @Published private(set) var isLoading = true
    @Published private(set) var isLoadingRecords = true
    @Published private(set) var isLoadingAsks = false
    
    // Error States
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    
    private let userId: String
    private let userRepository: UserRepository
    
    // MARK: - Initialization
    
    init(userId: String, userRepository: UserRepository) {
        self.userId = userId
        self.userRepository = userRepository
    }
    
    // MARK: - Public Methods
    
    /// 載入用戶資料
    func loadProfile() async {
        isLoading = true
        errorMessage = nil
        
        do {
            profile = try await userRepository.getUserProfileDetail(id: userId)
        } catch is CancellationError {
            #if DEBUG
            print("⚠️ 載入用戶資料被取消")
            #endif
        } catch {
            errorMessage = "載入失敗：\(error.localizedDescription)"
            #if DEBUG
            print("❌ 載入用戶資料錯誤：\(error)")
            #endif
        }
        
        isLoading = false
    }
    
    /// 載入用戶的紀錄列表
    func loadUserRecords() async {
        isLoadingRecords = true
        errorMessage = nil
        
        do {
            userRecords = try await userRepository.getUserRecords(userId: userId, page: 1, limit: 50)
        } catch is CancellationError {
            #if DEBUG
            print("⚠️ 載入紀錄列表被取消")
            #endif
        } catch {
            errorMessage = "載入失敗：\(error.localizedDescription)"
            #if DEBUG
            print("❌ 載入紀錄列表錯誤：\(error)")
            #endif
        }
        
        isLoadingRecords = false
    }
    
    /// 載入用戶的詢問列表
    func loadUserAsks() async {
        isLoadingAsks = true
        errorMessage = nil
        
        do {
            userAsks = try await userRepository.getUserAsks(userId: userId, page: 1, limit: 50)
        } catch is CancellationError {
            #if DEBUG
            print("⚠️ 載入詢問列表被取消")
            #endif
        } catch {
            errorMessage = "載入失敗：\(error.localizedDescription)"
            #if DEBUG
            print("❌ 載入詢問列表錯誤：\(error)")
            #endif
        }
        
        isLoadingAsks = false
    }
    
    /// 刷新所有資料
    func refreshAll() async {
        await loadProfile()
        await loadUserRecords()
    }
}
