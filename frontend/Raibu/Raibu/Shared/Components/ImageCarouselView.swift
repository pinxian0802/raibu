//
//  ImageCarouselView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI
import CoreLocation

// MARK: - Image Cache Manager

/// 圖片快取管理器 (單例)
final class ImageCache {
    static let shared = ImageCache()
    
    private var cache = NSCache<NSString, UIImage>()
    
    private init() {
        // 設定快取限制
        cache.countLimit = 100  // 最多快取 100 張圖片
        cache.totalCostLimit = 100 * 1024 * 1024  // 最多 100MB
    }
    
    func get(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

// MARK: - Cached Async Image

/// 帶快取的非同步圖片視圖
struct CachedAsyncImage<Content: View, Placeholder: View, ErrorView: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    let errorView: () -> ErrorView
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    @State private var loadFailed = false
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder errorView: @escaping () -> ErrorView
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        self.errorView = errorView
    }
    
    var body: some View {
        Group {
            if let image = loadedImage {
                content(Image(uiImage: image))
            } else if loadFailed {
                errorView()
            } else {
                placeholder()
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else {
            loadFailed = true
            isLoading = false
            return
        }
        
        let cacheKey = url.absoluteString
        
        // 先檢查快取
        if let cachedImage = ImageCache.shared.get(forKey: cacheKey) {
            loadedImage = cachedImage
            isLoading = false
            return
        }
        
        // 如果已經有圖片或已失敗，不重新載入
        if loadedImage != nil || loadFailed {
            return
        }
        
        // 從網路載入
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    // 存入快取
                    ImageCache.shared.set(image, forKey: cacheKey)
                    
                    await MainActor.run {
                        loadedImage = image
                        isLoading = false
                    }
                } else {
                    await MainActor.run {
                        loadFailed = true
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    loadFailed = true
                    isLoading = false
                }
            }
        }
    }
}

/// 圖片輪播視圖 (支援錨點定位和點擊跳轉)
struct ImageCarouselView: View {
    let images: [ImageMedia]
    let initialIndex: Int  // 錨點：被點擊的圖片 Index
    var onImageTap: ((ImageMedia) -> Void)?  // 點擊圖片的回調
    var onLocationTap: ((ImageMedia) -> Void)?  // 點擊「查看位置」按鈕的回調
    
    @State private var currentIndex: Int = 0
    @State private var hasSetInitialIndex = false
    
    init(
        images: [ImageMedia],
        initialIndex: Int = 0,
        onImageTap: ((ImageMedia) -> Void)? = nil,
        onLocationTap: ((ImageMedia) -> Void)? = nil
    ) {
        self.images = images
        self.initialIndex = initialIndex
        self.onImageTap = onImageTap
        self.onLocationTap = onLocationTap
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // 圖片輪播
            TabView(selection: $currentIndex) {
                ForEach(images.indices, id: \.self) { index in
                    imageView(for: images[index])
                        .tag(index)
                        .onTapGesture {
                            onImageTap?(images[index])
                        }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // 自訂頁面指示器
            if images.count > 1 {
                pageIndicators
            }
        }
        .onAppear {
            // 錨點定位：只在首次出現時設定
            if !hasSetInitialIndex {
                currentIndex = min(initialIndex, images.count - 1)
                hasSetInitialIndex = true
            }
        }
    }
    
    // MARK: - Subviews
    
    private func imageView(for image: ImageMedia) -> some View {
        VStack(spacing: 8) {
            // 圖片區
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(
                    url: URL(string: image.originalPublicUrl),
                    content: { loadedImage in
                        loadedImage
                            .resizable()
                            .scaledToFit()
                    },
                    placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .shimmer()
                    },
                    errorView: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                            )
                    }
                )
                
                // 查看位置按鈕 - 只有圖片有位置資訊時顯示
                if image.location != nil {
                    Button {
                        onLocationTap?(image)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12, weight: .medium))
                            Text("查看位置")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                        )
                    }
                    .padding(12)
                }
            }
            
            // 地址與時間顯示區（靠左對齊）
            VStack(alignment: .leading, spacing: 4) {
                // 地址
                if image.location != nil {
                    // 優先使用資料庫中的地址
                    if let address = image.address, !address.isEmpty {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    } else {
                        // 回退：即時 geocoding（用於舊資料）
                        AddressText(location: image.location!)
                    }
                }
                
                // 拍攝時間
                if let capturedAt = image.capturedAt {
                    Text(formatCapturedAt(capturedAt))
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
        }
    }
    
    private var pageIndicators: some View {
        HStack(spacing: 6) {
            ForEach(images.indices, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.primary : Color.secondary.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .animation(.spring(response: 0.3), value: currentIndex)
            }
        }
        .padding(.bottom, 8)
    }
    
    /// 格式化拍攝時間
    private func formatCapturedAt(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - AddressText (回退用即時 Geocoding)

/// 即時逆向地理編碼元件 (用於舊資料回退)
private struct AddressText: View {
    let location: Coordinate
    
    @State private var address: String = "載入地址中..."
    
    var body: some View {
        Text(address)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(2)
            .task {
                await fetchAddress()
            }
    }
    
    private func fetchAddress() async {
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(latitude: location.lat, longitude: location.lng)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(clLocation)
            if let placemark = placemarks.first {
                var addressParts: [String] = []
                
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
                
                address = addressParts.isEmpty ? "未知地點" : addressParts.joined(separator: ", ")
            }
        } catch {
            address = "無法取得地址"
        }
    }
}

#Preview {
    ImageCarouselView(
        images: [
            ImageMedia(
                id: "1",
                originalPublicUrl: "https://picsum.photos/400/300",
                thumbnailPublicUrl: "https://picsum.photos/100/75",
                location: Coordinate(lat: 25.033, lng: 121.565),
                capturedAt: Date(),
                displayOrder: 0,
                address: "台北101, 信義區"
            ),
            ImageMedia(
                id: "2",
                originalPublicUrl: "https://picsum.photos/401/300",
                thumbnailPublicUrl: "https://picsum.photos/101/75",
                location: nil,
                capturedAt: Date(),
                displayOrder: 1,
                address: nil
            )
        ],
        initialIndex: 0
    )
    .frame(height: 300)
}
