//
//  DetailImageCarouselView.swift
//  Raibu
//
//  共用元件：詳情頁圖片輪播
//  GeometryReader + ScrollView(.horizontal) + scrollTargetBehavior(.viewAligned)
//

import SwiftUI
import Kingfisher

enum DetailImageCarouselLayoutStyle: Equatable {
    case centeredSnap
    case edgeAligned
}

/// 詳情頁圖片水平輪播
/// 用於 Record / Ask 詳情頁的圖片展示區域
struct DetailImageCarouselView: View {
    let images: [ImageMedia]
    let initialImageIndex: Int
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    var layoutStyle: DetailImageCarouselLayoutStyle = .centeredSnap
    @Binding var scrolledImageId: String?
    var onImageTap: ((_ images: [ImageMedia], _ index: Int) -> Void)?

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geo in
            let centeredSideInset = max(16, (geo.size.width - cardWidth) / 2)
            let edgeInset: CGFloat = 20
            let itemSpacing: CGFloat = layoutStyle == .edgeAligned ? 12 : 10

            let baseScrollView = ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: itemSpacing) {
                    ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                        KFImage(URL(string: image.originalPublicUrl))
                            .placeholder {
                                Rectangle()
                                    .fill(Color.appDisabled.opacity(0.2))
                                    .frame(width: cardWidth, height: cardHeight)
                                    .cornerRadius(12)
                            }
                            .retry(maxCount: 2, interval: .seconds(1))
                            .setProcessor(
                                DownsamplingImageProcessor(
                                    size: CGSize(
                                        width: cardWidth * displayScale,
                                        height: cardHeight * displayScale
                                    )
                                )
                            )
                            .scaleFactor(displayScale)
                            .cacheOriginalImage()
                            .fade(duration: 0.2)
                            .resizable()
                            .scaledToFill()
                            .frame(
                                width: cardWidth,
                                height: cardHeight,
                                alignment: .center
                            )
                            .clipped()
                            .cornerRadius(12)
                            .id(image.id)
                            .onTapGesture {
                                onImageTap?(images, index)
                            }
                    }
                }
                .padding(.horizontal, layoutStyle == .edgeAligned ? edgeInset : 0)
                .scrollTargetLayout()
            }

            Group {
                switch layoutStyle {
                case .centeredSnap:
                    baseScrollView
                        .contentMargins(.horizontal, centeredSideInset, for: .scrollContent)
                        .scrollTargetBehavior(.viewAligned)
                case .edgeAligned:
                    baseScrollView
                        .padding(.horizontal, -edgeInset)
                }
            }
            .scrollPosition(id: $scrolledImageId)
            .onAppear {
                if scrolledImageId == nil {
                    scrolledImageId = images[min(initialImageIndex, images.count - 1)].id
                }
            }
        }
        .frame(height: cardHeight)
    }
}
