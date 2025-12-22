//
//  ImageMedia.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation
import CoreLocation

/// 圖片狀態
enum ImageMediaStatus: String, Codable {
    case pending = "PENDING"
    case completed = "COMPLETED"
}

/// 圖片媒體模型
struct ImageMedia: Codable, Identifiable, Equatable {
    let id: String
    let originalPublicUrl: String
    let thumbnailPublicUrl: String
    let location: Coordinate?
    let capturedAt: Date?
    let displayOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case originalPublicUrl = "original_public_url"
        case thumbnailPublicUrl = "thumbnail_public_url"
        case location
        case capturedAt = "captured_at"
        case displayOrder = "display_order"
    }
    
    /// 轉換為 CLLocationCoordinate2D
    var clLocationCoordinate: CLLocationCoordinate2D? {
        guard let location = location else { return nil }
        return CLLocationCoordinate2D(latitude: location.lat, longitude: location.lng)
    }
}

/// 座標模型
struct Coordinate: Codable, Equatable {
    let lat: Double
    let lng: Double
    
    /// 從 CLLocationCoordinate2D 建立
    init(lat: Double, lng: Double) {
        self.lat = lat
        self.lng = lng
    }
    
    init(from clCoordinate: CLLocationCoordinate2D) {
        self.lat = clCoordinate.latitude
        self.lng = clCoordinate.longitude
    }
    
    /// 轉換為 CLLocationCoordinate2D
    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
    
    /// 計算距離 (公尺)
    func distance(to other: Coordinate) -> Double {
        let location1 = CLLocation(latitude: lat, longitude: lng)
        let location2 = CLLocation(latitude: other.lat, longitude: other.lng)
        return location1.distance(from: location2)
    }
}

// MARK: - API Request Models

/// 建立圖片請求 (用於建立標點)
struct CreateImageRequest: Codable {
    let uploadId: String
    let originalPublicUrl: String
    let thumbnailPublicUrl: String
    let location: Coordinate?
    let capturedAt: Date?
    let displayOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case uploadId = "upload_id"
        case originalPublicUrl = "original_public_url"
        case thumbnailPublicUrl = "thumbnail_public_url"
        case location
        case capturedAt = "captured_at"
        case displayOrder = "display_order"
    }
}
