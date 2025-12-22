//
//  PhotoPickerViewModel.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation
import Photos
import SwiftUI
import Combine

/// 相簿選擇器視圖模型
class PhotoPickerViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var photos: [SelectablePhoto] = []
    @Published var selectedPhotos: [SelectablePhoto] = []  // 按選取順序
    @Published var isLoading = false
    @Published var showMaxLimitToast = false
    @Published var dateRange: DateRangeOption = .oneWeek
    
    // MARK: - Configuration
    
    let requireGPS: Bool
    let maxSelection: Int
    
    // MARK: - Dependencies
    
    private let photoPickerService: PhotoPickerService
    
    // MARK: - Initialization
    
    init(
        photoPickerService: PhotoPickerService,
        requireGPS: Bool = false,
        maxSelection: Int = 10
    ) {
        self.photoPickerService = photoPickerService
        self.requireGPS = requireGPS
        self.maxSelection = maxSelection
    }
    
    // MARK: - Public Methods
    
    /// 載入照片
    func loadPhotos() async {
        await MainActor.run {
            isLoading = true
        }
        
        let assets = await photoPickerService.fetchPhotos(
            requireGPS: requireGPS,
            dateRange: dateRange
        )
        
        let selectablePhotos = assets.map { SelectablePhoto(asset: $0) }
        
        await MainActor.run {
            photos = selectablePhotos
            isLoading = false
        }
    }
    
    /// 切換時間範圍
    func changeDateRange(to range: DateRangeOption) async {
        dateRange = range
        await loadPhotos()
    }
    
    /// 選取/取消選取照片
    func toggleSelection(_ photo: SelectablePhoto) {
        if let index = selectedPhotos.firstIndex(of: photo) {
            // 取消選取 -> 後續號碼自動遞補
            selectedPhotos.remove(at: index)
        } else if selectedPhotos.count < maxSelection {
            // 新增選取
            selectedPhotos.append(photo)
        } else {
            // 已達上限 -> 顯示 Toast
            showMaxLimitToast = true
            
            // 自動隱藏
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.showMaxLimitToast = false
            }
        }
    }
    
    /// 取得照片的選取編號 (1-based)
    func selectionNumber(for photo: SelectablePhoto) -> Int? {
        guard let index = selectedPhotos.firstIndex(of: photo) else { return nil }
        return index + 1
    }
    
    /// 是否已選取該照片
    func isSelected(_ photo: SelectablePhoto) -> Bool {
        selectedPhotos.contains(photo)
    }
    
    /// 是否應該顯示為禁用狀態
    func isDisabled(_ photo: SelectablePhoto) -> Bool {
        !isSelected(photo) && selectedPhotos.count >= maxSelection
    }
    
    /// 清除所有選取
    func clearSelection() {
        selectedPhotos.removeAll()
    }
    
    /// 載入選取照片的完整資料
    func loadSelectedPhotosData() async throws -> [SelectedPhoto] {
        return try await photoPickerService.loadPhotosData(for: selectedPhotos.map { $0.asset })
    }
}
