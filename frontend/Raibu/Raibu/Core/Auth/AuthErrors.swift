//
//  AuthErrors.swift
//  Raibu
//
//  Auth error definitions and utilities
//  Extracted from AuthService.swift for better organization
//

import Foundation

// MARK: - Auth Errors

/// 認證相關錯誤
enum AuthError: LocalizedError {
    case invalidResponse
    case authFailed(message: String)
    case signUpFailed(message: String)
    case emailNotVerified
    case emailAlreadyRegistered
    case otpInvalid
    case noRefreshToken
    case refreshFailed
    case resendFailed
    case invalidCallback
    case networkError(String)
    case invalidEmail          // 新增：Email 格式無效
    case invalidPassword       // 新增：密碼格式無效
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "無效的回應"
        case .authFailed(let message):
            return message
        case .signUpFailed(let message):
            return message
        case .emailNotVerified:
            return "請先驗證您的 Email"
        case .emailAlreadyRegistered:
            return "此 Email 已被註冊，請直接登入"
        case .otpInvalid:
            return "驗證碼無效或已過期，請重新獲取"
        case .noRefreshToken:
            return "找不到 Refresh Token"
        case .refreshFailed:
            return "Token 刷新失敗"
        case .resendFailed:
            return "重新發送驗證碼失敗"
        case .invalidCallback:
            return "驗證連結無效"
        case .networkError(let message):
            return message
        case .invalidEmail:
            return "請輸入有效的電子郵件地址"
        case .invalidPassword:
            return "密碼需至少 8 個字元，包含英文和數字"
        }
    }
}

// MARK: - Auth Validation

/// 認證相關驗證工具
enum AuthValidation {
    /// 驗證 Email 格式
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    /// 驗證密碼格式（至少 8 字元，包含英文和數字）
    static func isValidPassword(_ password: String) -> Bool {
        let hasMinimumLength = password.count >= 8
        let hasLetter = password.rangeOfCharacter(from: .letters) != nil
        let hasNumber = password.rangeOfCharacter(from: .decimalDigits) != nil
        return hasMinimumLength && hasLetter && hasNumber
    }
    
    /// 驗證登入表單
    static func validateLoginForm(email: String, password: String) -> AuthError? {
        if email.isEmpty {
            return .authFailed(message: "請輸入電子郵件")
        }
        if !isValidEmail(email) {
            return .invalidEmail
        }
        if password.isEmpty {
            return .authFailed(message: "請輸入密碼")
        }
        return nil
    }
    
    /// 驗證註冊表單
    static func validateSignUpForm(email: String, password: String, confirmPassword: String, displayName: String) -> AuthError? {
        if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .signUpFailed(message: "請輸入顯示名稱")
        }
        if email.isEmpty {
            return .signUpFailed(message: "請輸入電子郵件")
        }
        if !isValidEmail(email) {
            return .invalidEmail
        }
        if password.isEmpty {
            return .signUpFailed(message: "請輸入密碼")
        }
        if !isValidPassword(password) {
            return .invalidPassword
        }
        if password != confirmPassword {
            return .signUpFailed(message: "密碼不一致")
        }
        return nil
    }
}

// MARK: - Network Error Handling

extension AuthError {
    /// 將一般 Error 轉換為 AuthError
    static func from(_ error: Error) -> AuthError {
        if let authError = error as? AuthError {
            return authError
        }
        
        // 處理網路錯誤
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return .networkError("沒有網路連線，請檢查網路設定")
            case .timedOut:
                return .networkError("連線逾時，請稍後再試")
            case .cannotFindHost, .cannotConnectToHost:
                return .networkError("無法連線到伺服器，請稍後再試")
            case .networkConnectionLost:
                return .networkError("網路連線中斷，請重試")
            default:
                return .networkError("網路錯誤：\(urlError.localizedDescription)")
            }
        }
        return .networkError("發生未知錯誤：\(error.localizedDescription)")
    }
}
