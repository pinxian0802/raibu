//
//  MapViewModel.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation
import MapKit
import SwiftUI
import Combine

/// 地圖視圖模型
class MapViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentMode: MapMode = .record
    @Published var region: MKCoordinateRegion
    @Published var recordImages: [MapRecordImage] = []
    @Published var asks: [MapAsk] = []
    @Published var clusters: [ClusterResult] = []
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 詳細視窗
    @Published var selectedRecordId: String?
    @Published var selectedAskId: String?
    @Published var showDetailSheet = false
    @Published var showClusterListSheet = false
    @Published var clusterListItems: [ClusterItem] = []
    
    // 長按建立詢問
    @Published var longPressLocation: CLLocationCoordinate2D?
    @Published var showCreateAskSheet = false
    
    // MARK: - Dependencies
    
    private let recordRepository: RecordRepository
    private let askRepository: AskRepository
    private let clusteringService: ClusteringService
    private let locationManager: LocationManager
    
    // MARK: - Private Properties
    
    private var mapSize: CGSize = .zero
    private var lastFetchedRegion: MKCoordinateRegion?
    private var fetchTask: Task<Void, Never>?
    
    // 台北市中心預設位置
    private static let defaultCenter = CLLocationCoordinate2D(latitude: 25.033, longitude: 121.565)
    private static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    
    // MARK: - Initialization
    
    init(
        recordRepository: RecordRepository,
        askRepository: AskRepository,
        clusteringService: ClusteringService,
        locationManager: LocationManager
    ) {
        self.recordRepository = recordRepository
        self.askRepository = askRepository
        self.clusteringService = clusteringService
        self.locationManager = locationManager
        
        // 設定初始區域
        self.region = MKCoordinateRegion(
            center: Self.defaultCenter,
            span: Self.defaultSpan
        )
    }
    
    // MARK: - Public Methods
    
    /// 切換地圖模式
    func switchMode(to mode: MapMode) {
        currentMode = mode
        updateClusters()
        Task {
            await fetchDataForCurrentRegion()
        }
    }
    
    /// 地圖區域變更時呼叫
    func onRegionChanged(_ newRegion: MKCoordinateRegion, mapSize: CGSize) {
        self.region = newRegion
        self.mapSize = mapSize
        
        // 防抖：取消之前的 fetch 任務
        fetchTask?.cancel()
        
        fetchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)  // 300ms
            
            if !Task.isCancelled {
                await fetchDataForCurrentRegion()
                updateClusters()
            }
        }
    }
    
    /// 更新群集
    func updateClusters() {
        let mapRect = MKMapRect(region)
        
        let items: [ClusterItem]
        switch currentMode {
        case .record:
            items = recordImages.map { .recordImage($0) }
        case .ask:
            items = asks.map { .ask($0) }
        }
        
        clusters = clusteringService.clusterItems(items, in: mapRect, mapSize: mapSize)
    }
    
    /// 處理群集點擊
    func onClusterTapped(_ cluster: ClusterResult) {
        let currentZoom = log2(360.0 / region.span.longitudeDelta)
        let action = clusteringService.handleClusterTap(
            cluster: cluster,
            currentZoom: currentZoom
        )
        
        switch action {
        case .zoomIn(let center):
            withAnimation {
                region = MKCoordinateRegion(
                    center: center,
                    span: MKCoordinateSpan(
                        latitudeDelta: region.span.latitudeDelta / 2,
                        longitudeDelta: region.span.longitudeDelta / 2
                    )
                )
            }
            
        case .showBottomSheet(let items):
            if items.count == 1 {
                // 單一項目直接開啟詳情
                handleSingleItemTap(items[0])
            } else {
                // 多項目顯示列表
                clusterListItems = items
                showClusterListSheet = true
            }
        }
    }
    
    /// 處理單一項目點擊
    func handleSingleItemTap(_ item: ClusterItem) {
        switch item {
        case .recordImage(let image):
            selectedRecordId = image.recordId
            showDetailSheet = true
            
        case .ask(let ask):
            selectedAskId = ask.id
            showDetailSheet = true
        }
    }
    
    /// 處理地圖長按（建立詢問）
    func onLongPress(at coordinate: CLLocationCoordinate2D) {
        longPressLocation = coordinate
        showCreateAskSheet = true
    }
    
    /// 移動到使用者當前位置
    func moveToUserLocation() {
        guard let location = locationManager.currentLocation else {
            locationManager.requestLocation()
            return
        }
        
        withAnimation {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }
    
    /// 搜尋地點並移動
    func searchAndMoveTo(query: String) async {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = query
        searchRequest.region = region
        
        do {
            let search = MKLocalSearch(request: searchRequest)
            let response = try await search.start()
            
            if let firstItem = response.mapItems.first {
                await MainActor.run {
                    withAnimation {
                        region = MKCoordinateRegion(
                            center: firstItem.placemark.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    }
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "找不到該地點"
            }
        }
    }
    
    // MARK: - Data Fetching (Public for MapViewRepresentable)
    
    @MainActor
    func fetchDataForCurrentRegion() async {
        let bounds = regionBounds(region)
        
        isLoading = true
        errorMessage = nil
        
        do {
            switch currentMode {
            case .record:
                recordImages = try await recordRepository.getMapRecords(
                    minLat: bounds.minLat,
                    maxLat: bounds.maxLat,
                    minLng: bounds.minLng,
                    maxLng: bounds.maxLng
                )
                
            case .ask:
                let allAsks = try await askRepository.getMapAsks(
                    minLat: bounds.minLat,
                    maxLat: bounds.maxLat,
                    minLng: bounds.minLng,
                    maxLng: bounds.maxLng
                )
                // 過濾：僅顯示 48 小時內的詢問標點 (PRD 規定)
                asks = allAsks.filter { $0.isWithin48Hours }
            }
            
            updateClusters()
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func regionBounds(_ region: MKCoordinateRegion) -> (minLat: Double, maxLat: Double, minLng: Double, maxLng: Double) {
        let center = region.center
        let span = region.span
        
        return (
            minLat: center.latitude - span.latitudeDelta / 2,
            maxLat: center.latitude + span.latitudeDelta / 2,
            minLng: center.longitude - span.longitudeDelta / 2,
            maxLng: center.longitude + span.longitudeDelta / 2
        )
    }
}

// MARK: - MKMapRect Extension

extension MKMapRect {
    init(_ region: MKCoordinateRegion) {
        let topLeft = MKMapPoint(CLLocationCoordinate2D(
            latitude: region.center.latitude + region.span.latitudeDelta / 2,
            longitude: region.center.longitude - region.span.longitudeDelta / 2
        ))
        let bottomRight = MKMapPoint(CLLocationCoordinate2D(
            latitude: region.center.latitude - region.span.latitudeDelta / 2,
            longitude: region.center.longitude + region.span.longitudeDelta / 2
        ))
        
        self.init(
            x: topLeft.x,
            y: topLeft.y,
            width: bottomRight.x - topLeft.x,
            height: bottomRight.y - topLeft.y
        )
    }
}
