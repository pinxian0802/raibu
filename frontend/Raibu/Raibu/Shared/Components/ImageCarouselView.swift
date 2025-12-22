//
//  ImageCarouselView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI

/// 圖片輪播視圖 (支援錨點定位)
struct ImageCarouselView: View {
    let images: [ImageMedia]
    let initialIndex: Int  // 錨點：被點擊的圖片 Index
    
    @State private var currentIndex: Int = 0
    @State private var hasSetInitialIndex = false
    
    init(images: [ImageMedia], initialIndex: Int = 0) {
        self.images = images
        self.initialIndex = initialIndex
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // 圖片輪播
            TabView(selection: $currentIndex) {
                ForEach(images.indices, id: \.self) { index in
                    imageView(for: images[index])
                        .tag(index)
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
        AsyncImage(url: URL(string: image.originalPublicUrl)) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        ProgressView()
                    )
                
            case .success(let loadedImage):
                loadedImage
                    .resizable()
                    .scaledToFit()
                
            case .failure:
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                    )
                
            @unknown default:
                EmptyView()
            }
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
                displayOrder: 0
            ),
            ImageMedia(
                id: "2",
                originalPublicUrl: "https://picsum.photos/401/300",
                thumbnailPublicUrl: "https://picsum.photos/101/75",
                location: nil,
                capturedAt: Date(),
                displayOrder: 1
            )
        ],
        initialIndex: 0
    )
    .frame(height: 300)
}
