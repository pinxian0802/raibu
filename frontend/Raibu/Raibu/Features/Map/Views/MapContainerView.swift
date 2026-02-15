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
    @EnvironmentObject var detailSheetRouter: DetailSheetRouter
    @StateObject private var viewModel: MapViewModel
    @StateObject private var toastManager = ToastManager()

    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var isSearchExpanded = false // 新增：控制搜尋欄展開狀態
    @State private var createAskLocation: CreateAskLocation?
    @State private var searchLocation: SearchLocationMarker?
    @State private var hideMarkers = false

    // Sheet 控制
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
        .sheet(item: $clusterSheetData) { data in
            ClusterGridSheetView(
                items: data.items,
                recordRepository: container.recordRepository,
                askRepository: container.askRepository,
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
            detailSheetRouter.open(.record(id: image.recordId, imageIndex: image.displayOrder))

        case .ask(let ask):
            detailSheetRouter.open(.ask(id: ask.id))
        }
    }

    // MARK: - Top Controls

    private var topControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 第一行：搜尋欄和模式切換按鈕（固定在頂部）
            HStack(spacing: 12) {
                // 搜尋欄（建議列表會浮在上層，不影響佈局）
                MapSearchBar(
                    searchText: $searchText,
                    isSearchActive: $isSearchActive,
                    isExpanded: $isSearchExpanded,
                    mapRegion: viewModel.region,
                    onSearchResultSelected: { result in
                        searchLocation = SearchLocationMarker(
                            coordinate: result.coordinate,
                            title: result.mapItem.name ?? searchText,
                            subtitle: result.mapItem.placemark.title
                        )
                        isSearchActive = false
                        withAnimation {
                            viewModel.region = result.adjustedRegion
                        }
                    },
                    onSearchCleared: {
                        searchLocation = nil
                        hideMarkers = false
                    }
                )
                // 搜尋展開時填滿剩餘空間
                .frame(maxWidth: isSearchExpanded ? .infinity : nil)
                
                // 模式切換按鈕（固定位置）
                if isSearchExpanded {
                    modeSwitcherCompact
                        .transition(.scale.combined(with: .opacity))
                } else {
                    modeSwitcher
                        .transition(.scale.combined(with: .opacity))
                }
                
                // 只有收合時才需要 Spacer（展開時搜尋欄會填滿）
                if !isSearchExpanded {
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSearchExpanded)

            // 第二行：隱藏標點按鈕（建議列表展開時不顯示）
            if searchLocation != nil && !isSearchActive {
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
                        .background(hideMarkers ? Color.brandBlue : Color(.systemBackground))
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.1), radius: 3)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isSearchActive)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: searchLocation)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isSearchActive)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
            HStack {
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
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 75) // TabBar 高度調整後：約 55pt + 底部安全區域 20pt
        }
    }

    @Namespace private var modeSwitcherAnimation
    
    private var modeSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(MapMode.allCases, id: \.self) { mode in
                Button {
                    // 觸覺反饋
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        viewModel.switchMode(to: mode)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.iconName)
                            .font(.system(size: 14, weight: .semibold))
                            .scaleEffect(viewModel.currentMode == mode ? 1.1 : 1.0)
                            .rotationEffect(.degrees(viewModel.currentMode == mode ? 0 : -8))
                        
                        Text(mode.rawValue)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(viewModel.currentMode == mode ? .white : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background {
                        if viewModel.currentMode == mode {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: mode == .record 
                                            ? [Color.brandBlue, Color.brandBlue.opacity(0.85)]
                                            : [Color.brandOrange, Color.brandOrange.opacity(0.85)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: (mode == .record ? Color.brandBlue : Color.brandOrange).opacity(0.35), radius: 6, x: 0, y: 3)
                                .matchedGeometryEffect(id: "modeBackground", in: modeSwitcherAnimation)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(ModeSwitchButtonStyle(isSelected: viewModel.currentMode == mode))
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.separator).opacity(0.15), lineWidth: 0.5)
        )
    }
    
    // MARK: - Compact Mode Switcher
    
    /// 緊湊版地圖模式切換器（搜尋展開時顯示）
    private var modeSwitcherCompact: some View {
        Button {
            // 觸覺反饋
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // 切換到另一個模式
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                let nextMode: MapMode = viewModel.currentMode == .record ? .ask : .record
                viewModel.switchMode(to: nextMode)
            }
        } label: {
            ZStack {
                // 背景漸變
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: viewModel.currentMode == .record 
                                ? [Color.brandBlue, Color.brandBlue.opacity(0.8)]
                                : [Color.brandOrange, Color.brandOrange.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: (viewModel.currentMode == .record ? Color.brandBlue : Color.brandOrange).opacity(0.4),
                           radius: 8, x: 0, y: 4)
                
                // 圖標（帶 3D 翻轉效果）
                Image(systemName: viewModel.currentMode.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .rotation3DEffect(
                        .degrees(viewModel.currentMode == .record ? 0 : 180),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .scaleEffect(1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.65), value: viewModel.currentMode)
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(CompactModeSwitchButtonStyle())
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

/// 模式切換按鈕樣式
struct ModeSwitchButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 緊湊版模式切換按鈕樣式
struct CompactModeSwitchButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .brightness(configuration.isPressed ? -0.1 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Supporting Types

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
        .environmentObject(NavigationCoordinator())
        .environmentObject(DetailSheetRouter())
}
