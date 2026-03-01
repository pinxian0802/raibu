//
//  DetailSheetSkeleton.swift
//  Raibu
//
//  共用元件：詳情 Sheet 骨架載入畫面
//  對應現在的排版：作者列 → 圖片輪播 → 描述 → 底部回覆輸入列
//

import SwiftUI

/// 詳情 Sheet 的骨架載入畫面
/// - Parameters:
///   - showImageCarousel: 是否顯示圖片輪播區骨架
///   - contentTopPadding: 上方留白，對應 `contentTopPadding`
struct DetailSheetSkeleton: View {
    var showImageCarousel: Bool = true
    var contentTopPadding: CGFloat = 10

    // 對應 imageCardWidth / imageCardHeight
    private let cardWidth: CGFloat = 300
    private let cardHeight: CGFloat = 375

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        bodySection(totalWidth: proxy.size.width)
                            .frame(minHeight: proxy.size.height * 0.82, alignment: .top)
                    }
                    .padding(.top, contentTopPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollDisabled(true)

                Divider()
                replyInputBarSkeleton
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .shimmering()
    }

    // MARK: - Body

    private func bodySection(totalWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. 作者列
            authorRowSkeleton
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

            // 2. 圖片輪播（置中卡片，對應實際排版）
            if showImageCarousel {
                imageCarouselSkeleton(totalWidth: totalWidth)

                // metadata 列
                imageMetaRowSkeleton
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
            }

            // 3. 描述 + 互動列
            VStack(alignment: .leading, spacing: 14) {
                if showImageCarousel { Divider() }
                descriptionSkeleton
                interactionRowSkeleton
            }
            .padding(.horizontal, 16)
            .padding(.top, showImageCarousel ? 12 : 4)
            .padding(.bottom, 10)
        }
    }

    // MARK: - Author Row
    // loading 時只顯示頭像 + 名字/時間，箭頭和 ⋯ 不顯示

    private var authorRowSkeleton: some View {
        HStack(alignment: .center, spacing: 12) {
            // 頭像 skeleton
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 40, height: 40)

            // 名字 + 時間 skeleton
            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 110, height: 15)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 70, height: 11)
            }

            Spacer()
        }
    }

    // MARK: - Image Carousel
    // 對應實際排版：置中卡片、圓角 12、帶 sideInset

    private func imageCarouselSkeleton(totalWidth: CGFloat) -> some View {
        let sideInset = max(16, (totalWidth - cardWidth) / 2)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 顯示兩張以暗示可滑動
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(width: cardWidth, height: cardHeight)
                }
            }
            .padding(.horizontal, sideInset)
        }
        .disabled(true)
        .frame(height: cardHeight)
    }

    // MARK: - Image Meta Row

    private var imageMetaRowSkeleton: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 150, height: 11)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 10)
            }
            Spacer()
            // "查看位置" 按鈕區
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(width: 60, height: 12)
        }
    }

    // MARK: - Description

    private var descriptionSkeleton: some View {
        VStack(alignment: .leading, spacing: 9) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: 16)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(width: 260, height: 16)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(width: 180, height: 16)
        }
        .frame(minHeight: 70, alignment: .topLeading)
    }

    // MARK: - Interaction Row
    // loading 時只顯示數字佔位，icon 不顯示

    private var interactionRowSkeleton: some View {
        HStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(.systemGray5))
                .frame(width: 44, height: 13)
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(.systemGray5))
                .frame(width: 44, height: 13)
            Spacer()
        }
        .padding(.top, 2)
    }

    // MARK: - Reply Input Bar

    private var replyInputBarSkeleton: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 32, height: 32)
            Capsule()
                .fill(Color(.systemGray5))
                .frame(height: 40)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.appSurface)
    }
}

// MARK: - Shimmering modifier

private extension View {
    func shimmering() -> some View {
        self.modifier(ShimmeringModifier())
    }
}

private struct ShimmeringModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Color.white.opacity(0.4), location: 0.38),
                            .init(color: Color.white.opacity(0.4), location: 0.62),
                            .init(color: .clear, location: 1),
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: geo.size.width * (phase * 2 - 1))
                }
                .clipped()
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

#Preview("有圖片") {
    DetailSheetSkeleton(showImageCarousel: true)
        .background(Color.appSurface)
}

#Preview("無圖片") {
    DetailSheetSkeleton(showImageCarousel: false)
        .background(Color.appSurface)
}
