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
import CoreLocation

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
    ///   - startDate: 起始日期（含）
    ///   - endDate: 結束日期（含當日）
    /// - Returns: 符合條件的 PHAsset 陣列
    func fetchPhotos(requireGPS: Bool, startDate: Date? = nil, endDate: Date? = nil) async -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        // 時間篩選
        fetchOptions.predicate = datePredicate(startDate: startDate, endDate: endDate)
        
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

    /// 依 localIdentifier 取得指定照片（維持傳入順序）
    func fetchAssets(localIdentifiers: [String]) async -> [PHAsset] {
        guard !localIdentifiers.isEmpty else { return [] }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        var assetMap: [String: PHAsset] = [:]

        fetchResult.enumerateObjects { asset, _, _ in
            assetMap[asset.localIdentifier] = asset
        }

        return localIdentifiers.compactMap { assetMap[$0] }
    }
    
    /// 嘗試以拍攝時間與座標對應既有圖片到本機相簿 asset localIdentifier（依 displayOrder）
    func inferAssetLocalIdentifiers(for images: [ImageMedia]) async -> [String] {
        guard !images.isEmpty else { return [] }
        
        let orderedImages = images.sorted { $0.displayOrder < $1.displayOrder }
        var usedAssetIDs: Set<String> = []
        var matchedIDs: [String] = []
        
        for image in orderedImages {
            if let assetID = inferredAssetID(for: image, excluding: usedAssetIDs) {
                usedAssetIDs.insert(assetID)
                matchedIDs.append(assetID)
            }
        }
        
        return matchedIDs
    }

    // MARK: - Private Helpers
    
    private func bestMatchingAssetID(
        for image: ImageMedia,
        excluding usedAssetIDs: Set<String>,
        timeTolerance: TimeInterval,
        distanceToleranceMeters: Double
    ) -> String? {
        guard let capturedAt = image.capturedAt else { return nil }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        let start = capturedAt.addingTimeInterval(-timeTolerance)
        let end = capturedAt.addingTimeInterval(timeTolerance)
        fetchOptions.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@",
            start as CVarArg,
            end as CVarArg
        )
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        guard fetchResult.count > 0 else { return nil }
        
        var bestMatch: (assetID: String, score: Double)?
        
        fetchResult.enumerateObjects { asset, _, stop in
            let assetID = asset.localIdentifier
            guard !usedAssetIDs.contains(assetID) else { return }
            guard let assetDate = asset.creationDate else { return }
            
            let timeDelta = abs(assetDate.timeIntervalSince(capturedAt))
            guard timeDelta <= timeTolerance else { return }
            
            var distanceScore = 0.0
            if let targetLocation = image.location?.clLocationCoordinate {
                guard let assetCoordinate = asset.location?.coordinate else { return }
                let target = CLLocation(latitude: targetLocation.latitude, longitude: targetLocation.longitude)
                let assetLocation = CLLocation(latitude: assetCoordinate.latitude, longitude: assetCoordinate.longitude)
                let distance = target.distance(from: assetLocation)
                guard distance <= distanceToleranceMeters else { return }
                distanceScore = distance
            }
            
            let score = timeDelta + distanceScore * 4.0
            if let currentBest = bestMatch {
                if score < currentBest.score {
                    bestMatch = (assetID, score)
                }
            } else {
                bestMatch = (assetID, score)
            }
            
            if score < 1.0 {
                stop.pointee = true
            }
        }
        
        return bestMatch?.assetID
    }

    private func inferredAssetID(
        for image: ImageMedia,
        excluding usedAssetIDs: Set<String>
    ) -> String? {
        if let strictMatch = bestMatchingAssetID(
            for: image,
            excluding: usedAssetIDs,
            timeTolerance: 60,
            distanceToleranceMeters: 80
        ) {
            return strictMatch
        }

        if let mediumMatch = bestMatchingAssetID(
            for: image,
            excluding: usedAssetIDs,
            timeTolerance: 600,
            distanceToleranceMeters: 300
        ) {
            return mediumMatch
        }

        // 後端時間若有時區偏移，放寬到 14 小時以提高回填成功率。
        if let relaxedMatch = bestMatchingAssetID(
            for: image,
            excluding: usedAssetIDs,
            timeTolerance: 14 * 60 * 60,
            distanceToleranceMeters: 300
        ) {
            return relaxedMatch
        }

        return bestMatchingAssetIDByLocation(
            for: image,
            excluding: usedAssetIDs,
            distanceToleranceMeters: 80
        )
    }

    private func bestMatchingAssetIDByLocation(
        for image: ImageMedia,
        excluding usedAssetIDs: Set<String>,
        distanceToleranceMeters: Double
    ) -> String? {
        guard let targetCoordinate = image.location?.clLocationCoordinate else { return nil }

        let targetLocation = CLLocation(
            latitude: targetCoordinate.latitude,
            longitude: targetCoordinate.longitude
        )

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "location != nil")

        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var bestMatch: (assetID: String, distance: Double)?
        var scannedCount = 0
        let maxScanCount = 5000

        fetchResult.enumerateObjects { asset, _, stop in
            scannedCount += 1
            if scannedCount > maxScanCount {
                stop.pointee = true
                return
            }

            let assetID = asset.localIdentifier
            guard !usedAssetIDs.contains(assetID),
                  let assetCoordinate = asset.location?.coordinate else { return }

            let assetLocation = CLLocation(
                latitude: assetCoordinate.latitude,
                longitude: assetCoordinate.longitude
            )
            let distance = targetLocation.distance(from: assetLocation)
            guard distance <= distanceToleranceMeters else { return }

            if let currentBest = bestMatch {
                if distance < currentBest.distance {
                    bestMatch = (assetID, distance)
                }
            } else {
                bestMatch = (assetID, distance)
            }

            if distance < 5 {
                stop.pointee = true
            }
        }

        return bestMatch?.assetID
    }

    private func datePredicate(startDate: Date?, endDate: Date?) -> NSPredicate? {
        let calendar = Calendar.current
        var predicates: [NSPredicate] = []

        if let startDate {
            let normalizedStart = calendar.startOfDay(for: startDate)
            predicates.append(NSPredicate(format: "creationDate >= %@", normalizedStart as CVarArg))
        }

        if let endDate {
            let normalizedEnd = calendar.startOfDay(for: endDate)
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: normalizedEnd) {
                predicates.append(NSPredicate(format: "creationDate < %@", nextDay as CVarArg))
            }
        }

        guard !predicates.isEmpty else { return nil }
        if predicates.count == 1 { return predicates[0] }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
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
    
    /// 批次載入照片資料（含逆向地理編碼）
    func loadPhotosData(for assets: [PHAsset]) async throws -> [SelectedPhoto] {
        var photos: [SelectedPhoto] = []
        
        for asset in assets {
            var photo = try await loadPhotoData(for: asset)
            
            // 逆向地理編碼
            if let location = photo.location {
                photo.address = await reverseGeocode(location: location)
            }
            
            photos.append(photo)
        }
        
        return photos
    }
    
    /// 逆向地理編碼
    private func reverseGeocode(location: Coordinate) async -> String? {
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(latitude: location.lat, longitude: location.lng)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(clLocation)
            if let placemark = placemarks.first {
                var addressParts: [String] = []
                
                // Debug: 顯示 CLGeocoder 回傳的各個欄位
                print("=== CLGeocoder Debug ===")
                print("name: \(placemark.name ?? "nil")")
                print("thoroughfare: \(placemark.thoroughfare ?? "nil")")
                print("subThoroughfare: \(placemark.subThoroughfare ?? "nil")")
                print("subLocality: \(placemark.subLocality ?? "nil")")
                print("locality: \(placemark.locality ?? "nil")")
                print("administrativeArea: \(placemark.administrativeArea ?? "nil")")
                print("========================")
                
                // 優先使用 name（通常是最精確的地址/商家名稱）
                if let name = placemark.name {
                    addressParts.append(name)
                }
                
                // 只有當 name 不包含街道資訊時，才添加街道
                if let thoroughfare = placemark.thoroughfare {
                    let streetAddress: String
                    if let subThoroughfare = placemark.subThoroughfare {
                        streetAddress = "\(thoroughfare) \(subThoroughfare)"
                    } else {
                        streetAddress = thoroughfare
                    }
                    
                    // 檢查是否和 name 重複（避免重複添加）
                    let isDuplicate = addressParts.contains { existingPart in
                        existingPart.contains(thoroughfare) || streetAddress.contains(existingPart)
                    }
                    
                    if !isDuplicate {
                        addressParts.append(streetAddress)
                    }
                }
                
                // 台灣地址結構：subLocality=里, locality=區, administrativeArea=市
                // 只顯示「區」和「市」
                
                // 添加區（locality）
                if let locality = placemark.locality {
                    if !addressParts.contains(where: { $0.contains(locality) }) {
                        addressParts.append(locality)
                    }
                }
                
                // 添加城市（administrativeArea）
                if let administrativeArea = placemark.administrativeArea {
                    if !addressParts.contains(where: { $0.contains(administrativeArea) }) {
                        addressParts.append(administrativeArea)
                    }
                }
                
                return addressParts.isEmpty ? nil : addressParts.joined(separator: ", ")
            }
        } catch {
            print("Geocoding failed: \(error.localizedDescription)")
        }
        
        return nil
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
