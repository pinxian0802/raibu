//
//  ReportViewModel.swift
//  raibu
//
//  Created on 2026/01/27.
//

import Foundation
import SwiftUI
import Combine

/// 檢舉 ViewModel
@MainActor
class ReportViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var selectedCategory: ReportCategory?
    @Published var reason: String = ""
    @Published var isSubmitting = false
    @Published var hasReported = false
    @Published var showSuccess = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let repository: ReportRepository
    private let target: ReportTargetType
    
    // MARK: - Computed Properties
    
    var canSubmit: Bool {
        selectedCategory != nil && !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }
    
    // MARK: - Init
    
    init(target: ReportTargetType, apiClient: APIClient) {
        self.target = target
        self.repository = ReportRepository(apiClient: apiClient)
    }
    
    // MARK: - Public Methods
    
    /// 檢查是否已檢舉過
    func checkIfReported() async {
        do {
            let response = try await repository.checkReport(target: target)
            hasReported = response.hasReported
        } catch {
            print("Check report error: \(error)")
        }
    }
    
    /// 提交檢舉
    func submitReport() async {
        guard let category = selectedCategory else {
            errorMessage = "請選擇檢舉原因"
            return
        }
        
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReason.isEmpty else {
            errorMessage = "請輸入詳細說明"
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        do {
            _ = try await repository.createReport(
                target: target,
                category: category,
                reason: trimmedReason
            )
            showSuccess = true
            hasReported = true
        } catch let error as APIError {
            // 顯示後端回傳的錯誤訊息
            print("❌ Report error: \(error)")
            errorMessage = error.errorDescription ?? "檢舉失敗，請稍後再試"
        } catch {
            print("❌ Report unknown error: \(error)")
            errorMessage = "檢舉失敗，請稍後再試"
        }
        
        isSubmitting = false
    }
    
    /// 重置表單
    func reset() {
        selectedCategory = nil
        reason = ""
        errorMessage = nil
        showSuccess = false
    }
}
