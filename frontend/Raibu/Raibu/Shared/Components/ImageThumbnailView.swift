//
//  ImageThumbnailView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI

/// 圖片縮圖視圖 (地圖標點使用，含白色邊框)
struct ImageThumbnailView: View {
    let url: String
    let size: CGFloat
    let borderWidth: CGFloat
    
    init(url: String, size: CGFloat = 44, borderWidth: CGFloat = 2) {
        self.url = url
        self.size = size
        self.borderWidth = borderWidth
    }
    
    var body: some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .empty:
                placeholderView
                
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                
            case .failure:
                placeholderView
                
            @unknown default:
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white, lineWidth: borderWidth)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 2)
    }
    
    private var placeholderView: some View {
        Circle()
            .fill(Color(.systemGray4))
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: size * 0.4))
                    .foregroundColor(.secondary)
            )
    }
}

/// 方形縮圖視圖 (列表使用)
struct SquareThumbnailView: View {
    let url: String
    let size: CGFloat
    let cornerRadius: CGFloat
    
    init(url: String, size: CGFloat = 60, cornerRadius: CGFloat = 8) {
        self.url = url
        self.size = size
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .empty:
                placeholderView
                
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                
            case .failure:
                placeholderView
                
            @unknown default:
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
    
    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.systemGray5))
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: size * 0.4))
                    .foregroundColor(.secondary)
            )
    }
}

#Preview {
    VStack(spacing: 30) {
        // 圓形縮圖 (地圖用)
        HStack(spacing: 20) {
            ImageThumbnailView(url: "https://picsum.photos/100", size: 44)
            ImageThumbnailView(url: "invalid-url", size: 44)
            ImageThumbnailView(url: "https://picsum.photos/101", size: 60)
        }
        
        // 方形縮圖 (列表用)
        HStack(spacing: 20) {
            SquareThumbnailView(url: "https://picsum.photos/100")
            SquareThumbnailView(url: "invalid-url")
            SquareThumbnailView(url: "https://picsum.photos/101", size: 80, cornerRadius: 12)
        }
    }
    .padding()
    .background(Color(.systemGray6))
}
