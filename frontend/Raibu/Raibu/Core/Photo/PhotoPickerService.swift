//
//  PhotoPickerService.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation
import Photos
import UIKit
import Combine

/// 時間範圍選項
enum DateRangeOption: String, CaseIterable {
    case oneWeek = "7 天"
    case twoWeeks = "14 天"
    case oneMonth = "30 天"
    
    var days: Int {
        switch self {
        case .oneWeek: return 7
        case .twoWeeks: return 14
        case .oneMonth: return 30
        }
    }
    
    var startDate: Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }
}

/// 相簿選擇器服務
class PhotoPickerService: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    
    // MARK: - Public Methods
    
    /// 請求相簿權限
    func requestAuthorization() async -> PHAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            authorizationStatus = status
        }
        return status
    }
    
    /// 取得篩選後的照片
    /// - Parameters:
    ///   - requireGPS: 是否要求 GPS（紀錄模式為 true）
    ///   - dateRange: 時間範圍
    /// - Returns: 符合條件的 PHAsset 陣列
    func fetchPhotos(requireGPS: Bool, dateRange: DateRangeOption = .oneWeek) async -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        // 時間篩選
        let startDate = dateRange.startDate
        fetchOptions.predicate = NSPredicate(format: "creationDate >= %@", startDate as CVarArg)
        
        let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        var filtered: [PHAsset] = []
        
        allPhotos.enumerateObjects { asset, _, _ in
            // GPS 篩選（僅紀錄模式）
            if requireGPS {
                guard asset.location != nil else { return }
            }
            
            filtered.append(asset)
        }
        
        return filtered
    }
    
    /// 載入照片完整資料
    func loadPhotoData(for asset: PHAsset) async throws -> SelectedPhoto {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, uti, orientation, info in
                guard let imageData = data else {
                    continuation.resume(throwing: PhotoError.failedToLoadData)
                    return
                }
                
                // 產生縮圖
                guard let thumbnailData = self.generateThumbnail(from: imageData) else {
                    continuation.resume(throwing: PhotoError.failedToGenerateThumbnail)
                    return
                }
                
                // 判斷 MIME 類型
                let mimeType = self.mimeType(for: uti ?? "public.jpeg")
                
                // 提取座標
                let location: Coordinate?
                if let assetLocation = asset.location {
                    location = Coordinate(
                        lat: assetLocation.coordinate.latitude,
                        lng: assetLocation.coordinate.longitude
                    )
                } else {
                    location = nil
                }
                
                let photo = SelectedPhoto(
                    id: UUID().uuidString,
                    asset: asset,
                    originalData: imageData,
                    thumbnailData: thumbnailData,
                    mimeType: mimeType,
                    fileSize: imageData.count,
                    location: location,
                    capturedAt: asset.creationDate
                )
                
                continuation.resume(returning: photo)
            }
        }
    }
    
    /// 批次載入照片資料
    func loadPhotosData(for assets: [PHAsset]) async throws -> [SelectedPhoto] {
        var photos: [SelectedPhoto] = []
        
        for asset in assets {
            let photo = try await loadPhotoData(for: asset)
            photos.append(photo)
        }
        
        return photos
    }
    
    // MARK: - Private Methods
    
    /// 生成縮圖 (最長邊 300px, JPEG 品質 70%)
    private func generateThumbnail(from data: Data, maxSize: CGFloat = 300, quality: CGFloat = 0.7) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        
        // 計算縮放比例
        let scale = min(maxSize / image.size.width, maxSize / image.size.height, 1)
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        
        // 繪製縮圖
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return thumbnail?.jpegData(compressionQuality: quality)
    }
    
    /// 取得 MIME 類型
    private func mimeType(for uti: String) -> String {
        switch uti {
        case "public.jpeg", "public.jpg":
            return "image/jpeg"
        case "public.png":
            return "image/png"
        case "public.heic", "public.heif":
            return "image/heic"
        case "org.webmproject.webp":
            return "image/webp"
        default:
            return "image/jpeg"
        }
    }
}

// MARK: - Photo Errors

enum PhotoError: LocalizedError {
    case failedToLoadData
    case failedToGenerateThumbnail
    case noGPSData
    
    var errorDescription: String? {
        switch self {
        case .failedToLoadData:
            return "無法載入照片資料"
        case .failedToGenerateThumbnail:
            return "無法產生縮圖"
        case .noGPSData:
            return "照片沒有 GPS 資訊"
        }
    }
}
