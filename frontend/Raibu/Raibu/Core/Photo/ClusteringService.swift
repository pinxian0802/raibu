//
//  ClusteringService.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation
import MapKit

/// 群集點擊行為
enum ClusterAction {
    case zoomIn(center: CLLocationCoordinate2D)
    case showBottomSheet(items: [ClusterItem])
}

/// 群集結果
struct ClusterResult: Identifiable {
    let id = UUID()
    let center: CLLocationCoordinate2D
    let items: [ClusterItem]
    
    var count: Int { items.count }
    var isSingle: Bool { count == 1 }
}

/// 群集項目 (可以是紀錄圖片或詢問標點)
enum ClusterItem: Identifiable {
    case recordImage(MapRecordImage)
    case ask(MapAsk)
    
    var id: String {
        switch self {
        case .recordImage(let image):
            return "record_\(image.imageId)"
        case .ask(let ask):
            return "ask_\(ask.id)"
        }
    }
    
    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .recordImage(let image):
            return CLLocationCoordinate2D(latitude: image.lat, longitude: image.lng)
        case .ask(let ask):
            return ask.center.clLocationCoordinate
        }
    }
}

/// 群集演算法服務
class ClusteringService {
    
    /// 螢幕像素半徑門檻 (R)
    private let pixelThreshold: CGFloat = 40
    
    // MARK: - Public Methods
    
    /// 計算群集
    /// - Parameters:
    ///   - items: 需要群集的項目
    ///   - mapRect: 地圖可視範圍
    ///   - mapSize: 地圖視圖大小
    /// - Returns: 群集結果陣列
    func clusterItems(
        _ items: [ClusterItem],
        in mapRect: MKMapRect,
        mapSize: CGSize
    ) -> [ClusterResult] {
        guard !items.isEmpty else { return [] }
        
        // 計算每個項目的螢幕座標
        var itemsWithScreenPos: [(item: ClusterItem, screenPos: CGPoint)] = []
        
        for item in items {
            let mapPoint = MKMapPoint(item.coordinate)
            let screenX = (mapPoint.x - mapRect.origin.x) / mapRect.size.width * Double(mapSize.width)
            let screenY = (mapPoint.y - mapRect.origin.y) / mapRect.size.height * Double(mapSize.height)
            itemsWithScreenPos.append((item, CGPoint(x: screenX, y: screenY)))
        }
        
        // 使用簡單的貪婪群集演算法
        var clusters: [ClusterResult] = []
        var processed = Set<String>()
        
        for (item, screenPos) in itemsWithScreenPos {
            guard !processed.contains(item.id) else { continue }
            
            // 找出所有在半徑內的項目
            var clusterItems: [ClusterItem] = [item]
            processed.insert(item.id)
            
            for (otherItem, otherScreenPos) in itemsWithScreenPos {
                guard !processed.contains(otherItem.id) else { continue }
                
                let distance = hypot(screenPos.x - otherScreenPos.x, screenPos.y - otherScreenPos.y)
                if distance < pixelThreshold {
                    clusterItems.append(otherItem)
                    processed.insert(otherItem.id)
                }
            }
            
            // 計算群集中心
            let center = calculateCenter(of: clusterItems)
            clusters.append(ClusterResult(center: center, items: clusterItems))
        }
        
        return clusters
    }
    
    /// 處理群集點擊
    /// - Parameters:
    ///   - cluster: 被點擊的群集
    ///   - currentZoom: 當前縮放等級
    ///   - maxZoom: 最大縮放等級
    ///   - currentSpanDelta: 當前地圖 span 的 latitudeDelta
    /// - Returns: 應執行的動作
    func handleClusterTap(
        cluster: ClusterResult,
        currentZoom: Double,
        maxZoom: Double = 18,
        currentSpanDelta: Double = 0
    ) -> ClusterAction {
        if cluster.isSingle {
            // 單一項目直接返回
            return .showBottomSheet(items: cluster.items)
        }
        
        // 如果 span 已經很小（非常接近地圖），或達到最大縮放，顯示列表
        let isAtMaxZoom = currentZoom >= maxZoom || currentSpanDelta < 0.0005
        
        if !isAtMaxZoom {
            // 尚未達最大縮放 -> 自動放大
            return .zoomIn(center: cluster.center)
        } else {
            // 已達最大縮放 -> 顯示列表
            return .showBottomSheet(items: cluster.items)
        }
    }
    
    // MARK: - Private Methods
    
    /// 計算多個座標的中心點
    private func calculateCenter(of items: [ClusterItem]) -> CLLocationCoordinate2D {
        guard !items.isEmpty else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        
        var totalLat = 0.0
        var totalLng = 0.0
        
        for item in items {
            totalLat += item.coordinate.latitude
            totalLng += item.coordinate.longitude
        }
        
        return CLLocationCoordinate2D(
            latitude: totalLat / Double(items.count),
            longitude: totalLng / Double(items.count)
        )
    }
}
