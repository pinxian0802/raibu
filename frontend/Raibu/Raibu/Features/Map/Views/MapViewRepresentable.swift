//
//  MapViewRepresentable.swift
//  Raibu
//
//  UIViewRepresentable wrapper for MKMapView.
//

import SwiftUI
import MapKit

/// MKMapView 的 SwiftUI 橋接
/// 處理地圖顯示、標註管理、手勢識別
struct MapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let clusters: [ClusterResult]
    let currentMode: MapMode
    let searchLocation: SearchLocationMarker?
    let onClusterTapped: (ClusterResult) -> Void
    let onLongPress: (CLLocationCoordinate2D) -> Void
    let onRegionChanged: (CGSize) -> Void
    let onMapTapped: () -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        
        // 顯示景點標記（POI）
        mapView.pointOfInterestFilter = .includingAll
        
        // 長按手勢
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(context.coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPress)
        
        // 點擊手勢（用於關閉搜尋建議）
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(context.coordinator.handleTap(_:))
        )
        tapGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(tapGesture)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新 region
        let currentRegion = mapView.region
        if abs(currentRegion.center.latitude - region.center.latitude) > 0.0001 ||
           abs(currentRegion.center.longitude - region.center.longitude) > 0.0001 {
            mapView.setRegion(region, animated: true)
        }
        
        // 更新搜尋位置標記
        updateSearchLocationAnnotation(mapView: mapView)
        
        // 差異比對更新標註（避免閃爍）
        let existingAnnotations = mapView.annotations.compactMap { $0 as? ClusterAnnotation }
        let existingIds = Set(existingAnnotations.map { $0.clusterIdentifier })
        let newIds = Set(clusters.map { clusterIdentifier(for: $0) })
        
        // 移除不再存在的標註
        let toRemove = existingAnnotations.filter { !newIds.contains($0.clusterIdentifier) }
        if !toRemove.isEmpty {
            mapView.removeAnnotations(toRemove)
        }
        
        // 加入新的標註
        let existingClusterIds = existingIds
        for cluster in clusters {
            let id = clusterIdentifier(for: cluster)
            if !existingClusterIds.contains(id) {
                let annotation = ClusterAnnotation(cluster: cluster, mode: currentMode, identifier: id)
                mapView.addAnnotation(annotation)
            }
        }
    }
    
    /// 更新搜尋位置標記
    private func updateSearchLocationAnnotation(mapView: MKMapView) {
        let existingSearchAnnotations = mapView.annotations.compactMap { $0 as? SearchLocationAnnotation }
        
        // 檢查是否需要更新標記
        if let location = searchLocation {
            // 檢查是否已經有相同位置的標記
            let existingAnnotation = existingSearchAnnotations.first { annotation in
                annotation.coordinate.latitude == location.coordinate.latitude &&
                annotation.coordinate.longitude == location.coordinate.longitude
            }
            
            // 如果已經存在相同位置的標記，不需要更新
            if existingAnnotation != nil {
                return
            }
            
            // 移除舊的標記
            if !existingSearchAnnotations.isEmpty {
                mapView.removeAnnotations(existingSearchAnnotations)
            }
            
            // 加入新標記
            let annotation = SearchLocationAnnotation(
                coordinate: location.coordinate,
                title: location.title,
                subtitle: location.subtitle
            )
            mapView.addAnnotation(annotation)
        } else {
            // 沒有搜尋位置時，移除所有搜尋標記
            if !existingSearchAnnotations.isEmpty {
                mapView.removeAnnotations(existingSearchAnnotations)
            }
        }
    }
    
    /// 產生群集的唯一識別 ID
    private func clusterIdentifier(for cluster: ClusterResult) -> String {
        let itemIds = cluster.items.map { $0.id }.sorted().joined(separator: "_")
        return itemIds
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: MapViewRepresentable
        
        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            parent.onMapTapped()
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let mapView = gesture.view as? MKMapView else { return }
            
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onLongPress(coordinate)
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 使用 DispatchQueue.main.async 延遲更新，避免在 SwiftUI view 更新過程中觸發狀態變更
            // 這解決了 "Publishing changes from within view updates is not allowed" 的錯誤
            DispatchQueue.main.async {
                self.parent.region = mapView.region
                self.parent.onRegionChanged(mapView.bounds.size)
            }
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 處理搜尋位置標記
            if let searchAnnotation = annotation as? SearchLocationAnnotation {
                let identifier = "SearchLocation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                    annotationView?.animatesWhenAdded = true
                }
                
                annotationView?.annotation = annotation
                annotationView?.markerTintColor = .systemRed
                annotationView?.glyphImage = UIImage(systemName: "mappin")
                
                return annotationView
            }
            
            // 處理 Cluster 標註
            guard let clusterAnnotation = annotation as? ClusterAnnotation else { return nil }
            
            let cluster = clusterAnnotation.cluster
            let identifier = clusterAnnotation.clusterIdentifier
            
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
            }
            
            annotationView?.annotation = annotation
            
            // 設定圖示
            if cluster.isSingle {
                if case .ask = cluster.items[0] {
                    annotationView?.image = MapIconFactory.createAskIcon()
                } else if case .recordImage(let image) = cluster.items[0] {
                    loadThumbnail(for: annotationView, urlString: image.thumbnailPublicUrl, badgeCount: nil)
                }
            } else {
                if clusterAnnotation.mode == .record {
                    if let firstRecordImage = cluster.items.compactMap({ item -> MapRecordImage? in
                        if case .recordImage(let image) = item { return image }
                        return nil
                    }).first {
                        loadThumbnail(for: annotationView, urlString: firstRecordImage.thumbnailPublicUrl, badgeCount: cluster.count)
                    }
                } else {
                    annotationView?.image = MapIconFactory.createClusterIcon(count: cluster.count, mode: clusterAnnotation.mode)
                }
            }
            
            return annotationView
        }
        
        // MARK: - Thumbnail Loading
        
        private func loadThumbnail(for annotationView: MKAnnotationView?, urlString: String, badgeCount: Int?) {
            guard let url = URL(string: urlString) else { return }
            
            let cacheKey = "\(urlString)_\(badgeCount ?? 0)" as NSString
            
            // 檢查快取
            if let cachedImage = MapIconFactory.imageCache.object(forKey: cacheKey) {
                annotationView?.image = cachedImage
                if badgeCount != nil {
                    let badgeOffset = MapIconFactory.badgeSize / 2
                    annotationView?.centerOffset = CGPoint(x: badgeOffset / 2, y: badgeOffset / 2)
                } else {
                    annotationView?.centerOffset = .zero
                }
                return
            }
            
            // 使用帶快取策略的請求
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            
            let hasBadge = badgeCount != nil
            let badgeOffsetValue = MapIconFactory.badgeSize / 2
            
            URLSession.shared.dataTask(with: request) { [weak annotationView] data, _, _ in
                guard let data = data, let originalImage = UIImage(data: data) else { return }
                
                let thumbnailImage: UIImage
                if let count = badgeCount {
                    thumbnailImage = MapIconFactory.createThumbnailWithBadge(from: originalImage, count: count)
                } else {
                    thumbnailImage = MapIconFactory.createThumbnailIcon(from: originalImage)
                }
                
                // 儲存到快取
                MapIconFactory.imageCache.setObject(thumbnailImage, forKey: cacheKey)
                
                DispatchQueue.main.async {
                    annotationView?.image = thumbnailImage
                    if hasBadge {
                        annotationView?.centerOffset = CGPoint(x: badgeOffsetValue / 2, y: badgeOffsetValue / 2)
                    } else {
                        annotationView?.centerOffset = .zero
                    }
                }
            }.resume()
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let clusterAnnotation = view.annotation as? ClusterAnnotation else { return }
            mapView.deselectAnnotation(view.annotation, animated: false)
            parent.onClusterTapped(clusterAnnotation.cluster)
        }
    }
}
