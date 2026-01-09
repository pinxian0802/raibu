//
//  CachedImage.swift
//  Raibu
//
//  Created on 2026/01/09.
//

import SwiftUI
import Kingfisher

// MARK: - CachedImage

/// 統一的快取圖片元件，封裝 Kingfisher
/// 提供記憶體 + 磁碟雙層快取，並支援自動重試
struct CachedImage<Placeholder: View>: View {
    let url: URL?
    let placeholder: () -> Placeholder
    
    init(
        url: URL?,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.placeholder = placeholder
    }
    
    var body: some View {
        KFImage(url)
            .placeholder { placeholder() }
            .retry(maxCount: 2, interval: .seconds(1))
            .cacheOriginalImage()
            .fade(duration: 0.2)
            .resizable()
    }
}

// MARK: - Convenience Extensions

extension CachedImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    /// 預設使用 ProgressView 作為 placeholder
    init(url: URL?) {
        self.url = url
        self.placeholder = { ProgressView() }
    }
}

// MARK: - Avatar Image

/// 圓形頭像專用快取圖片
struct CachedAvatarImage: View {
    let url: URL?
    let size: CGFloat
    
    init(url: URL?, size: CGFloat = 36) {
        self.url = url
        self.size = size
    }
    
    var body: some View {
        KFImage(url)
            .placeholder {
                Circle()
                    .fill(Color(.systemGray4))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.secondary)
                    )
            }
            .retry(maxCount: 2, interval: .seconds(1))
            .cacheOriginalImage()
            .fade(duration: 0.2)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
    }
}

// MARK: - Thumbnail Image

/// 方形縮圖專用快取圖片
struct CachedThumbnailImage: View {
    let url: URL?
    let size: CGFloat
    let cornerRadius: CGFloat
    
    init(url: URL?, size: CGFloat = 60, cornerRadius: CGFloat = 8) {
        self.url = url
        self.size = size
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        KFImage(url)
            .placeholder {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .shimmer()
            }
            .retry(maxCount: 2, interval: .seconds(1))
            .cacheOriginalImage()
            .fade(duration: 0.2)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
