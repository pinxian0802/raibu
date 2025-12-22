//
//  CreateRecordViewModel.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation
import SwiftUI
import Combine

/// 建立紀錄視圖模型
class CreateRecordViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var description = ""
    @Published var selectedPhotos: [SelectedPhoto] = []
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var errorMessage: String?
    @Published var isCompleted = false
    
    @Published var showPhotoPicker = false
    
    // MARK: - Dependencies
    
    private let uploadService: UploadService
    private let recordRepository: RecordRepository
    
    // MARK: - Computed Properties
    
    var canSubmit: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedPhotos.isEmpty &&
        !isUploading
    }
    
    var photoCount: Int {
        selectedPhotos.count
    }
    
    // MARK: - Initialization
    
    init(uploadService: UploadService, recordRepository: RecordRepository) {
        self.uploadService = uploadService
        self.recordRepository = recordRepository
    }
    
    // MARK: - Public Methods
    
    /// 設定選取的照片
    func setPhotos(_ photos: [SelectedPhoto]) {
        selectedPhotos = photos
    }
    
    /// 移除照片
    func removePhoto(at index: Int) {
        guard index >= 0 && index < selectedPhotos.count else { return }
        selectedPhotos.remove(at: index)
    }
    
    /// 提交建立紀錄
    func submit() async {
        guard canSubmit else { return }
        
        await MainActor.run {
            isUploading = true
            errorMessage = nil
        }
        
        do {
            // Step 1: 上傳圖片
            let uploadedImages = try await uploadService.uploadPhotos(selectedPhotos, context: .record)
            
            await MainActor.run {
                uploadProgress = 0.8
            }
            
            // Step 2: 建立紀錄
            let _ = try await recordRepository.createRecord(
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                images: uploadedImages
            )
            
            await MainActor.run {
                uploadProgress = 1.0
                isCompleted = true
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isUploading = false
            }
        }
    }
}
