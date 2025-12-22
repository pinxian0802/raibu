//
//  APIError.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation

/// API 錯誤類型
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidArgument(message: String)
    case unauthenticated
    case permissionDenied
    case notFound
    case resourceExhausted(message: String)
    case internalError
    case uploadFailed
    case unknown(statusCode: Int)
    
    /// 從後端錯誤回應建立
    init(from response: ErrorResponse) {
        switch response.error.code {
        case "INVALID_ARGUMENT":
            self = .invalidArgument(message: response.error.message)
        case "UNAUTHENTICATED":
            self = .unauthenticated
        case "PERMISSION_DENIED":
            self = .permissionDenied
        case "NOT_FOUND":
            self = .notFound
        case "RESOURCE_EXHAUSTED":
            self = .resourceExhausted(message: response.error.message)
        case "INTERNAL":
            self = .internalError
        default:
            self = .internalError
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無效的 URL"
        case .invalidResponse:
            return "無效的回應"
        case .invalidArgument(let message):
            return message
        case .unauthenticated:
            return "請先登入"
        case .permissionDenied:
            return "沒有權限執行此操作"
        case .notFound:
            return "找不到資源"
        case .resourceExhausted(let message):
            return message
        case .internalError:
            return "伺服器發生錯誤，請稍後再試"
        case .uploadFailed:
            return "圖片上傳失敗"
        case .unknown(let statusCode):
            return "未知錯誤 (狀態碼: \(statusCode))"
        }
    }
}

/// 後端錯誤回應格式
struct ErrorResponse: Codable {
    let error: ErrorDetail
    
    struct ErrorDetail: Codable {
        let code: String
        let message: String
        let details: [String: String]?
    }
}
