//
//  AuthService.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation
import SwiftUI
import Combine

/// 認證狀態
enum AuthState {
    case unauthenticated
    case awaitingEmailVerification(email: String)
    case awaitingPasswordReset(email: String)
    case awaitingProfileSetup  // 新用戶完善個人資料（設定頭貼）
    case authenticated
}

/// 認證服務
class AuthService: ObservableObject {
    /// 單例實例（全局共用）
    static let shared = AuthService()
    
    @Published var authState: AuthState = .unauthenticated
    @Published var currentUser: User?
    @Published private(set) var isCurrentUserProfileSynced = false
    @Published var isLoading = false
    
    /// 便捷屬性：當前使用者 ID
    var currentUserId: String? {
        return currentUser?.id
    }
    
    /// 便利屬性：是否已認證
    var isAuthenticated: Bool {
        if case .authenticated = authState { return true }
        return false
    }
    
    /// 便利屬性：是否等待 Email 驗證
    var isAwaitingVerification: Bool {
        if case .awaitingEmailVerification = authState { return true }
        return false
    }
    
    /// 等待驗證的 Email（如果有的話）
    var pendingVerificationEmail: String? {
        if case .awaitingEmailVerification(let email) = authState {
            return email
        }
        return nil
    }
    
    private let keychainManager: KeychainManager
    private var accessToken: String?
    
    // MARK: - Test Mode Configuration (DEBUG only)
    #if DEBUG
    /// 測試用 Email 後綴（符合此後綴的 Email 可跳過真實驗證）
    private static let testEmailSuffix = "@test.raibu.app"
    /// 測試用驗證碼
    private static let testOTPCode = "123456"
    
    /// 檢查是否為測試用 Email
    private func isTestEmail(_ email: String) -> Bool {
        return email.lowercased().hasSuffix(Self.testEmailSuffix)
    }
    #endif
    
    init(keychainManager: KeychainManager = KeychainManager()) {
        self.keychainManager = keychainManager
    }
    
    // MARK: - Token Access Methods
    
    /// 取得認證 Headers（封裝 Token，不直接暴露原始值）
    func getAuthorizationHeaders() -> [String: String]? {
        guard let token = accessToken else { return nil }
        return ["Authorization": "Bearer \(token)"]
    }
    
    /// 從 JWT Token 解析過期時間
    private func getTokenExpirationDate(_ token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        
        // JWT payload 是 base64url 格式
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // 補齊 padding
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        
        guard let payloadData = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = json["exp"] as? Double else { return nil }
        
        return Date(timeIntervalSince1970: exp)
    }
    
    /// 檢查 Token 是否快過期（剩餘 < 10 分鐘）
    private func isTokenExpiringSoon(_ token: String) -> Bool {
        guard let expDate = getTokenExpirationDate(token) else { return false }
        return expDate.timeIntervalSinceNow < 600 // 10 分鐘
    }
    
    // MARK: - Public Methods
    
    /// 檢查當前認證狀態
    func checkAuthStatus() async {
        if let token = keychainManager.getAccessToken() {
            accessToken = token
            
            // 檢查 Token 是否快過期（< 10 分鐘），提前刷新
            if isTokenExpiringSoon(token) {
                do {
                    try await refreshAccessToken()
                    #if DEBUG
                    print("♻️ Token 即將過期，已自動刷新")
                    #endif
                } catch {
                    #if DEBUG
                    print("⚠️ Token 刷新失敗：\(error.localizedDescription)")
                    #endif
                    // 刷新失敗不強制登出，讓現有 Token 繼續嘗試
                }
            }
            
            // 驗證 Token 是否有效
            if await validateToken(accessToken ?? token) {
                await MainActor.run {
                    authState = .authenticated
                }
            } else {
                // Token 無效，清除
                await signOut()
            }
        }
    }
    
    /// 登入
    func signIn(email: String, password: String) async throws {
        var request = URLRequest(url: SupabaseConfig.signInURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
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
            // 🔍 Debug: 印出登入錯誤回應
            #if DEBUG
            if let rawJSON = String(data: data, encoding: .utf8) {
                print("❌ Login Error (Status: \(httpResponse.statusCode)): \(rawJSON)")
            }
            #endif
            
            if let errorResponse = try? JSONDecoder().decode(AuthErrorResponse.self, from: data) {
                // 使用統一錯誤處理
                let errorMsg = errorResponse.toLocalizedMessage(fallback: "登入失敗，請稍後再試")
                
                // 特殊處理：Email 未驗證需要特別狀態
                if errorResponse.errorCode == "email_not_confirmed" {
                    throw AuthError.emailNotVerified
                }
                
                throw AuthError.authFailed(message: errorMsg)
            }
            throw AuthError.authFailed(message: "登入失敗，請稍後再試")
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        // 檢查 Email 是否已驗證
        if let user = authResponse.supabaseUser, user.emailConfirmedAt == nil {
            throw AuthError.emailNotVerified
        }
        
        // 儲存 Token
        keychainManager.saveAccessToken(authResponse.accessToken)
        keychainManager.saveRefreshToken(authResponse.refreshToken)
        accessToken = authResponse.accessToken
        
        await MainActor.run {
            currentUser = authResponse.user
            isCurrentUserProfileSynced = false
            authState = .authenticated
        }
    }
    
    /// 註冊（需要 Email 驗證）
    func signUp(email: String, password: String, displayName: String) async throws {
        // 🧪 DEBUG: 測試用 Email 跳過真實註冊
        #if DEBUG
        if isTestEmail(email) {
            print("🧪 [TEST MODE] 使用測試 Email: \(email)")
            print("🧪 [TEST MODE] 跳過 Supabase 註冊，直接進入驗證頁面")
            print("🧪 [TEST MODE] 請使用驗證碼: \(Self.testOTPCode)")
            
            // 模擬短暫延遲
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒
            
            await MainActor.run {
                // 建立測試用 User
                currentUser = User(
                    id: "test-user-\(UUID().uuidString.prefix(8))",
                    displayName: displayName,
                    avatarUrl: nil,
                    totalViews: 0,
                    createdAt: Date()
                )
                isCurrentUserProfileSynced = false
                authState = .awaitingEmailVerification(email: email)
            }
            return
        }
        #endif
        
        var request = URLRequest(url: SupabaseConfig.signUpURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "data": [
                "display_name": displayName
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        // 處理錯誤回應
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(AuthErrorResponse.self, from: data) {
                // 使用統一錯誤處理
                let errorMsg = errorResponse.toLocalizedMessage(fallback: "註冊失敗，請稍後再試")
                
                // 特殊處理：Email 已存在需要特別狀態
                if errorResponse.errorCode == "email_exists" || errorResponse.errorCode == "user_already_exists" {
                    throw AuthError.emailAlreadyRegistered
                }
                
                throw AuthError.signUpFailed(message: errorMsg)
            }
            throw AuthError.signUpFailed(message: "註冊失敗，請稍後再試")
        }
        
        // 🔍 Debug: 印出 Supabase 回傳的原始資料
        #if DEBUG
        if let rawJSON = String(data: data, encoding: .utf8) {
            print("📧 Supabase SignUp Response: \(rawJSON)")
        }
        #endif
        
        // 嘗試解析回應
        // Supabase 在不同情況可能回傳不同格式：
        // 1. 有 access_token 時：{"access_token": "...", "user": {...}}
        // 2. 需要驗證時：直接回傳 user 物件 {"id": "...", "email": "...", "identities": [...]}
        
        // 首先嘗試解析為 SignUpResponse（有 access_token 的格式）
        if let signUpResponse = try? JSONDecoder().decode(SignUpResponse.self, from: data),
           signUpResponse.accessToken != nil {
            // 有 token，直接登入
            if let token = signUpResponse.accessToken, let refreshToken = signUpResponse.refreshToken {
                keychainManager.saveAccessToken(token)
                keychainManager.saveRefreshToken(refreshToken)
                accessToken = token
                
                await MainActor.run {
                    currentUser = signUpResponse.user
                    isCurrentUserProfileSynced = false
                    authState = .authenticated
                }
            }
            return
        }
        
        // 嘗試直接解析為 SupabaseUser（需要驗證的格式）
        let user = try JSONDecoder().decode(SupabaseUser.self, from: data)
        
        // 🔍 檢查是否為「假註冊」（Supabase 回傳成功但使用者已存在）
        // 當 Email 已存在時，identities 會是空陣列 []
        let identities = user.identities ?? []
        if identities.isEmpty {
            print("⚠️ Duplicate email detected: identities is empty")
            throw AuthError.emailAlreadyRegistered
        }
        
        // 需要 Email 驗證
        await MainActor.run {
            authState = .awaitingEmailVerification(email: email)
        }
    }
    
    /// 重新發送 OTP 驗證碼
    func resendOTP(email: String) async throws {
        // 🧪 DEBUG: 測試用 Email 跳過真實發送
        #if DEBUG
        if isTestEmail(email) {
            print("🧪 [TEST MODE] 跳過重新發送 OTP")
            print("🧪 [TEST MODE] 請使用驗證碼: \(Self.testOTPCode)")
            try await Task.sleep(nanoseconds: 500_000_000) // 模擬延遲
            return
        }
        #endif
        
        var request = URLRequest(url: SupabaseConfig.otpURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "email": email,
            "create_user": false  // 不創建新用戶，只發送 OTP
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.resendFailed
        }
    }
    
    /// 驗證 OTP 驗證碼
    func verifyOTP(email: String, token: String) async throws {
        // 🧪 DEBUG: 測試用 Email + 驗證碼跳過真實驗證
        #if DEBUG
        if isTestEmail(email) {
            print("🧪 [TEST MODE] 驗證測試 Email: \(email)")
            
            // 檢查驗證碼是否正確
            if token == Self.testOTPCode {
                print("🧪 [TEST MODE] 驗證碼正確！進入個人資料設定頁面")
                
                // 模擬短暫延遲
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒
                
                await MainActor.run {
                    // 新用戶需要完善個人資料（設定頭貼）
                    authState = .awaitingProfileSetup
                }
                return
            } else {
                print("🧪 [TEST MODE] 驗證碼錯誤！正確驗證碼為: \(Self.testOTPCode)")
                throw AuthError.otpInvalid
            }
        }
        #endif
        
        var request = URLRequest(url: SupabaseConfig.verifyURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "email": email,
            "token": token,
            "type": "signup"  // 註冊驗證類型
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            // 🔍 Debug: 印出錯誤回應
            #if DEBUG
            if let rawJSON = String(data: data, encoding: .utf8) {
                print("❌ OTP Verify Error (Status: \(httpResponse.statusCode)): \(rawJSON)")
            }
            #endif
            
            if let errorResponse = try? JSONDecoder().decode(AuthErrorResponse.self, from: data) {
                // 檢查是否為 OTP 過期或無效
                if errorResponse.errorCode == "otp_expired" || errorResponse.errorCode == "otp_disabled" {
                    throw AuthError.otpInvalid
                }
                
                // 使用統一錯誤處理
                let errorMsg = errorResponse.toLocalizedMessage(fallback: "驗證失敗，請稍後再試")
                throw AuthError.authFailed(message: errorMsg)
            }
            throw AuthError.otpInvalid
        }
        
        // 驗證成功，解析 token
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        // 儲存 Token
        keychainManager.saveAccessToken(authResponse.accessToken)
        keychainManager.saveRefreshToken(authResponse.refreshToken)
        accessToken = authResponse.accessToken
        
        await MainActor.run {
            currentUser = authResponse.user
            isCurrentUserProfileSynced = false
            // 新用戶需要完善個人資料（設定頭貼）
            authState = .awaitingProfileSetup
        }
    }
    
    /// 重新發送驗證信（保留舊方法以便相容）
    func resendVerificationEmail(email: String) async throws {
        try await resendOTP(email: email)
    }
    
    // MARK: - Password Reset
    
    /// 發送密碼重設 OTP 驗證碼（使用 recover endpoint 觸發 Reset Password 模板）
    func sendPasswordResetOTP(email: String) async throws {
        var request = URLRequest(url: SupabaseConfig.recoverURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "email": email
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        // recover endpoint 成功時回傳 200
        if httpResponse.statusCode != 200 {
            // 🔍 Debug: 印出錯誤回應
            #if DEBUG
            if let rawJSON = String(data: data, encoding: .utf8) {
                print("❌ Password Reset Error (Status: \(httpResponse.statusCode)): \(rawJSON)")
            }
            #endif
            
            if let errorResponse = try? JSONDecoder().decode(AuthErrorResponse.self, from: data) {
                // 使用統一錯誤處理
                let errorMsg = errorResponse.toLocalizedMessage(fallback: "發送驗證碼失敗，請稍後再試")
                throw AuthError.authFailed(message: errorMsg)
            }
            throw AuthError.authFailed(message: "發送驗證碼失敗，請稍後再試")
        }
        
        // 成功發送，切換到密碼重設等待狀態
        await MainActor.run {
            authState = .awaitingPasswordReset(email: email)
        }
    }
    
    /// 驗證密碼重設 OTP（第一步：僅驗證）
    /// 成功後回傳 access_token 供後續更新密碼使用
    private var passwordResetAccessToken: String?
    
    func verifyPasswordResetCode(email: String, token: String) async throws {
        var verifyRequest = URLRequest(url: SupabaseConfig.verifyURL)
        verifyRequest.httpMethod = "POST"
        verifyRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        verifyRequest.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let verifyBody: [String: Any] = [
            "email": email,
            "token": token,
            "type": "recovery"  // 密碼重設驗證類型
        ]
        verifyRequest.httpBody = try JSONSerialization.data(withJSONObject: verifyBody)
        
        let (verifyData, verifyResponse) = try await URLSession.shared.data(for: verifyRequest)
        
        guard let httpVerifyResponse = verifyResponse as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        if httpVerifyResponse.statusCode != 200 {
            // 🔍 Debug: 印出錯誤回應
            #if DEBUG
            if let rawJSON = String(data: verifyData, encoding: .utf8) {
                print("❌ Password Reset OTP Error (Status: \(httpVerifyResponse.statusCode)): \(rawJSON)")
            }
            #endif
            
            if let errorResponse = try? JSONDecoder().decode(AuthErrorResponse.self, from: verifyData) {
                // 檢查是否為 OTP 過期或無效
                if errorResponse.errorCode == "otp_expired" || errorResponse.errorCode == "otp_disabled" {
                    throw AuthError.otpInvalid
                }
                
                // 使用統一錯誤處理
                let errorMsg = errorResponse.toLocalizedMessage(fallback: "驗證失敗，請稍後再試")
                throw AuthError.authFailed(message: errorMsg)
            }
            throw AuthError.otpInvalid
        }
        
        // 解析驗證成功後的 access_token 並暫存（只存記憶體，不存 Keychain）
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: verifyData)
        passwordResetAccessToken = authResponse.accessToken
        
        // 🔍 Debug: 印出 access token 供測試用
        #if DEBUG
        print("✅ OTP Verified! Access Token for testing:")
        print("🔑 \(authResponse.accessToken)")
        #endif
        
        // ⚠️ 注意：不儲存到 Keychain！密碼重設完成前不應該持久化 Token
        // 這樣可以避免 App 閃退後使用者被誤認為已登入
    }
    
    /// 更新密碼（第二步：驗證成功後設定新密碼）
    func updatePassword(newPassword: String) async throws {
        guard let token = passwordResetAccessToken ?? accessToken else {
            throw AuthError.authFailed(message: "請先驗證驗證碼")
        }
        
        var updateRequest = URLRequest(url: SupabaseConfig.userURL)
        updateRequest.httpMethod = "PUT"
        updateRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        updateRequest.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        updateRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let updateBody: [String: Any] = [
            "password": newPassword
        ]
        updateRequest.httpBody = try JSONSerialization.data(withJSONObject: updateBody)
        
        let (updateData, updateResponse) = try await URLSession.shared.data(for: updateRequest)
        
        guard let httpUpdateResponse = updateResponse as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        if httpUpdateResponse.statusCode != 200 {
            // 🔍 Debug: 印出錯誤回應
            #if DEBUG
            if let rawJSON = String(data: updateData, encoding: .utf8) {
                print("❌ Password Update Error (Status: \(httpUpdateResponse.statusCode)): \(rawJSON)")
            }
            #endif
            
            // 使用統一錯誤處理
            if let errorResponse = try? JSONDecoder().decode(AuthErrorResponse.self, from: updateData) {
                let errorMsg = errorResponse.toLocalizedMessage(fallback: "更新密碼失敗，請稍後再試")
                throw AuthError.authFailed(message: errorMsg)
            }
            
            throw AuthError.authFailed(message: "更新密碼失敗，請稍後再試")
        }
        
        // 密碼重設成功！
        // 清除所有暫存的 token（不自動登入，讓使用者手動登入）
        passwordResetAccessToken = nil
        accessToken = nil
        keychainManager.clearTokens()
        
        // 不自動登入，由 UI 層處理顯示成功頁面
    }
    
    /// 保留舊方法向後相容（一步完成）
    func verifyPasswordResetOTP(email: String, token: String, newPassword: String) async throws {
        try await verifyPasswordResetCode(email: email, token: token)
        try await updatePassword(newPassword: newPassword)
    }
    
    /// 取消密碼重設（返回登入）
    func cancelPasswordReset() {
        passwordResetAccessToken = nil
        authState = .unauthenticated
    }
    
    // MARK: - Debug: 測試更新密碼 API（不需要走 OTP 流程）
    #if DEBUG
    /// 🧪 測試用：用目前登入用戶的 token 直接測試更新密碼 API
    /// 使用方式：登入後在 Console 呼叫 authService.testUpdatePassword("新密碼")
    @discardableResult
    func testUpdatePassword(_ newPassword: String) async -> String {
        guard let token = accessToken else {
            print("❌ 測試失敗：請先登入")
            return "❌ 測試失敗：請先登入"
        }
        
        print("🧪 開始測試更新密碼 API...")
        print("🔑 使用 Token: \(token.prefix(50))...")
        
        var updateRequest = URLRequest(url: SupabaseConfig.userURL)
        updateRequest.httpMethod = "PUT"
        updateRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        updateRequest.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        updateRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let updateBody: [String: Any] = [
            "password": newPassword
        ]
        
        do {
            updateRequest.httpBody = try JSONSerialization.data(withJSONObject: updateBody)
            let (updateData, updateResponse) = try await URLSession.shared.data(for: updateRequest)
            
            guard let httpResponse = updateResponse as? HTTPURLResponse else {
                print("❌ 無效回應")
                return "❌ 無效回應"
            }
            
            print("📊 Status Code: \(httpResponse.statusCode)")
            
            var resultMsg = "📊 Status Code: \(httpResponse.statusCode)\n"
            
            if let rawJSON = String(data: updateData, encoding: .utf8) {
                print("📝 Response: \(rawJSON)")
                resultMsg += "📝 Response: \(rawJSON)\n\n"
            }
            
            // 嘗試解析錯誤訊息並轉換為中文
            if httpResponse.statusCode != 200 {
                if let errorResponse = try? JSONDecoder().decode(AuthErrorResponse.self, from: updateData) {
                    let localizedMsg = errorResponse.toLocalizedMessage(fallback: "未知錯誤")
                    resultMsg += "🇹🇼 中文訊息: \(localizedMsg)\n"
                }
            }
            
            if httpResponse.statusCode == 200 {
                print("✅ 密碼更新成功！")
                resultMsg = "✅ 密碼更新成功！\n" + resultMsg
            } else if httpResponse.statusCode == 422 {
                print("⚠️ 422 錯誤 - 可能是相同密碼或驗證失敗")
                resultMsg = "⚠️ 422 錯誤\n" + resultMsg
            } else {
                print("❌ 更新失敗")
                resultMsg = "❌ 更新失敗\n" + resultMsg
            }
            
            return resultMsg
        } catch {
            print("❌ 錯誤: \(error.localizedDescription)")
            return "❌ 錯誤: \(error.localizedDescription)"
        }
    }
    #endif
    
    /// 處理 Deep Link 驗證回調
    func handleAuthCallback(url: URL) async throws {
        // Supabase 驗證連結格式：raibu://auth-callback#access_token=xxx&refresh_token=xxx&...
        guard let fragment = url.fragment else {
            throw AuthError.invalidCallback
        }
        
        // 解析 URL fragment 中的參數
        var params: [String: String] = [:]
        for pair in fragment.components(separatedBy: "&") {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                params[parts[0]] = parts[1].removingPercentEncoding
            }
        }
        
        // 檢查是否有錯誤
        if let error = params["error"], let errorDescription = params["error_description"] {
            throw AuthError.authFailed(message: errorDescription.replacingOccurrences(of: "+", with: " "))
        }
        
        // 取得 tokens
        guard let accessToken = params["access_token"],
              let refreshToken = params["refresh_token"] else {
            throw AuthError.invalidCallback
        }
        
        // 儲存 tokens
        keychainManager.saveAccessToken(accessToken)
        keychainManager.saveRefreshToken(refreshToken)
        self.accessToken = accessToken
        
        // 取得使用者資訊
        if await validateToken(accessToken) {
            await MainActor.run {
                authState = .authenticated
            }
        } else {
            throw AuthError.invalidCallback
        }
    }
    
    /// 取消等待驗證狀態（返回登入）
    func cancelVerificationPending() {
        authState = .unauthenticated
    }
    
    /// 完成個人資料設定（設定頭貼後）
    func completeProfileSetup() {
        authState = .authenticated
    }
    
    /// 跳過個人資料設定
    func skipProfileSetup() {
        authState = .authenticated
    }

    /// 同步並快取後端使用者資料（供 UI 直接讀取，避免各頁重複打 API）
    @MainActor
    func cacheCurrentUserProfile(_ user: User) {
        currentUser = user
        isCurrentUserProfileSynced = true
    }
    
    /// 登出
    func signOut() async {
        keychainManager.clearTokens()
        accessToken = nil
        
        await MainActor.run {
            currentUser = nil
            isCurrentUserProfileSynced = false
            authState = .unauthenticated
        }
    }
    
    /// 刷新 Token
    func refreshAccessToken() async throws {
        guard let refreshToken = keychainManager.getRefreshToken() else {
            throw AuthError.noRefreshToken
        }
        
        var request = URLRequest(url: SupabaseConfig.refreshTokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
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
        var request = URLRequest(url: SupabaseConfig.userURL)
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            
            #if DEBUG
            print("🔍 validateToken response status: \(httpResponse.statusCode)")
            if let rawJSON = String(data: data, encoding: .utf8) {
                print("🔍 validateToken response data: \(rawJSON.prefix(500))")
            }
            #endif
            
            if httpResponse.statusCode == 200 {
                // 解析使用者資訊
                let decoder = JSONDecoder()
                if let user = try? decoder.decode(SupabaseUser.self, from: data) {
                    await MainActor.run {
                        self.currentUser = User(
                            id: user.id,
                            displayName: user.userMetadata?.displayName ?? user.email ?? "使用者",
                            avatarUrl: user.userMetadata?.avatarUrl,
                            totalViews: nil,
                            createdAt: nil
                        )
                        self.isCurrentUserProfileSynced = false
                        print("✅ currentUser set: id=\(user.id)")
                    }
                } else {
                    print("⚠️ Failed to decode SupabaseUser from response")
                }
                return true
            }
            return false
        } catch {
            print("❌ validateToken error: \(error)")
            return false
        }
    }
}

// MARK: - Models and Errors are defined in separate files:
// - AuthModels.swift
// - AuthErrors.swift
