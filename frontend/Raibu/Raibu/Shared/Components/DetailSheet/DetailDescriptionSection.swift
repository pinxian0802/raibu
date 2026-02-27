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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(description)
                .font(font)
                .foregroundColor(.primary)
                .lineLimit(isExpanded ? nil : collapsedLineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)

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
        .frame(minHeight: 70, alignment: .topLeading)
    }

    private var shouldShowToggle: Bool {
        let lineBreakCount = description.filter { $0 == "\n" }.count
        return lineBreakCount >= collapsedLineLimit || description.count > expandThreshold
    }
}
