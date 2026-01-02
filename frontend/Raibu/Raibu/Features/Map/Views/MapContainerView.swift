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
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @StateObject private var viewModel: MapViewModel
    @StateObject private var toastManager = ToastManager()
    
    @State private var searchText = ""
    @State private var createAskLocation: CreateAskLocation?
    
    // Sheet 控制
    @State private var selectedDetailItem: DetailSheetItem?
    @State private var clusterSheetData: ClusterSheetData?
    
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
        .sheet(item: $createAskLocation, onDismiss: {
            // 刷新地圖資料以顯示新建立的詢問
            Task {
                await viewModel.fetchDataForCurrentRegion()
            }
        }) { location in
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
            clusters: viewModel.clusters,
            currentMode: viewModel.currentMode,
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
}

// MARK: - Detail Sheet Item

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

// MARK: - Create Ask Location

struct CreateAskLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Cluster Sheet Data

struct ClusterSheetData: Identifiable {
    let id = UUID()
    let items: [ClusterItem]
}

// MARK: - Map UIViewRepresentable (用於長按座標轉換)

struct MapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let clusters: [ClusterResult]
    let currentMode: MapMode
    let onClusterTapped: (ClusterResult) -> Void
    let onLongPress: (CLLocationCoordinate2D) -> Void
    let onRegionChanged: (CGSize) -> Void
    
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
    
    /// 產生群集的唯一識別 ID
    private func clusterIdentifier(for cluster: ClusterResult) -> String {
        // 使用所有項目的 ID 排序後組合，確保相同內容的群集有相同的 ID
        let itemIds = cluster.items.map { $0.id }.sorted().joined(separator: "_")
        return itemIds
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
            parent.onRegionChanged(mapView.bounds.size)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
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
                    annotationView?.image = createAskIcon()
                } else if case .recordImage(let image) = cluster.items[0] {
                    // 直接載入縮圖（無 placeholder）
                    loadThumbnail(for: annotationView, urlString: image.thumbnailPublicUrl, badgeCount: nil)
                }
            } else {
                // 群聚：取得最新的圖片 URL（假設第一個是最新的，或需要排序）
                if clusterAnnotation.mode == .record {
                    // 找到群聚中的第一張圖片（作為代表）
                    if let firstRecordImage = cluster.items.compactMap({ item -> MapRecordImage? in
                        if case .recordImage(let image) = item { return image }
                        return nil
                    }).first {
                        loadThumbnail(for: annotationView, urlString: firstRecordImage.thumbnailPublicUrl, badgeCount: cluster.count)
                    }
                } else {
                    // Ask 模式的群聚仍使用數字圖示
                    annotationView?.image = createClusterIcon(count: cluster.count, mode: clusterAnnotation.mode)
                }
            }
            
            return annotationView
        }
        
        // MARK: - Image Cache
        
        /// 圖片快取
        private static let imageCache = NSCache<NSString, UIImage>()
        
        /// Badge 尺寸常數（需與 createThumbnailWithBadge 保持一致）
        private var badgeSize: CGFloat { 28 }
        
        /// 非同步載入縮圖（帶快取）
        private func loadThumbnail(for annotationView: MKAnnotationView?, urlString: String, badgeCount: Int?) {
            guard let url = URL(string: urlString) else { return }
            
            let cacheKey = "\(urlString)_\(badgeCount ?? 0)" as NSString
            
            // 檢查快取
            if let cachedImage = Self.imageCache.object(forKey: cacheKey) {
                annotationView?.image = cachedImage
                // 有 badge 時需要調整 centerOffset
                if badgeCount != nil {
                    let badgeOffset = badgeSize / 2
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
            let badgeOffsetValue = badgeSize / 2
            
            URLSession.shared.dataTask(with: request) { [weak annotationView] data, _, _ in
                guard let data = data, let originalImage = UIImage(data: data) else { return }
                
                let thumbnailImage: UIImage
                if let count = badgeCount {
                    thumbnailImage = self.createThumbnailWithBadge(from: originalImage, count: count)
                } else {
                    thumbnailImage = self.createThumbnailIcon(from: originalImage)
                }
                
                // 儲存到快取
                Self.imageCache.setObject(thumbnailImage, forKey: cacheKey)
                
                DispatchQueue.main.async {
                    annotationView?.image = thumbnailImage
                    // 有 badge 時，圖片右上角有額外空間，需要調整 centerOffset
                    // 讓正方形縮圖的中心對準座標位置
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
        
        // MARK: - Icon Creation
        
        /// 縮圖 icon 尺寸（與群聚演算法一致）
        private var iconSize: CGFloat { ClusteringService.markerIconSize }
        
        /// 圓角半徑
        private var cornerRadius: CGFloat { 12 }
        
        /// 從圖片建立正方形縮圖 icon（帶白色邊框和圓角）
        private func createThumbnailIcon(from image: UIImage) -> UIImage {
            let size = CGSize(width: iconSize, height: iconSize)
            let borderWidth: CGFloat = 3
            let renderer = UIGraphicsImageRenderer(size: size)
            
            return renderer.image { context in
                let rect = CGRect(origin: .zero, size: size)
                let innerRect = rect.insetBy(dx: borderWidth, dy: borderWidth)
                
                // 繪製白色邊框背景（圓角正方形）
                let borderPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
                UIColor.white.setFill()
                borderPath.fill()
                
                // 裁切成圓角正方形並繪製圖片
                let clipPath = UIBezierPath(roundedRect: innerRect, cornerRadius: cornerRadius - borderWidth)
                clipPath.addClip()
                
                // 計算裁切區域（取中央正方形）
                let imageSize = image.size
                let minSide = min(imageSize.width, imageSize.height)
                let cropRect = CGRect(
                    x: (imageSize.width - minSide) / 2,
                    y: (imageSize.height - minSide) / 2,
                    width: minSide,
                    height: minSide
                )
                
                if let cgImage = image.cgImage?.cropping(to: cropRect) {
                    UIImage(cgImage: cgImage).draw(in: innerRect)
                } else {
                    image.draw(in: innerRect)
                }
            }
        }
        
        /// 從圖片建立帶數量 badge 的縮圖（右上角顯示群聚數量）
        private func createThumbnailWithBadge(from image: UIImage, count: Int) -> UIImage {
            let borderWidth: CGFloat = 3
            let badgeSize: CGFloat = 28
            // badge 偏移量需要足夠大，讓整個 badge 圓圈都在渲染區域內
            // badge 圓心在正方形右上角，所以需要 badgeSize/2 的空間
            let badgeOffset: CGFloat = badgeSize / 2
            
            // 擴大渲染區域以容納 badge 的偏移
            let totalSize = CGSize(width: iconSize + badgeOffset, height: iconSize + badgeOffset)
            let renderer = UIGraphicsImageRenderer(size: totalSize)
            
            return renderer.image { context in
                // 正方形縮圖位置（向下和向左偏移以留出 badge 空間）
                let thumbnailOrigin = CGPoint(x: 0, y: badgeOffset)
                let thumbnailRect = CGRect(origin: thumbnailOrigin, size: CGSize(width: iconSize, height: iconSize))
                let innerRect = thumbnailRect.insetBy(dx: borderWidth, dy: borderWidth)
                
                // 繪製白色邊框背景（圓角正方形）
                let borderPath = UIBezierPath(roundedRect: thumbnailRect, cornerRadius: cornerRadius)
                UIColor.white.setFill()
                borderPath.fill()
                
                // 儲存狀態（用於後續繪製 badge）
                context.cgContext.saveGState()
                
                // 裁切成圓角正方形並繪製圖片
                let clipPath = UIBezierPath(roundedRect: innerRect, cornerRadius: cornerRadius - borderWidth)
                clipPath.addClip()
                
                // 計算裁切區域（取中央正方形）
                let imageSize = image.size
                let minSide = min(imageSize.width, imageSize.height)
                let cropRect = CGRect(
                    x: (imageSize.width - minSide) / 2,
                    y: (imageSize.height - minSide) / 2,
                    width: minSide,
                    height: minSide
                )
                
                if let cgImage = image.cgImage?.cropping(to: cropRect) {
                    UIImage(cgImage: cgImage).draw(in: innerRect)
                } else {
                    image.draw(in: innerRect)
                }
                
                // 恢復狀態以繪製 badge
                context.cgContext.restoreGState()
                
                // 繪製右上角的數量 badge（圓心位於正方形右上角）
                // badge 圓心 x = iconSize（正方形右邊緣）
                // badge 圓心 y = badgeOffset（正方形上邊緣）
                let badgeCenterX = iconSize
                let badgeCenterY = badgeOffset
                let badgeRect = CGRect(
                    x: badgeCenterX - badgeSize / 2,
                    y: badgeCenterY - badgeSize / 2,
                    width: badgeSize,
                    height: badgeSize
                )
                
                // Badge 背景（藍色圓形 + 白色邊框）
                UIColor.white.setFill()
                context.cgContext.fillEllipse(in: badgeRect)
                
                let innerBadgeRect = badgeRect.insetBy(dx: 2, dy: 2)
                UIColor.systemBlue.setFill()
                context.cgContext.fillEllipse(in: innerBadgeRect)
                
                // Badge 數字
                let text = "\(count)" as NSString
                let fontSize: CGFloat = count >= 100 ? 10 : (count >= 10 ? 12 : 14)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: fontSize),
                    .foregroundColor: UIColor.white
                ]
                let textSize = text.size(withAttributes: attributes)
                let textRect = CGRect(
                    x: badgeRect.midX - textSize.width / 2,
                    y: badgeRect.midY - textSize.height / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                text.draw(in: textRect, withAttributes: attributes)
            }
        }
        
        private func createAskIcon() -> UIImage {
            let size = CGSize(width: iconSize, height: iconSize)
            let borderWidth: CGFloat = 3
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                UIColor.white.setFill()
                context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
                
                UIColor.orange.setFill()
                context.cgContext.fillEllipse(in: CGRect(x: borderWidth, y: borderWidth, width: iconSize - borderWidth * 2, height: iconSize - borderWidth * 2))
                
                // 置中繪製問號圖示
                let symbolSize: CGFloat = 40
                let iconRect = CGRect(
                    x: (iconSize - symbolSize) / 2,
                    y: (iconSize - symbolSize) / 2,
                    width: symbolSize,
                    height: symbolSize
                )
                let config = UIImage.SymbolConfiguration(pointSize: 32, weight: .bold)
                if let icon = UIImage(systemName: "questionmark", withConfiguration: config) {
                    icon.withTintColor(.white, renderingMode: .alwaysOriginal).draw(in: iconRect)
                }
            }
        }
        
        private func createClusterIcon(count: Int, mode: MapMode) -> UIImage {
            let size = CGSize(width: iconSize, height: iconSize)
            let borderWidth: CGFloat = 3
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                UIColor.white.setFill()
                context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
                
                let color = mode == .record ? UIColor.systemBlue : UIColor.orange
                color.setFill()
                context.cgContext.fillEllipse(in: CGRect(x: borderWidth, y: borderWidth, width: iconSize - borderWidth * 2, height: iconSize - borderWidth * 2))
                
                // 繪製數字（置中）
                let text = "\(count)" as NSString
                let fontSize: CGFloat = count >= 100 ? 20 : (count >= 10 ? 24 : 28)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: fontSize),
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
    let clusterIdentifier: String
    
    var coordinate: CLLocationCoordinate2D {
        cluster.center
    }
    
    init(cluster: ClusterResult, mode: MapMode, identifier: String) {
        self.cluster = cluster
        self.mode = mode
        self.clusterIdentifier = identifier
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

