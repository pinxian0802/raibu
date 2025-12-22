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
    
    /// 發送 DELETE 請求
    func delete(_ endpoint: APIEndpoint) async throws {
        let request = try buildRequest(for: endpoint, method: "DELETE")
        try await executeWithoutResponse(request)
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
        
        // 注入 Auth Token
        if let token = authService.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
    
    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // 處理錯誤狀態碼
        if !(200...299).contains(httpResponse.statusCode) {
            throw try handleErrorResponse(data: data, statusCode: httpResponse.statusCode)
        }
        
        return try decoder.decode(T.self, from: data)
    }
    
    private func executeWithoutResponse(_ request: URLRequest) async throws {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
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
