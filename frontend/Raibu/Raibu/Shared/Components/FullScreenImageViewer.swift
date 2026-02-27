//
//  FullScreenImageViewer.swift
//  Raibu
//
//  Created on 2026/02/24.
//

import SwiftUI
import Kingfisher

// MARK: - FullScreenImageViewer

/// 全螢幕圖片查看器
/// 使用 ZStack overlay 實現，圖片以 .fit 完整顯示（不裁切）
struct FullScreenImageViewer: View {
    let images: [ImageMedia]
    let initialIndex: Int
    @Binding var isPresented: Bool
    
    @State private var currentIndex: Int = 0
    @State private var backgroundOpacity: Double = 0
    @State private var viewerScale: CGFloat = 0.85
    @State private var dragOffset: CGSize = .zero
    @State private var dragScale: CGFloat = 1.0
    @State private var imageScale: CGFloat = 1.0
    @State private var lastImageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var lastImageOffset: CGSize = .zero
    @State private var isDraggingVertically = false
    @State private var uiOpacity: Double = 0
    
    private let dismissThreshold: CGFloat = 120
    private let dragDismissVelocityThreshold: CGFloat = 800
    
    var body: some View {
        ZStack {
            // 黑色背景
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissViewer()
                }
            
            // 圖片內容
            TabView(selection: $currentIndex) {
                ForEach(images.indices, id: \.self) { index in
                    zoomableImageView(for: images[index], at: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .offset(dragOffset)
            .scaleEffect(dragScale * viewerScale)
            
            // 上下 UI 控制
            VStack(spacing: 0) {
                // 關閉按鈕
                HStack {
                    Button {
                        dismissViewer()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 22)
                    .padding(.top, 22)
                    Spacer()
                }
                .opacity(uiOpacity)
                
                Spacer()
                
                // 頁碼指示器 - 固定位置
                if images.count > 1 {
                    Text("\(currentIndex + 1) / \(images.count)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 16)
                }
                
                // 底部資訊區域 (地址 + 拍攝時間)
                let currentImage = images[min(currentIndex, images.count - 1)]
                VStack(spacing: 4) {
                    if let address = currentImage.address, !address.isEmpty {
                        Text(address)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    if let capturedAt = currentImage.capturedAt {
                        Text(formatCapturedAt(capturedAt))
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: currentIndex)
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
                .opacity(uiOpacity)
            }
        }
        .ignoresSafeArea(.all)
        .statusBarHidden(true)
        .onAppear {
            currentIndex = min(initialIndex, images.count - 1)
            // 使用兩段動畫：先快速淡入背景，再彈性縮放
            withAnimation(.easeOut(duration: 0.25)) {
                backgroundOpacity = 1.0
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82, blendDuration: 0.1)) {
                viewerScale = 1.0
            }
            withAnimation(.easeIn(duration: 0.2).delay(0.15)) {
                uiOpacity = 1.0
            }
        }
        .onChange(of: currentIndex) { _, _ in
            resetZoom()
        }
    }
    
    // MARK: - Zoomable Image
    
    @ViewBuilder
    private func zoomableImageView(for image: ImageMedia, at index: Int) -> some View {
        KFImage(URL(string: image.originalPublicUrl))
            .placeholder {
                ProgressView()
                    .tint(.white)
            }
            .retry(maxCount: 2, interval: .seconds(1))
            .cacheOriginalImage()
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(index == currentIndex ? imageScale : 1.0)
            .offset(index == currentIndex ? imageOffset : .zero)
            .gesture(index == currentIndex ? combinedGesture : nil)
            .simultaneousGesture(
                index == currentIndex
                    ? (imageScale > 1.05 ? panGesture : nil)
                    : nil
            )
            .simultaneousGesture(
                index == currentIndex && imageScale <= 1.05
                    ? verticalDismissGesture
                    : nil
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Gestures
    
    private var combinedGesture: some Gesture {
        pinchGesture
    }
    
    /// 垂直拖動手勢（僅在非縮放狀態下作用，不干擾 TabView 左右滑動）
    private var verticalDismissGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .global)
            .onChanged { value in
                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)
                
                // 判斷是否為垂直方向拖動
                if !isDraggingVertically {
                    if vertical > horizontal && vertical > 10 {
                        isDraggingVertically = true
                    } else {
                        return // 讓 TabView 處理水平滑動
                    }
                }
                
                guard isDraggingVertically else { return }
                
                let verticalDrag = value.translation.height
                if verticalDrag > 0 {
                    dragOffset = CGSize(width: value.translation.width * 0.4, height: verticalDrag)
                    let progress = min(verticalDrag / (dismissThreshold * 2.5), 1.0)
                    backgroundOpacity = 1.0 - progress * 0.6
                    dragScale = 1.0 - progress * 0.15
                    uiOpacity = 1.0 - progress * 1.5 // UI 提早淡出
                } else {
                    dragOffset = CGSize(width: 0, height: verticalDrag * 0.3)
                }
            }
            .onEnded { value in
                defer { isDraggingVertically = false }
                guard isDraggingVertically else { return }
                
                let verticalDrag = value.translation.height
                let verticalVelocity = value.predictedEndTranslation.height - value.translation.height
                
                if verticalDrag > dismissThreshold || verticalVelocity > dragDismissVelocityThreshold {
                    dismissViewer()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        dragOffset = .zero
                        backgroundOpacity = 1.0
                        dragScale = 1.0
                        uiOpacity = 1.0
                    }
                }
            }
    }
    
    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale = lastImageScale * value.magnification
                imageScale = max(1.0, min(newScale, 5.0))
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    if imageScale < 1.0 {
                        imageScale = 1.0
                    }
                    lastImageScale = imageScale
                    
                    if imageScale <= 1.0 {
                        imageOffset = .zero
                        lastImageOffset = .zero
                    }
                }
            }
    }
    
    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                imageOffset = CGSize(
                    width: lastImageOffset.width + value.translation.width,
                    height: lastImageOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastImageOffset = imageOffset
            }
    }
    
    // MARK: - Helpers
    
    private func dismissViewer() {
        // 同時執行淡出 + 縮小，使用較快的動畫
        withAnimation(.easeOut(duration: 0.25)) {
            backgroundOpacity = 0
            uiOpacity = 0
        }
        withAnimation(.easeOut(duration: 0.28)) {
            viewerScale = 0.8
            dragScale = dragScale * 0.9
            dragOffset = CGSize(
                width: dragOffset.width,
                height: dragOffset.height + 60
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            isPresented = false
            dragOffset = .zero
            dragScale = 1.0
            viewerScale = 0.85
            backgroundOpacity = 0
            uiOpacity = 0
            resetZoom()
        }
    }
    
    private func resetZoom() {
        imageScale = 1.0
        lastImageScale = 1.0
        imageOffset = .zero
        lastImageOffset = .zero
    }
    
    private func formatCapturedAt(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }
}

// MARK: - View Extension

extension View {
    /// 加入全螢幕圖片查看器 overlay
    func fullScreenImageViewer(
        isPresented: Binding<Bool>,
        images: [ImageMedia],
        initialIndex: Int
    ) -> some View {
        self.overlay {
            if isPresented.wrappedValue {
                FullScreenImageViewer(
                    images: images,
                    initialIndex: initialIndex,
                    isPresented: isPresented
                )
            }
        }
    }
}
