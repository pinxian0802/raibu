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
    
    // MARK: - Repositories
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
        static let baseURL = "http://localhost:3000/api/v1"
        // Production: "https://api.raibu.app/api/v1"
    }
    
    // MARK: - Initialization
    init() {
        // Initialize core services in dependency order
        self.keychainManager = KeychainManager()
        self.authService = AuthService(keychainManager: keychainManager)
        self.apiClient = APIClient(
            baseURL: Config.baseURL,
            authService: authService
        )
        self.locationManager = LocationManager()
        
        // Initialize feature services
        self.uploadService = UploadService(apiClient: apiClient)
        self.photoPickerService = PhotoPickerService()
        self.clusteringService = ClusteringService()
    }
}
