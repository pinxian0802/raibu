//
//  RecordRepository.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation

/// 紀錄標點 Repository
class RecordRepository: RecordRepositoryProtocol {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Public Methods
    
    /// 建立紀錄標點
    func createRecord(description: String, images: [UploadedImage]) async throws -> Record {
        let request = CreateRecordRequest(
            description: description,
            images: images.map { $0.toCreateRequest() }
        )
        
        return try await apiClient.post(.createRecord, body: request)
    }
    
    /// 取得地圖範圍內的紀錄圖片
    func getMapRecords(
        minLat: Double,
        maxLat: Double,
        minLng: Double,
        maxLng: Double,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> [MapRecordImage] {
        let response: MapRecordsResponse = try await apiClient.get(
            .getMapRecords(minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng, startDate: startDate, endDate: endDate)
        )
        return response.images
    }
    
    /// 取得紀錄詳情
    func getRecordDetail(id: String) async throws -> Record {
        return try await apiClient.get(.getRecordDetail(id: id))
    }
    
    /// 編輯紀錄
    func updateRecord(
        id: String,
        description: String?,
        sortedImages: [SortedImageItem]
    ) async throws -> Record {
        let request = UpdateRecordRequest(
            description: description,
            sortedImages: sortedImages
        )

        do {
            return try await apiClient.patch(.updateRecord(id: id), body: request)
        } catch is DecodingError {
            // 有些環境下更新 API 會成功但回傳 payload 不完整，fallback 重新抓詳情避免誤判失敗。
            return try await getRecordDetail(id: id)
        }
    }
    
    /// 刪除紀錄
    func deleteRecord(id: String) async throws {
        try await apiClient.delete(.deleteRecord(id: id))
    }
}
