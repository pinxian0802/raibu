//
//  ShimmerView.swift
//  Raibu
//
//  Created on 2026/01/01.
//

import SwiftUI

// MARK: - Shimmer Modifier

/// 為任何 View 加上 shimmer 動畫效果
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.appOnPrimary.opacity(0.4),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                }
            )
            .clipped()
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.2)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    /// 套用 shimmer 效果
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Shimmer Shapes

/// 矩形 shimmer 佔位元件
struct ShimmerBox: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 4
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
            .shimmer()
    }
}

/// 圓形 shimmer 佔位元件（頭像用）
struct ShimmerCircle: View {
    var size: CGFloat = 40
    
    var body: some View {
        Circle()
            .fill(Color(.systemGray5))
            .frame(width: size, height: size)
            .shimmer()
    }
}

/// 正方形圓角 shimmer 佔位元件（縮圖用）
struct ShimmerSquare: View {
    var size: CGFloat = 60
    var cornerRadius: CGFloat = 8
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.systemGray5))
            .frame(width: size, height: size)
            .shimmer()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ShimmerBox(width: 200, height: 20)
        ShimmerBox(width: 150, height: 16)
        ShimmerCircle(size: 50)
        ShimmerSquare(size: 80)
    }
    .padding()
}
