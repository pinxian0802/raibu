//
//  APIClient.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation

/// HTTP 請求封裝
class APIClient {
    private let baseURL: String
    private let authService: AuthService
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    init(baseURL: String, authService: AuthService) {
        self.baseURL = baseURL
        self.authService = authService
        self.session = URLSession.shared
        
        // 配置 JSON 解碼器
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // 配置 JSON 編碼器
        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - Public Methods
    
    /// 發送 GET 請求
    func get<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let request = try buildRequest(for: endpoint, method: "GET")
        return try await execute(request)
    }
    
    /// 發送 POST 請求
    func post<T: Decodable, B: Encodable>(_ endpoint: APIEndpoint, body: B) async throws -> T {
        var request = try buildRequest(for: endpoint, method: "POST")
        request.httpBody = try encoder.encode(body)
        return try await execute(request)
    }
    
    /// 發送 POST 請求 (無回傳)
    func post<B: Encodable>(_ endpoint: APIEndpoint, body: B) async throws {
        var request = try buildRequest(for: endpoint, method: "POST")
        request.httpBody = try encoder.encode(body)
        try await executeWithoutResponse(request)
    }
    
    /// 發送 PATCH 請求
    func patch<T: Decodable, B: Encodable>(_ endpoint: APIEndpoint, body: B) async throws -> T {
        var request = try buildRequest(for: endpoint, method: "PATCH")
        request.httpBody = try encoder.encode(body)
        return try await execute(request)
    }
    
    /// 發送 DELETE 請求 (無回傳)
    func delete(_ endpoint: APIEndpoint) async throws {
        let request = try buildRequest(for: endpoint, method: "DELETE")
        try await executeWithoutResponse(request)
    }
    
    /// 發送 DELETE 請求 (有回傳)
    func delete<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let request = try buildRequest(for: endpoint, method: "DELETE")
        return try await execute(request)
    }
    
    /// 直接上傳至 Presigned URL (不經過 baseURL)
    func uploadToPresignedURL(data: Data, url: URL, contentType: String) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.uploadFailed
        }
    }
    
    // MARK: - Private Methods
    
    private func buildRequest(for endpoint: APIEndpoint, method: String) throws -> URLRequest {
        let url = try endpoint.url(baseURL: baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 注入 Auth Token（使用封裝方法，不直接存取 Token）
        if let headers = authService.getAuthorizationHeaders() {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        return request
    }
    
    private func execute<T: Decodable>(_ request: URLRequest, isRetry: Bool = false) async throws -> T {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // 處理 401 錯誤：嘗試刷新 Token 後重試
        if httpResponse.statusCode == 401 && !isRetry {
            do {
                try await authService.refreshAccessToken()
                // 重建請求（使用新的 Token）
                var newRequest = request
                if let headers = authService.getAuthorizationHeaders() {
                    for (key, value) in headers {
                        newRequest.setValue(value, forHTTPHeaderField: key)
                    }
                }
                return try await execute(newRequest, isRetry: true)
            } catch {
                #if DEBUG
                print("⚠️ Token 刷新失敗，無法重試請求：\(error.localizedDescription)")
                #endif
                // 刷新失敗，拋出原始 401 錯誤
                throw try handleErrorResponse(data: data, statusCode: httpResponse.statusCode)
            }
        }
        
        // 處理其他錯誤狀態碼
        if !(200...299).contains(httpResponse.statusCode) {
            throw try handleErrorResponse(data: data, statusCode: httpResponse.statusCode)
        }
        
        return try decoder.decode(T.self, from: data)
    }
    
    private func executeWithoutResponse(_ request: URLRequest, isRetry: Bool = false) async throws {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // 處理 401 錯誤：嘗試刷新 Token 後重試
        if httpResponse.statusCode == 401 && !isRetry {
            do {
                try await authService.refreshAccessToken()
                var newRequest = request
                if let headers = authService.getAuthorizationHeaders() {
                    for (key, value) in headers {
                        newRequest.setValue(value, forHTTPHeaderField: key)
                    }
                }
                return try await executeWithoutResponse(newRequest, isRetry: true)
            } catch {
                #if DEBUG
                print("⚠️ Token 刷新失敗，無法重試請求：\(error.localizedDescription)")
                #endif
                throw try handleErrorResponse(data: data, statusCode: httpResponse.statusCode)
            }
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            throw try handleErrorResponse(data: data, statusCode: httpResponse.statusCode)
        }
    }
    
    private func handleErrorResponse(data: Data, statusCode: Int) throws -> APIError {
        if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
            return APIError(from: errorResponse)
        }
        return APIError.unknown(statusCode: statusCode)
    }
}
