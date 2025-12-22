//
//  MapContainerView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI
import MapKit

/// 地圖主容器視圖
struct MapContainerView: View {
    @EnvironmentObject var container: DIContainer
    
    var body: some View {
        MapContentView(container: container)
    }
}

/// 實際地圖內容（使用 @StateObject 正確觀察 ViewModel）
struct MapContentView: View {
    let container: DIContainer
    @StateObject private var viewModel: MapViewModel
    @StateObject private var toastManager = ToastManager()
    
    @State private var searchText = ""
    @State private var showCreateRecord = false
    @State private var showCreateAsk = false
    @State private var longPressLocation: CLLocationCoordinate2D?
    
    // Sheet 控制
    @State private var showDetailSheet = false
    @State private var showClusterListSheet = false
    @State private var selectedRecordId: String?
    @State private var selectedAskId: String?
    @State private var clusterListItems: [ClusterItem] = []
    
    init(container: DIContainer) {
        self.container = container
        _viewModel = StateObject(wrappedValue: MapViewModel(
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
            
            // 載入指示器
            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .sheet(isPresented: $showDetailSheet) {
            detailSheet
        }
        .sheet(isPresented: $showClusterListSheet) {
            clusterListSheet
        }
        .sheet(isPresented: $showCreateRecord, onDismiss: {
            // 刷新地圖資料以顯示新建立的紀錄
            Task {
                await viewModel.fetchDataForCurrentRegion()
            }
        }) {
            CreateRecordFullView(
                uploadService: container.uploadService,
                recordRepository: container.recordRepository
            )
        }
        .sheet(isPresented: $showCreateAsk, onDismiss: {
            // 刷新地圖資料以顯示新建立的詢問
            Task {
                await viewModel.fetchDataForCurrentRegion()
            }
        }) {
            if let location = longPressLocation {
                CreateAskFullView(
                    initialLocation: location,
                    uploadService: container.uploadService,
                    askRepository: container.askRepository
                )
            }
        }
        .toastContainer(toastManager)
    }
    
    // MARK: - Map View
    
    private var mapView: some View {
        MapViewRepresentable(
            region: $viewModel.region,
            clusters: viewModel.clusters,
            currentMode: viewModel.currentMode,
            onClusterTapped: { cluster in
                handleClusterTapped(cluster)
            },
            onLongPress: { coordinate in
                if viewModel.currentMode == .ask {
                    longPressLocation = coordinate
                    showCreateAsk = true
                }
            },
            onRegionChanged: {
                Task {
                    await viewModel.fetchDataForCurrentRegion()
                }
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
                clusterListItems = items
                showClusterListSheet = true
            }
        }
    }
    
    private func handleSingleItemTap(_ item: ClusterItem) {
        switch item {
        case .recordImage(let image):
            selectedRecordId = image.recordId
            selectedAskId = nil
            showDetailSheet = true
            
        case .ask(let ask):
            selectedAskId = ask.id
            selectedRecordId = nil
            showDetailSheet = true
        }
    }
    
    // MARK: - Top Controls
    
    private var topControls: some View {
        VStack(spacing: 12) {
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("搜尋地點", text: $searchText)
                        .textFieldStyle(.plain)
                        .submitLabel(.search)
                        .onSubmit {
                            Task {
                                await viewModel.searchAndMoveTo(query: searchText)
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
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
                        viewModel.moveToUserLocation()
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.15), radius: 5)
                    }
                    
                    // 新增按鈕
                    if viewModel.currentMode == .record {
                        Button {
                            showCreateRecord = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                    }
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
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.switchMode(to: mode)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.iconName)
                        Text(mode.rawValue)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(viewModel.currentMode == mode ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        viewModel.currentMode == mode ?
                        (mode == .record ? Color.blue : Color.orange) :
                        Color.clear
                    )
                    .cornerRadius(20)
                }
            }
        }
        .padding(4)
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.15), radius: 5)
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        Color.black.opacity(0.001)
            .overlay(
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(20)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.15), radius: 10)
            )
    }
    
    // MARK: - Sheets
    
    @ViewBuilder
    private var detailSheet: some View {
        if let recordId = selectedRecordId {
            RecordDetailSheetView(
                recordId: recordId,
                recordRepository: container.recordRepository,
                replyRepository: container.replyRepository
            )
        } else if let askId = selectedAskId {
            AskDetailSheetView(
                askId: askId,
                askRepository: container.askRepository,
                replyRepository: container.replyRepository
            )
        }
    }
    
    private var clusterListSheet: some View {
        ClusterListView(
            items: clusterListItems,
            onItemSelected: { item in
                showClusterListSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    handleSingleItemTap(item)
                }
            }
        )
    }
}

// MARK: - Map UIViewRepresentable (用於長按座標轉換)

struct MapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let clusters: [ClusterResult]
    let currentMode: MapMode
    let onClusterTapped: (ClusterResult) -> Void
    let onLongPress: (CLLocationCoordinate2D) -> Void
    let onRegionChanged: () -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        
        // 長按手勢
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(context.coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPress)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新 region
        let currentRegion = mapView.region
        if abs(currentRegion.center.latitude - region.center.latitude) > 0.0001 ||
           abs(currentRegion.center.longitude - region.center.longitude) > 0.0001 {
            mapView.setRegion(region, animated: true)
        }
        
        // 更新標註
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        for cluster in clusters {
            let annotation = ClusterAnnotation(cluster: cluster, mode: currentMode)
            mapView.addAnnotation(annotation)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        
        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let mapView = gesture.view as? MKMapView else { return }
            
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onLongPress(coordinate)
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
            parent.onRegionChanged()
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let clusterAnnotation = annotation as? ClusterAnnotation else { return nil }
            
            let identifier = "ClusterAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
            }
            
            annotationView?.annotation = annotation
            
            // 設定圖示
            let cluster = clusterAnnotation.cluster
            if cluster.isSingle {
                if case .ask = cluster.items[0] {
                    annotationView?.image = createAskIcon()
                } else if case .recordImage(let image) = cluster.items[0] {
                    // 使用縮圖 (簡化版：使用系統圖示)
                    annotationView?.image = createRecordIcon()
                }
            } else {
                annotationView?.image = createClusterIcon(count: cluster.count, mode: clusterAnnotation.mode)
            }
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let clusterAnnotation = view.annotation as? ClusterAnnotation else { return }
            mapView.deselectAnnotation(view.annotation, animated: false)
            parent.onClusterTapped(clusterAnnotation.cluster)
        }
        
        // MARK: - Icon Creation
        
        private func createRecordIcon() -> UIImage {
            let size = CGSize(width: 44, height: 44)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                // 白色邊框圓形
                UIColor.white.setFill()
                context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
                
                // 藍色填充
                UIColor.systemBlue.setFill()
                context.cgContext.fillEllipse(in: CGRect(x: 2, y: 2, width: 40, height: 40))
                
                // 相機圖示
                let iconRect = CGRect(x: 12, y: 12, width: 20, height: 20)
                let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
                if let icon = UIImage(systemName: "camera.fill", withConfiguration: config) {
                    icon.withTintColor(.white, renderingMode: .alwaysOriginal).draw(in: iconRect)
                }
            }
        }
        
        private func createAskIcon() -> UIImage {
            let size = CGSize(width: 44, height: 44)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                UIColor.white.setFill()
                context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
                
                UIColor.orange.setFill()
                context.cgContext.fillEllipse(in: CGRect(x: 2, y: 2, width: 40, height: 40))
                
                let iconRect = CGRect(x: 12, y: 12, width: 20, height: 20)
                let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
                if let icon = UIImage(systemName: "questionmark", withConfiguration: config) {
                    icon.withTintColor(.white, renderingMode: .alwaysOriginal).draw(in: iconRect)
                }
            }
        }
        
        private func createClusterIcon(count: Int, mode: MapMode) -> UIImage {
            let size = CGSize(width: 44, height: 44)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                UIColor.white.setFill()
                context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
                
                let color = mode == .record ? UIColor.systemBlue : UIColor.orange
                color.setFill()
                context.cgContext.fillEllipse(in: CGRect(x: 2, y: 2, width: 40, height: 40))
                
                // 繪製數字
                let text = "\(count)" as NSString
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 16),
                    .foregroundColor: UIColor.white
                ]
                let textSize = text.size(withAttributes: attributes)
                let textRect = CGRect(
                    x: (size.width - textSize.width) / 2,
                    y: (size.height - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                text.draw(in: textRect, withAttributes: attributes)
            }
        }
    }
}

// MARK: - Cluster Annotation

class ClusterAnnotation: NSObject, MKAnnotation {
    let cluster: ClusterResult
    let mode: MapMode
    
    var coordinate: CLLocationCoordinate2D {
        cluster.center
    }
    
    init(cluster: ClusterResult, mode: MapMode) {
        self.cluster = cluster
        self.mode = mode
    }
}

// MARK: - Cluster List View

struct ClusterListView: View {
    let items: [ClusterItem]
    let onItemSelected: (ClusterItem) -> Void
    
    var body: some View {
        NavigationView {
            List(items) { item in
                Button {
                    onItemSelected(item)
                } label: {
                    clusterItemRow(item)
                }
            }
            .navigationTitle("選擇標點")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    @ViewBuilder
    private func clusterItemRow(_ item: ClusterItem) -> some View {
        switch item {
        case .recordImage(let image):
            HStack(spacing: 12) {
                SquareThumbnailView(url: image.thumbnailPublicUrl, size: 50)
                
                Text("紀錄標點")
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            
        case .ask(let ask):
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "questionmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("詢問標點")
                        .foregroundColor(.primary)
                    
                    Text(ask.question)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Profile View (完整版)

struct ProfileView: View {
    @EnvironmentObject var container: DIContainer
    
    var body: some View {
        ProfileFullView(userRepository: container.userRepository)
    }
}

#Preview {
    MapContainerView()
        .environmentObject(DIContainer())
}

