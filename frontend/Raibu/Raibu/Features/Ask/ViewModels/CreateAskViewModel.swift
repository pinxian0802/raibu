//
//  CreateAskViewModel.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation
import CoreLocation
import Combine

/// 建立詢問視圖模型
class CreateAskViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var center: CLLocationCoordinate2D
    @Published var radiusMeters: Int = 500
    @Published var question = ""
    @Published var selectedPhotos: [SelectedPhoto] = []
    
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var errorMessage: String?
    @Published var isCompleted = false
    
    @Published var showPhotoPicker = false
    
    // MARK: - Configuration
    
    let radiusOptions = [100, 500, 1000]  // 公尺
    
    // MARK: - Dependencies
    
    private let uploadService: UploadService
    private let askRepository: AskRepository
    
    // MARK: - Computed Properties
    
    var canSubmit: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isUploading
    }
    
    var radiusText: String {
        if radiusMeters >= 1000 {
            return "\(radiusMeters / 1000) 公里"
        }
        return "\(radiusMeters) 公尺"
    }
    
    // MARK: - Initialization
    
    init(
        initialLocation: CLLocationCoordinate2D,
        uploadService: UploadService,
        askRepository: AskRepository
    ) {
        self.center = initialLocation
        self.uploadService = uploadService
        self.askRepository = askRepository
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
    
    /// 提交建立詢問
    func submit() async {
        guard canSubmit else { return }
        
        await MainActor.run {
            isUploading = true
            errorMessage = nil
        }
        
        do {
            var uploadedImages: [UploadedImage]?
            
            // 如果有照片，先上傳
            if !selectedPhotos.isEmpty {
                uploadedImages = try await uploadService.uploadPhotos(selectedPhotos, context: .ask)
            }
            
            await MainActor.run {
                uploadProgress = 0.8
            }
            
            // 建立詢問
            let _ = try await askRepository.createAsk(
                center: Coordinate(lat: center.latitude, lng: center.longitude),
                radiusMeters: radiusMeters,
                question: question.trimmingCharacters(in: .whitespacesAndNewlines),
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
