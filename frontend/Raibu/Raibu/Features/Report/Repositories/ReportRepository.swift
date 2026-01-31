//
//  ReportRepository.swift
//  raibu
//
//  Created on 2026/01/27.
//

import Foundation

/// 檢舉 Repository
class ReportRepository {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Public Methods
    
    /// 建立檢舉
    func createReport(
        target: ReportTargetType,
        category: ReportCategory,
        reason: String
    ) async throws -> CreateReportResponse {
        let request = CreateReportRequest(
            recordId: target.recordId,
            askId: target.askId,
            replyId: target.replyId,
            reasonCategory: category.rawValue,
            reason: reason
        )
        
        return try await apiClient.post(.createReport, body: request)
    }
    
    /// 檢查是否已檢舉
    func checkReport(target: ReportTargetType) async throws -> CheckReportResponse {
        return try await apiClient.get(
            .checkReport(
                recordId: target.recordId,
                askId: target.askId,
                replyId: target.replyId
            )
        )
    }
    
    /// 撤回檢舉
    func deleteReport(id: String) async throws {
        try await apiClient.delete(.deleteReport(id: id))
    }
}
