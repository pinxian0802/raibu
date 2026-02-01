//
//  AuthModels.swift
//  Raibu
//
//  Auth-related data models
//  Extracted from AuthService.swift for better organization
//

import Foundation

// MARK: - Auth Response Models

/// 認證回應（登入成功後回傳）
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

/// 註冊回應（可能沒有 access_token，表示需要驗證）
struct SignUpResponse: Codable {
    let accessToken: String?
    let refreshToken: String?
    let supabaseUser: SupabaseUser?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case supabaseUser = "user"
    }
    
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

// MARK: - Supabase User Models

/// Supabase Auth 回傳的使用者格式
struct SupabaseUser: Codable {
    let id: String
    let email: String?
    let emailConfirmedAt: String?
    let userMetadata: UserMetadata?
    let identities: [UserIdentity]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case emailConfirmedAt = "email_confirmed_at"
        case userMetadata = "user_metadata"
        case identities
    }
}

/// Supabase 使用者身份資訊
struct UserIdentity: Codable {
    let id: String
    let provider: String
}

/// 使用者 metadata
struct UserMetadata: Codable {
    let displayName: String?
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
    }
}

// MARK: - Auth Error Response

/// Supabase 錯誤回應格式
struct AuthErrorResponse: Codable {
    let error: String?
    let errorDescription: String?
    let message: String?
    let errorCode: String?   // 錯誤代碼 (e.g. "same_password")
    let msg: String?         // 錯誤訊息
    let code: Int?           // HTTP 狀態碼
    
    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
        case message
        case errorCode = "error_code"
        case msg
        case code
    }
}

// MARK: - AuthErrorResponse Extension

extension AuthErrorResponse {
    /// 將 Supabase error_code 轉換為中文錯誤訊息
    /// 參考: https://supabase.com/docs/guides/auth/debugging/error-codes
    func toLocalizedMessage(fallback: String) -> String {
        // 優先檢查 error_code
        if let errorCode = self.errorCode {
            switch errorCode {
            // 登入相關
            case "invalid_credentials":
                return "電子郵件或密碼錯誤"
            case "user_not_found":
                return "此帳號不存在"
            case "email_not_confirmed":
                return "請先驗證您的電子郵件"
            case "user_banned":
                return "此帳號已被停用"
                
            // 註冊相關
            case "email_exists", "user_already_exists":
                return "此電子郵件已被註冊"
            case "weak_password":
                return "密碼強度不足，請使用更複雜的密碼"
            case "signup_disabled":
                return "目前暫停註冊新帳號"
                
            // OTP 相關
            case "otp_expired":
                return "驗證碼已過期，請重新獲取"
            case "otp_disabled":
                return "驗證碼功能已停用"
                
            // 密碼重設相關
            case "same_password":
                return "新密碼不能與舊密碼相同"
            case "reauthentication_needed":
                return "需要重新驗證身份，請重新登入"
                
            // 頻率限制
            case "over_email_send_rate_limit":
                return "發送郵件過於頻繁，請稍後再試"
            case "over_request_rate_limit":
                return "請求過於頻繁，請稍後再試"
                
            default:
                break
            }
        }
        
        // 其他錯誤：使用 fallback 訊息
        return fallback
    }
}
