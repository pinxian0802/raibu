//
//  AskRepository.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation

/// 詢問標點 Repository
class AskRepository: AskRepositoryProtocol {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Public Methods
    
    /// 建立詢問標點
    func createAsk(
        center: Coordinate,
        radiusMeters: Int,
        question: String,
        images: [UploadedImage]?
    ) async throws -> Ask {
        let request = CreateAskRequest(
            center: center,
            radiusMeters: radiusMeters,
            question: question,
            images: images?.map { $0.toCreateRequest() }
        )
        
        return try await apiClient.post(.createAsk, body: request)
    }
    
    /// 取得地圖範圍內的詢問標點
    func getMapAsks(
        minLat: Double,
        maxLat: Double,
        minLng: Double,
        maxLng: Double
    ) async throws -> [MapAsk] {
        let response: MapAsksResponse = try await apiClient.get(
            .getMapAsks(minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng)
        )
        return response.asks
    }
    
    /// 取得詢問詳情
    func getAskDetail(id: String) async throws -> Ask {
        return try await apiClient.get(.getAskDetail(id: id))
    }
    
    /// 編輯詢問
    func updateAsk(
        id: String,
        question: String?,
        status: AskStatus?,
        sortedImages: [SortedImageItem]?
    ) async throws {
        let request = UpdateAskRequest(
            question: question,
            status: status,
            sortedImages: sortedImages
        )
        
        let _: Ask = try await apiClient.patch(.updateAsk(id: id), body: request)
    }
    
    /// 標記詢問為已解決
    func markAsResolved(id: String) async throws {
        try await updateAsk(id: id, question: nil, status: .resolved, sortedImages: nil)
    }
    
    /// 刪除詢問
    func deleteAsk(id: String) async throws {
        try await apiClient.delete(.deleteAsk(id: id))
    }
}
