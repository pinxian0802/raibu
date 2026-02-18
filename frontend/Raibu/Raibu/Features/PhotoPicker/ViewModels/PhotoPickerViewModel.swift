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

enum PhotoDateShortcut: String, CaseIterable {
    case today = "今天"
    case sevenDays = "7 天"
    case oneMonth = "1 個月"
    case thisYear = "今年"
    case custom = "自訂"

    var dayOffset: Int {
        switch self {
        case .today:
            return 0
        case .sevenDays:
            return 6
        case .oneMonth:
            return 29
        case .thisYear, .custom:
            return 0
        }
    }
}

/// 相簿選擇器視圖模型
class PhotoPickerViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var photos: [SelectablePhoto] = []
    @Published var selectedPhotos: [SelectablePhoto] = []  // 按選取順序
    @Published var isLoading = false
    @Published var showMaxLimitToast = false
    @Published var startDate: Date
    @Published var endDate: Date
    @Published var activeShortcut: PhotoDateShortcut? = .sevenDays
    
    // MARK: - Configuration
    
    let requireGPS: Bool
    let maxSelection: Int
    
    // MARK: - Dependencies
    
    private let photoPickerService: PhotoPickerService
    private let initialSelectedAssetIDs: [String]
    private var hasRestoredInitialSelection = false
    
    // MARK: - Initialization
    
    init(
        photoPickerService: PhotoPickerService,
        requireGPS: Bool = false,
        maxSelection: Int = 10,
        initialSelectedAssetIDs: [String] = []
    ) {
        let now = Date()
        let defaultStart = Calendar.current.date(byAdding: .day, value: -PhotoDateShortcut.sevenDays.dayOffset, to: now) ?? now
        var seenIDs: Set<String> = []
        let dedupedInitialIDs = initialSelectedAssetIDs.filter { seenIDs.insert($0).inserted }

        self.photoPickerService = photoPickerService
        self.requireGPS = requireGPS
        self.maxSelection = maxSelection
        self.startDate = defaultStart
        self.endDate = now
        self.initialSelectedAssetIDs = dedupedInitialIDs
    }
    
    // MARK: - Public Methods
    
    /// 載入照片
    func loadPhotos() async {
        await MainActor.run {
            isLoading = true
        }
        
        let assets = await photoPickerService.fetchPhotos(
            requireGPS: requireGPS,
            startDate: startDate,
            endDate: endDate
        )
        
        let selectablePhotos = assets.map { SelectablePhoto(asset: $0) }
        let restoredSelection = await restoreInitialSelectionIfNeeded(loadedPhotos: selectablePhotos)
        
        await MainActor.run {
            photos = selectablePhotos
            if let restoredSelection {
                selectedPhotos = restoredSelection
            }
            isLoading = false
        }
    }
    
    /// 套用日期捷徑
    func applyShortcut(_ shortcut: PhotoDateShortcut) async {
        let now = Date()
        let calendar = Calendar.current
        let start: Date

        switch shortcut {
        case .today:
            start = calendar.startOfDay(for: now)
        case .sevenDays:
            start = calendar.date(byAdding: .day, value: -shortcut.dayOffset, to: now) ?? now
        case .oneMonth:
            start = calendar.date(byAdding: .day, value: -shortcut.dayOffset, to: now) ?? now
        case .thisYear:
            let comps = calendar.dateComponents([.year], from: now)
            start = calendar.date(from: comps) ?? now
        case .custom:
            await MainActor.run {
                activeShortcut = .custom
            }
            return
        }

        await MainActor.run {
            startDate = start
            endDate = now
            activeShortcut = shortcut
        }
        await loadPhotos()
    }

    /// 切換到自選模式（不立即重載，等待日期確認）
    func switchToCustomRange() {
        activeShortcut = .custom
    }

    /// 一次更新日期區間
    func updateDateRange(start: Date, end: Date) async {
        await MainActor.run {
            if start <= end {
                startDate = start
                endDate = end
            } else {
                startDate = end
                endDate = start
            }
            activeShortcut = .custom
        }
        await loadPhotos()
    }

    /// 更新為單一日期（開始與結束同一天）
    func updateSingleDate(_ date: Date) async {
        await MainActor.run {
            startDate = date
            endDate = date
            activeShortcut = .custom
        }
        await loadPhotos()
    }

    /// 更新起始日期
    func updateStartDate(_ date: Date) async {
        await MainActor.run {
            if date > endDate {
                endDate = date
            }
            startDate = date
            activeShortcut = .custom
        }
        await loadPhotos()
    }

    /// 更新結束日期
    func updateEndDate(_ date: Date) async {
        await MainActor.run {
            if date < startDate {
                startDate = date
            }
            endDate = date
            activeShortcut = .custom
        }
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

    // MARK: - Private Helpers

    private func restoreInitialSelectionIfNeeded(loadedPhotos: [SelectablePhoto]) async -> [SelectablePhoto]? {
        guard !hasRestoredInitialSelection else { return nil }
        hasRestoredInitialSelection = true

        guard !initialSelectedAssetIDs.isEmpty else { return nil }

        var selectedMap: [String: SelectablePhoto] = [:]
        loadedPhotos.forEach { selectedMap[$0.id] = $0 }

        let missingIDs = initialSelectedAssetIDs.filter { selectedMap[$0] == nil }
        if !missingIDs.isEmpty {
            let missingAssets = await photoPickerService.fetchAssets(localIdentifiers: missingIDs)
            missingAssets.forEach { asset in
                selectedMap[asset.localIdentifier] = SelectablePhoto(asset: asset)
            }
        }

        return initialSelectedAssetIDs
            .compactMap { selectedMap[$0] }
            .prefix(maxSelection)
            .map { $0 }
    }
}
