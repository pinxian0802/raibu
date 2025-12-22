//
//  AuthService.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation
import SwiftUI
import Combine

/// 認證服務
class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private let keychainManager: KeychainManager
    private(set) var accessToken: String?
    
    // Supabase Auth 配置
    private let supabaseURL = "https://dfpecuyylrbagnwsgyfm.supabase.co"
    private let supabaseAnonKey = "sb_publishable_L4FdiTMZvEsyAh0q1iIcVQ_TsDTK3La"
    
    init(keychainManager: KeychainManager = KeychainManager()) {
        self.keychainManager = keychainManager
    }
    
    // MARK: - Public Methods
    
    /// 檢查當前認證狀態
    func checkAuthStatus() async {
        if let token = keychainManager.getAccessToken() {
            accessToken = token
            
            // 驗證 Token 是否有效
            if await validateToken(token) {
                await MainActor.run {
                    isAuthenticated = true
                }
            } else {
                // Token 無效，清除
                await signOut()
            }
        }
    }
    
    /// 登入
    func signIn(email: String, password: String) async throws {
        let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=password")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body = [
            "email": email,
            "password": password
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(AuthErrorResponse.self, from: data) {
                throw AuthError.authFailed(message: errorResponse.errorDescription ?? errorResponse.message ?? "登入失敗")
            }
            throw AuthError.authFailed(message: "登入失敗")
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        // 儲存 Token
        keychainManager.saveAccessToken(authResponse.accessToken)
        keychainManager.saveRefreshToken(authResponse.refreshToken)
        accessToken = authResponse.accessToken
        
        await MainActor.run {
            currentUser = authResponse.user
            isAuthenticated = true
        }
    }
    
    /// 註冊
    func signUp(email: String, password: String, displayName: String) async throws {
        let url = URL(string: "\(supabaseURL)/auth/v1/signup")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "data": [
                "display_name": displayName
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.signUpFailed
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        keychainManager.saveAccessToken(authResponse.accessToken)
        keychainManager.saveRefreshToken(authResponse.refreshToken)
        accessToken = authResponse.accessToken
        
        await MainActor.run {
            currentUser = authResponse.user
            isAuthenticated = true
        }
    }
    
    /// 登出
    func signOut() async {
        keychainManager.clearTokens()
        accessToken = nil
        
        await MainActor.run {
            currentUser = nil
            isAuthenticated = false
        }
    }
    
    /// 刷新 Token
    func refreshAccessToken() async throws {
        guard let refreshToken = keychainManager.getRefreshToken() else {
            throw AuthError.noRefreshToken
        }
        
        let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=refresh_token")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body = ["refresh_token": refreshToken]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.refreshFailed
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        keychainManager.saveAccessToken(authResponse.accessToken)
        keychainManager.saveRefreshToken(authResponse.refreshToken)
        accessToken = authResponse.accessToken
    }
    
    // MARK: - Private Methods
    
    private func validateToken(_ token: String) async -> Bool {
        let url = URL(string: "\(supabaseURL)/auth/v1/user")!
        
        var request = URLRequest(url: url)
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }
}

// MARK: - Auth Models

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let supabaseUser: SupabaseUser?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case supabaseUser = "user"
    }
    
    /// 轉換為 App 的 User 模型
    var user: User? {
        guard let su = supabaseUser else { return nil }
        return User(
            id: su.id,
            displayName: su.userMetadata?.displayName ?? su.email ?? "使用者",
            avatarUrl: su.userMetadata?.avatarUrl,
            totalViews: nil,
            createdAt: nil
        )
    }
}

/// Supabase Auth 回傳的使用者格式
struct SupabaseUser: Codable {
    let id: String
    let email: String?
    let userMetadata: UserMetadata?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case userMetadata = "user_metadata"
    }
}

struct UserMetadata: Codable {
    let displayName: String?
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
    }
}

struct AuthErrorResponse: Codable {
    let error: String?
    let errorDescription: String?
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
        case message
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidResponse
    case authFailed(message: String)
    case signUpFailed
    case noRefreshToken
    case refreshFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "無效的回應"
        case .authFailed(let message):
            return message
        case .signUpFailed:
            return "註冊失敗"
        case .noRefreshToken:
            return "找不到 Refresh Token"
        case .refreshFailed:
            return "Token 刷新失敗"
        }
    }
}
