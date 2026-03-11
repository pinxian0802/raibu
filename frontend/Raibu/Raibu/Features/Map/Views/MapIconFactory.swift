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

    /// 詢問標點外觀設定（對齊 CreateAsk 預覽）
    private static let askAvatarSize: CGFloat = 64
    private static let askTitleFontSize: CGFloat = 13
    private static let askTitleHorizontalPadding: CGFloat = 12
    private static let askTitleVerticalPadding: CGFloat = 7
    private static let askTitleMaxWidth: CGFloat = 150
    private static let askTitleMinWidth: CGFloat = 52
    private static let askAvatarToTitleSpacing: CGFloat = 10
    private static let askCardShadowPadding: CGFloat = 6
    
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
        let displayTitle = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let titleFont = UIFont(
            name: "PingFangTC-Semibold",
            size: askTitleFontSize
        ) ?? UIFont.systemFont(ofSize: askTitleFontSize, weight: .semibold)
        let textWidth = ceil((displayTitle as NSString).size(withAttributes: [.font: titleFont]).width)
        let preferredCardWidth = textWidth + (askTitleHorizontalPadding * 2)
        let cardWidth = min(askTitleMaxWidth, max(askTitleMinWidth, preferredCardWidth))
        let cardHeight = ceil(titleFont.lineHeight) + (askTitleVerticalPadding * 2)
        let totalWidth = max(askAvatarSize, cardWidth)
        let totalHeight = askAvatarSize + askAvatarToTitleSpacing + cardHeight + askCardShadowPadding
        let size = CGSize(width: totalWidth, height: totalHeight)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let avatarOriginX = (totalWidth - askAvatarSize) / 2
            let avatarRect = CGRect(x: avatarOriginX, y: 0, width: askAvatarSize, height: askAvatarSize)
            let avatarInnerRect = avatarRect.insetBy(dx: borderWidth, dy: borderWidth)

            context.cgContext.setShadow(offset: CGSize(width: 0, height: 4), blur: 8, color: UIColor.black.withAlphaComponent(0.22).cgColor)
            UIColor.appOnPrimary.setFill()
            context.cgContext.fillEllipse(in: avatarRect)
            context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)

            if let image {
                context.cgContext.saveGState()
                let clipPath = UIBezierPath(ovalIn: avatarInnerRect)
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
                    UIBezierPath(ovalIn: avatarInnerRect).addClip()
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

            // 白色外框
            UIColor.appOnPrimary.setStroke()
            let strokePath = UIBezierPath(ovalIn: avatarRect)
            strokePath.lineWidth = borderWidth
            strokePath.stroke()

            // Title card
            let cardOriginX = (totalWidth - cardWidth) / 2
            let cardOriginY = askAvatarSize + askAvatarToTitleSpacing
            let cardRect = CGRect(x: cardOriginX, y: cardOriginY, width: cardWidth, height: cardHeight)

            context.cgContext.setShadow(offset: CGSize(width: 0, height: 4), blur: 10, color: UIColor.black.withAlphaComponent(0.16).cgColor)
            UIColor.appOnPrimary.setFill()
            UIBezierPath(roundedRect: cardRect, cornerRadius: 12).fill()
            context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)

            let textRect = CGRect(
                x: cardRect.minX + askTitleHorizontalPadding,
                y: cardRect.minY + askTitleVerticalPadding,
                width: cardRect.width - (askTitleHorizontalPadding * 2),
                height: cardRect.height - (askTitleVerticalPadding * 2)
            )
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byTruncatingTail
            paragraphStyle.alignment = .left
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle
            ]
            (displayTitle as NSString).draw(in: textRect, withAttributes: textAttributes)
        }
    }

    static func askIconCenterOffset(title: String?) -> CGPoint {
        let displayTitle = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let titleFont = UIFont(
            name: "PingFangTC-Semibold",
            size: askTitleFontSize
        ) ?? UIFont.systemFont(ofSize: askTitleFontSize, weight: .semibold)
        let textWidth = ceil((displayTitle as NSString).size(withAttributes: [.font: titleFont]).width)
        let preferredCardWidth = textWidth + (askTitleHorizontalPadding * 2)
        let cardWidth = min(askTitleMaxWidth, max(askTitleMinWidth, preferredCardWidth))
        let cardHeight = ceil(titleFont.lineHeight) + (askTitleVerticalPadding * 2)
        let _ = max(askAvatarSize, cardWidth)
        let totalHeight = askAvatarSize + askAvatarToTitleSpacing + cardHeight + askCardShadowPadding
        let centerOffsetY = (askAvatarSize / 2) - (totalHeight / 2)
        return CGPoint(x: 0, y: centerOffsetY)
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
}
