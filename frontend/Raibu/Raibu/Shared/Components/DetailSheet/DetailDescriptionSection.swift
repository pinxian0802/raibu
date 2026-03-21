//
//  DetailDescriptionSection.swift
//  Raibu
//
//  共用元件：詳情頁文字描述區
//  含展開/收起邏輯
//

import SwiftUI

/// 詳情頁文字描述區
/// 支援行數限制 + 展開/收起按鈕
struct DetailDescriptionSection: View {
    let description: String
    @Binding var isExpanded: Bool

    var font: Font = .system(size: 16, weight: .regular, design: .rounded)
    var collapsedLineLimit: Int = 3
    var expandThreshold: Int = 90
    var minHeight: CGFloat? = 70
    var collapsedMaxHeight: CGFloat? = nil

    @State private var fullTextHeight: CGFloat = 0

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 6) {
            descriptionText

            if shouldShowToggle {
                Button(isExpanded ? "收起" : "更多...") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
            }
        }

        Group {
            if let minHeight {
                content.frame(minHeight: minHeight, alignment: .topLeading)
            } else {
                content
            }
        }
    }

    private var shouldShowToggle: Bool {
        if let collapsedMaxHeight {
            return fullTextHeight > collapsedMaxHeight + 0.5
        }
        let lineBreakCount = description.filter { $0 == "\n" }.count
        return lineBreakCount >= collapsedLineLimit || description.count > expandThreshold
    }

    @ViewBuilder
    private var descriptionText: some View {
        if let collapsedMaxHeight {
            Text(description)
                .font(font)
                .foregroundColor(.primary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxHeight: isExpanded ? nil : collapsedMaxHeight, alignment: .topLeading)
                .clipped()
                .overlay(alignment: .topLeading) {
                    Text(description)
                        .font(font)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(.clear)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: DetailDescriptionHeightPreferenceKey.self,
                                    value: proxy.size.height
                                )
                            }
                        )
                }
                .onPreferenceChange(DetailDescriptionHeightPreferenceKey.self) { fullTextHeight = $0 }
        } else {
            Text(description)
                .font(font)
                .foregroundColor(.primary)
                .lineLimit(isExpanded ? nil : collapsedLineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
    }
}

private struct DetailDescriptionHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
