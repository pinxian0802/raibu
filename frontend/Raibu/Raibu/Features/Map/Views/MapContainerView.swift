//
//  MapContainerView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import MapKit
import SwiftUI

// MARK: - Map Container View

/// 地圖主容器視圖
struct MapContainerView: View {
    @EnvironmentObject var container: DIContainer

    var body: some View {
        MapContentView(container: container)
    }
}

// MARK: - Map Content View

/// 實際地圖內容（使用 @StateObject 正確觀察 ViewModel）
struct MapContentView: View {
    let container: DIContainer
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @StateObject private var viewModel: MapViewModel
    @StateObject private var toastManager = ToastManager()

    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var createAskLocation: CreateAskLocation?
    @State private var searchLocation: SearchLocationMarker?
    @State private var hideMarkers = false

    // Sheet 控制
    @State private var selectedDetailItem: DetailSheetItem?
    @State private var clusterSheetData: ClusterSheetData?

    init(container: DIContainer) {
        self.container = container
        _viewModel = StateObject(
            wrappedValue: MapViewModel(
                recordRepository: container.recordRepository,
                askRepository: container.askRepository,
                clusteringService: container.clusteringService,
                locationManager: container.locationManager
            ))
    }

    var body: some View {
        ZStack {
            // 地圖
            mapView

            // 覆蓋層 UI
            VStack {
                topControls
                Spacer()
                bottomControls
            }
        }
        .sheet(item: $selectedDetailItem) { item in
            switch item {
            case .record(let recordId, let imageIndex):
                RecordDetailSheetView(
                    recordId: recordId,
                    initialImageIndex: imageIndex,
                    recordRepository: container.recordRepository,
                    replyRepository: container.replyRepository
                )
                .environmentObject(navigationCoordinator)
            case .ask(let askId):
                AskDetailSheetView(
                    askId: askId,
                    askRepository: container.askRepository,
                    replyRepository: container.replyRepository
                )
                .environmentObject(navigationCoordinator)
            }
        }
        .sheet(item: $clusterSheetData) { data in
            ClusterGridSheetView(
                items: data.items,
                recordRepository: container.recordRepository,
                replyRepository: container.replyRepository
            )
            .environmentObject(navigationCoordinator)
            .environmentObject(container)
        }
        .sheet(
            item: $createAskLocation,
            onDismiss: {
                // 刷新地圖資料以顯示新建立的詢問
                Task {
                    await viewModel.fetchDataForCurrentRegion()
                }
            }
        ) { location in
            CreateAskFullView(
                initialLocation: location.coordinate,
                uploadService: container.uploadService,
                askRepository: container.askRepository
            )
            .environmentObject(container)
        }
        .toastContainer(toastManager)
        .onChange(of: navigationCoordinator.targetCoordinate) { newCoordinate in
            // 回應導航協調器的跳轉請求
            if let coordinate = newCoordinate {
                // 先切換模式（如果有指定）
                if let targetMode = navigationCoordinator.targetMapMode {
                    viewModel.switchMode(to: targetMode)
                }

                // 移動到目標座標
                withAnimation {
                    viewModel.region = MKCoordinateRegion(
                        center: coordinate.clLocationCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    )
                }
                navigationCoordinator.clearTarget()
            }
        }
    }

    // MARK: - Map View

    private var mapView: some View {
        MapViewRepresentable(
            region: $viewModel.region,
            clusters: hideMarkers ? [] : viewModel.clusters,
            currentMode: viewModel.currentMode,
            searchLocation: searchLocation,
            onClusterTapped: { cluster in
                handleClusterTapped(cluster)
            },
            onLongPress: { coordinate in
                if viewModel.currentMode == .ask {
                    createAskLocation = CreateAskLocation(coordinate: coordinate)
                }
            },
            onRegionChanged: { mapSize in
                viewModel.onRegionChanged(viewModel.region, mapSize: mapSize)
            },
            onMapTapped: {
                // 點擊地圖時關閉搜尋建議列表
                isSearchActive = false
            }
        )
        .ignoresSafeArea()
    }

    // MARK: - Cluster Handling

    private func handleClusterTapped(_ cluster: ClusterResult) {
        let currentZoom = log2(360.0 / viewModel.region.span.longitudeDelta)
        let action = container.clusteringService.handleClusterTap(
            cluster: cluster,
            currentZoom: currentZoom,
            currentSpanDelta: viewModel.region.span.latitudeDelta
        )

        switch action {
        case .zoomIn(let center):
            withAnimation {
                // 限制最小 span，避免超出 MKMapView 限制
                let newLatDelta = max(viewModel.region.span.latitudeDelta / 2, 0.0003)
                let newLngDelta = max(viewModel.region.span.longitudeDelta / 2, 0.0003)
                viewModel.region = MKCoordinateRegion(
                    center: center,
                    span: MKCoordinateSpan(
                        latitudeDelta: newLatDelta,
                        longitudeDelta: newLngDelta
                    )
                )
            }

        case .showBottomSheet(let items):
            if items.count == 1 {
                handleSingleItemTap(items[0])
            } else {
                clusterSheetData = ClusterSheetData(items: items)
            }
        }
    }

    private func handleSingleItemTap(_ item: ClusterItem) {
        switch item {
        case .recordImage(let image):
            // 傳遞 displayOrder 作為初始圖片索引
            selectedDetailItem = .record(id: image.recordId, imageIndex: image.displayOrder)

        case .ask(let ask):
            selectedDetailItem = .ask(id: ask.id)
        }
    }

    // MARK: - Top Controls

    private var topControls: some View {
        VStack(spacing: 8) {
            MapSearchBar(
                searchText: $searchText,
                isSearchActive: $isSearchActive,
                mapRegion: viewModel.region,
                onSearchResultSelected: { result in
                    // 設定搜尋標記
                    searchLocation = SearchLocationMarker(
                        coordinate: result.coordinate,
                        title: result.mapItem.name ?? searchText,
                        subtitle: result.mapItem.placemark.title
                    )

                    // 關閉搜尋建議列表
                    isSearchActive = false

                    // 移動地圖到搜尋結果（使用根據地點大小調整的縮放等級）
                    withAnimation {
                        viewModel.region = result.adjustedRegion
                    }
                },
                onSearchCleared: {
                    // 清除地圖上的搜尋標記
                    searchLocation = nil
                    // 清除搜尋時恢復顯示標點
                    hideMarkers = false
                }
            )

            // 顯示/隱藏標點按鈕（只在有搜尋結果時顯示）
            if searchLocation != nil {
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            hideMarkers.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: hideMarkers ? "eye.slash" : "eye")
                            Text(hideMarkers ? "顯示標點" : "隱藏標點")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(hideMarkers ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(hideMarkers ? Color.blue : Color(.systemBackground))
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.1), radius: 3)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
            HStack {
                modeSwitcher

                Spacer()

                VStack(spacing: 12) {
                    // 定位按鈕
                    Button {
                        // 觸覺反饋
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.moveToUserLocation()
                        }
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.15), radius: 5)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }

    private var modeSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(MapMode.allCases, id: \.self) { mode in
                Button {
                    // 觸覺反饋
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.switchMode(to: mode)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.iconName)
                            .scaleEffect(viewModel.currentMode == mode ? 1.1 : 1.0)
                        Text(mode.rawValue)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(viewModel.currentMode == mode ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        viewModel.currentMode == mode
                            ? (mode == .record ? Color.blue : Color.orange) : Color.clear
                    )
                    .cornerRadius(20)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.15), radius: 5)
    }
}

// MARK: - Button Styles

/// 縮放按鈕樣式
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Supporting Types

/// 詳情 Sheet 項目類型
enum DetailSheetItem: Identifiable {
    case record(id: String, imageIndex: Int)
    case ask(id: String)

    var id: String {
        switch self {
        case .record(let id, let imageIndex): return "record-\(id)-\(imageIndex)"
        case .ask(let id): return "ask-\(id)"
        }
    }
}

/// 建立詢問位置
struct CreateAskLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

/// 群集 Sheet 資料
struct ClusterSheetData: Identifiable {
    let id = UUID()
    let items: [ClusterItem]
}

// MARK: - Preview

#Preview {
    MapContainerView()
        .environmentObject(DIContainer())
}
