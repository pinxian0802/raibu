//
//  DIContainer.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation
import SwiftUI
import Combine

/// 依賴注入容器 - 管理所有服務的單一實例
class DIContainer: ObservableObject {
    
    // MARK: - Core Services
    let apiClient: APIClient
    let authService: AuthService
    let keychainManager: KeychainManager
    let locationManager: LocationManager
    
    // MARK: - Feature Services
    let uploadService: UploadService
    let photoPickerService: PhotoPickerService
    let clusteringService: ClusteringService
    
    // MARK: - Repositories (Protocol-based for testability)
    lazy var recordRepository: RecordRepository = {
        RecordRepository(apiClient: apiClient)
    }()
    
    lazy var askRepository: AskRepository = {
        AskRepository(apiClient: apiClient)
    }()
    
    lazy var replyRepository: ReplyRepository = {
        ReplyRepository(apiClient: apiClient)
    }()
    
    lazy var userRepository: UserRepository = {
        UserRepository(apiClient: apiClient)
    }()
    
    // MARK: - Configuration
    struct Config {
        /// API Base URL - 根據編譯環境自動切換
        static var baseURL: String {
            #if DEBUG
            // 開發環境：使用本地伺服器
            return "http://localhost:3000/api/v1"
            #else
            // 正式環境：使用正式伺服器
            return "https://api.raibu.app/api/v1"
            #endif
        }
        
        /// 是否為開發環境
        static var isDevelopment: Bool {
            #if DEBUG
            return true
            #else
            return false
            #endif
        }
        
        /// 日誌級別
        static var logLevel: LogLevel {
            #if DEBUG
            return .debug
            #else
            return .error
            #endif
        }
    }
    
    /// 日誌級別
    enum LogLevel {
        case debug
        case info
        case warning
        case error
    }
    
    // MARK: - Initialization
    init() {
        // Initialize core services in dependency order
        self.keychainManager = KeychainManager()
        // 使用全局共享的 AuthService.shared，確保整個 App 使用同一個實例
        self.authService = AuthService.shared
        self.apiClient = APIClient(
            baseURL: Config.baseURL,
            authService: authService
        )
        self.locationManager = LocationManager()
        
        // Initialize feature services
        self.uploadService = UploadService(apiClient: apiClient)
        self.photoPickerService = PhotoPickerService()
        self.clusteringService = ClusteringService()
        
        // 輸出配置資訊（僅開發環境）
        #if DEBUG
        print("🔧 DIContainer initialized")
        print("   - API Base URL: \(Config.baseURL)")
        print("   - Environment: \(Config.isDevelopment ? "Development" : "Production")")
        #endif
    }
}
