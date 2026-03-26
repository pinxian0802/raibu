//
//  MapIconFactory.swift
//  Raibu
//
//  Created for MapContainerView refactoring.
//

import UIKit
import MapKit

/// 地圖圖標繪製工廠
/// 負責建立所有地圖標註的圖標，包含縮圖、群集圖標和詢問圖標
final class MapIconFactory {
    
    // MARK: - Constants
    
    /// 圖標尺寸（與群聚演算法一致）
    static var iconSize: CGFloat { ClusteringService.markerIconSize }
    
    /// 邊框寬度
    static let borderWidth: CGFloat = 3
    
    /// Badge 尺寸
    static let badgeSize: CGFloat = 28
    
    /// 圓角半徑
    static let cornerRadius: CGFloat = 12

    /// 詢問標點外觀設定（地圖上圖片尺寸對齊紀錄標點）
    private static var askAvatarSize: CGFloat { iconSize }
    private static var askAvatarCornerRadius: CGFloat {
        cornerRadius * (askAvatarSize / iconSize)
    }
    private static var askAvatarBorderWidth: CGFloat {
        borderWidth * (askAvatarSize / iconSize)
    }
    private static let askTitleFontSize: CGFloat = 12
    private static let askTitleCornerRadius: CGFloat = 5
    private static let askTitleHorizontalPadding: CGFloat = 6
    private static let askTitleVerticalPadding: CGFloat = 4
    private static let askTitleMaxWidth: CGFloat = 150
    private static let askTitleMinWidth: CGFloat = 52
    private static let askAvatarToTitleSpacing: CGFloat = 10
    private static let askCardShadowPadding: CGFloat = 12
    
    
    // MARK: - Image Cache
    
    /// 圖片快取（設定容量限制）
    static let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100  // 最多快取 100 張圖片
        cache.totalCostLimit = 50 * 1024 * 1024  // 50 MB
        return cache
    }()
    
    // MARK: - Thumbnail Icon
    
    /// 從圖片建立正方形縮圖 icon（帶白色邊框和圓角）
    static func createThumbnailIcon(from image: UIImage) -> UIImage {
        let size = CGSize(width: iconSize, height: iconSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let innerRect = rect.insetBy(dx: borderWidth, dy: borderWidth)
            
            // 繪製白色邊框背景（圓角正方形）
            let borderPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            UIColor.appOnPrimary.setFill()
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
    
    // MARK: - Thumbnail with Badge
    
    /// 從圖片建立帶數量 badge 的縮圖（右上角顯示群聚數量）
    static func createThumbnailWithBadge(from image: UIImage, count: Int) -> UIImage {
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
            UIColor.appOnPrimary.setFill()
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
            
            // 繪製右上角的數量 badge
            let badgeCenterX = iconSize
            let badgeCenterY = badgeOffset
            let badgeRect = CGRect(
                x: badgeCenterX - badgeSize / 2,
                y: badgeCenterY - badgeSize / 2,
                width: badgeSize,
                height: badgeSize
            )
            
            // Badge 背景（藍色圓形 + 白色邊框）
            UIColor.appOnPrimary.setFill()
            context.cgContext.fillEllipse(in: badgeRect)
            
            let innerBadgeRect = badgeRect.insetBy(dx: 2, dy: 2)
            UIColor.brandBlue.setFill()
            context.cgContext.fillEllipse(in: innerBadgeRect)
            
            // Badge 數字
            let text = "\(count)" as NSString
            let fontSize: CGFloat = count >= 100 ? 10 : (count >= 10 ? 12 : 14)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: UIColor.appOnPrimary
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
    
    // MARK: - Ask Icon
    
    /// 建立詢問標點圖標（預覽樣式：大頭貼 + 標題卡）
    static func createAskIcon(title: String?, image: UIImage?) -> UIImage {
        createAskIcon(title: title, image: image, showTitle: true, showCard: true)
    }
    
    /// 建立詢問標點圖標（可選擇是否顯示標題）
    private static func createAskIcon(
        title: String?,
        image: UIImage?,
        showTitle: Bool,
        showCard: Bool
    ) -> UIImage {
        let layout = makeAskIconLayout(title: title)
        let size = CGSize(width: layout.totalWidth, height: layout.totalHeight)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let avatarOriginX = (layout.totalWidth - askAvatarSize) / 2
            let avatarRect = CGRect(x: avatarOriginX, y: 0, width: askAvatarSize, height: askAvatarSize)
            let avatarInnerRect = avatarRect.insetBy(dx: askAvatarBorderWidth, dy: askAvatarBorderWidth)

            context.cgContext.setShadow(offset: CGSize(width: 0, height: 5), blur: 10, color: UIColor.black.withAlphaComponent(0.26).cgColor)
            UIColor.appOnPrimary.setFill()
            UIBezierPath(roundedRect: avatarRect, cornerRadius: askAvatarCornerRadius).fill()
            context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)

            if let image {
                context.cgContext.saveGState()
                let clipPath = UIBezierPath(
                    roundedRect: avatarInnerRect,
                    cornerRadius: askAvatarCornerRadius - askAvatarBorderWidth
                )
                clipPath.addClip()

                let imageSize = image.size
                let minSide = min(imageSize.width, imageSize.height)
                let cropRect = CGRect(
                    x: (imageSize.width - minSide) / 2,
                    y: (imageSize.height - minSide) / 2,
                    width: minSide,
                    height: minSide
                )
                if let cgImage = image.cgImage?.cropping(to: cropRect) {
                    UIImage(cgImage: cgImage).draw(in: avatarInnerRect)
                } else {
                    image.draw(in: avatarInnerRect)
                }
                context.cgContext.restoreGState()
            } else {
                let gradientColors = [
                    UIColor(red: 0.35, green: 0.51, blue: 0.98, alpha: 1).cgColor,
                    UIColor.brandOrange.cgColor
                ] as CFArray
                let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: gradientColors,
                    locations: [0.0, 1.0]
                )
                if let gradient {
                    context.cgContext.saveGState()
                    UIBezierPath(
                        roundedRect: avatarInnerRect,
                        cornerRadius: askAvatarCornerRadius - askAvatarBorderWidth
                    ).addClip()
                    context.cgContext.drawLinearGradient(
                        gradient,
                        start: CGPoint(x: avatarInnerRect.minX, y: avatarInnerRect.minY),
                        end: CGPoint(x: avatarInnerRect.maxX, y: avatarInnerRect.maxY),
                        options: []
                    )
                    context.cgContext.restoreGState()
                }

                let symbolSize: CGFloat = 26
                let iconRect = CGRect(
                    x: avatarInnerRect.midX - symbolSize / 2,
                    y: avatarInnerRect.midY - symbolSize / 2,
                    width: symbolSize,
                    height: symbolSize
                )
                let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
                if let icon = UIImage(systemName: "person.fill", withConfiguration: config) {
                    icon.withTintColor(.white, renderingMode: .alwaysOriginal).draw(in: iconRect)
                }
            }


            // Title card
            if showCard {
                let cardOriginX = (layout.totalWidth - layout.cardWidth) / 2
                let cardOriginY = askAvatarSize + askAvatarToTitleSpacing
                let cardRect = CGRect(
                    x: cardOriginX,
                    y: cardOriginY,
                    width: layout.cardWidth,
                    height: layout.cardHeight
                )

            context.cgContext.setShadow(offset: CGSize(width: 0, height: 5), blur: 12, color: UIColor.black.withAlphaComponent(0.2).cgColor)
                UIColor.appOnPrimary.setFill()
            UIBezierPath(roundedRect: cardRect, cornerRadius: askTitleCornerRadius).fill()
                context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)

                if showTitle, !layout.displayTitle.isEmpty {
                    let textRect = CGRect(
                        x: cardRect.minX + askTitleHorizontalPadding,
                        y: cardRect.minY + askTitleVerticalPadding,
                        width: cardRect.width - (askTitleHorizontalPadding * 2),
                        height: cardRect.height - (askTitleVerticalPadding * 2)
                    )
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.lineBreakMode = .byTruncatingTail
                    paragraphStyle.alignment = .center
                    let textAttributes: [NSAttributedString.Key: Any] = [
                        .font: layout.titleFont,
                        .foregroundColor: UIColor.label,
                        .paragraphStyle: paragraphStyle
                    ]
                    (layout.displayTitle as NSString).draw(in: textRect, withAttributes: textAttributes)
                }
            }
        }
    }

    static func askIconCenterOffset(title: String?) -> CGPoint {
        let layout = makeAskIconLayout(title: title)
        let centerOffsetY = (askAvatarSize / 2) - (layout.totalHeight / 2)
        return CGPoint(x: 0, y: centerOffsetY)
    }

    // MARK: - Ask Cluster Icon

    /// 詢問群聚徽章位置（相對頭像右上角）
    private static let askClusterBadgeOverlapX: CGFloat = 0.5
    private static let askClusterBadgeOverlapY: CGFloat = 0.55
    
    private struct AskClusterBadgeLayout {
        let iconRect: CGRect
        let badgeRect: CGRect
        let canvasSize: CGSize
        let translation: CGPoint
        let avatarCenterInCanvas: CGPoint
    }

    /// 建立詢問群聚圖標（與單一詢問標點完全相同 + 右上角數量徽章）
    static func createAskClusterIcon(title: String?, image: UIImage?, count: Int) -> UIImage {
        let badgeLayout = makeAskClusterBadgeLayout(title: title)
        let icon = createAskIcon(title: title, image: image, showTitle: true, showCard: true)

        let renderer = UIGraphicsImageRenderer(size: badgeLayout.canvasSize)
        return renderer.image { ctx in
            icon.draw(in: badgeLayout.iconRect.offsetBy(dx: badgeLayout.translation.x, dy: badgeLayout.translation.y))
            drawAskClusterBadge(
                count: count,
                in: badgeLayout.badgeRect.offsetBy(dx: badgeLayout.translation.x, dy: badgeLayout.translation.y),
                context: ctx
            )
        }
    }

    static func askClusterCenterOffset(title: String?) -> CGPoint {
        let badgeLayout = makeAskClusterBadgeLayout(title: title)
        return CGPoint(
            x: badgeLayout.avatarCenterInCanvas.x - badgeLayout.canvasSize.width / 2,
            y: badgeLayout.avatarCenterInCanvas.y - badgeLayout.canvasSize.height / 2
        )
    }
    
    // MARK: - Cluster Icon
    
    /// 建立群集圖標（圓形帶數字）
    static func createClusterIcon(count: Int, mode: MapMode) -> UIImage {
        let size = CGSize(width: iconSize, height: iconSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.appOnPrimary.setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
            
            let color = mode == .record ? UIColor.brandBlue : UIColor.brandOrange
            color.setFill()
            context.cgContext.fillEllipse(in: CGRect(
                x: borderWidth,
                y: borderWidth,
                width: iconSize - borderWidth * 2,
                height: iconSize - borderWidth * 2
            ))
            
            // 繪製數字（置中）
            let text = "\(count)" as NSString
            let fontSize: CGFloat = count >= 100 ? 20 : (count >= 10 ? 24 : 28)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: UIColor.appOnPrimary
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

    // MARK: - Ask Layout Helpers
    
    private struct AskIconLayout {
        let displayTitle: String
        let titleFont: UIFont
        let cardWidth: CGFloat
        let cardHeight: CGFloat
        let totalWidth: CGFloat
        let totalHeight: CGFloat
    }
    
    private static func makeAskIconLayout(title: String?) -> AskIconLayout {
        makeAskIconLayout(title: title, avatarSize: askAvatarSize)
    }

    private static func makeAskIconLayout(title: String?, avatarSize: CGFloat) -> AskIconLayout {
        let displayTitle = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let titleFont = UIFont(
            name: "PingFangTC-Regular",
            size: askTitleFontSize
        ) ?? UIFont.systemFont(ofSize: askTitleFontSize, weight: .regular)
        let textWidth = ceil((displayTitle as NSString).size(withAttributes: [.font: titleFont]).width)
        let preferredCardWidth = textWidth + (askTitleHorizontalPadding * 2)
        let cardWidth = min(askTitleMaxWidth, max(askTitleMinWidth, preferredCardWidth))
        let cardHeight = ceil(titleFont.lineHeight) + (askTitleVerticalPadding * 2)
        let totalWidth = max(avatarSize, cardWidth)
        let totalHeight = avatarSize + askAvatarToTitleSpacing + cardHeight + askCardShadowPadding
        
        return AskIconLayout(
            displayTitle: displayTitle,
            titleFont: titleFont,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            totalWidth: totalWidth,
            totalHeight: totalHeight
        )
    }

    private static func makeAskClusterBadgeLayout(title: String?) -> AskClusterBadgeLayout {
        let layout = makeAskIconLayout(title: title)
        let iconW = layout.totalWidth
        let iconH = layout.totalHeight
        let avatarX = (iconW - askAvatarSize) / 2
        let avatarRect = CGRect(x: avatarX, y: 0, width: askAvatarSize, height: askAvatarSize)
        let badgeRect = CGRect(
            x: avatarRect.maxX - badgeSize * (1 - askClusterBadgeOverlapX),
            y: avatarRect.minY - badgeSize * askClusterBadgeOverlapY,
            width: badgeSize,
            height: badgeSize
        )

        let iconRect = CGRect(x: 0, y: 0, width: iconW, height: iconH)
        let bounds = iconRect.union(badgeRect)
        let translation = CGPoint(x: -bounds.minX, y: -bounds.minY)
        let canvasSize = CGSize(width: ceil(bounds.width), height: ceil(bounds.height))
        let avatarCenterInCanvas = CGPoint(
            x: avatarRect.midX + translation.x,
            y: avatarRect.midY + translation.y
        )

        return AskClusterBadgeLayout(
            iconRect: iconRect,
            badgeRect: badgeRect,
            canvasSize: canvasSize,
            translation: translation,
            avatarCenterInCanvas: avatarCenterInCanvas
        )
    }
    
    private static func drawAskClusterBadge(
        count: Int,
        in rect: CGRect,
        context: UIGraphicsImageRendererContext
    ) {
        UIColor.appOnPrimary.setFill()
        context.cgContext.fillEllipse(in: rect)
        
        let innerRect = rect.insetBy(dx: 2, dy: 2)
        UIColor.brandOrange.setFill()
        context.cgContext.fillEllipse(in: innerRect)
        
        let text = "\(count)" as NSString
        let fontSize: CGFloat = count >= 100 ? 10 : (count >= 10 ? 12 : 14)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: UIColor.appOnPrimary
        ]
        let textSize = text.size(withAttributes: attributes)
        let textRect = CGRect(
            x: rect.midX - textSize.width / 2,
            y: rect.midY - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attributes)
    }
}
