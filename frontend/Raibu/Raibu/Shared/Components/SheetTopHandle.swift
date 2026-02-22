//
//  SheetTopHandle.swift
//  Raibu
//
//  Created on 2026/02/18.
//

import SwiftUI

/// Bottom sheet 版面常數，所有 Sheet 頂部樣式請統一使用此處設定
enum BottomSheetLayoutMetrics {
    static let handleTopPadding: CGFloat = 10
    static let handleBottomPadding: CGFloat = 10
    static let topBarHorizontalPadding: CGFloat = 24
    static let topBarHeight: CGFloat = 44
    static let topBarBottomPadding: CGFloat = 4
}

/// Bottom sheet 頂部拖曳指示條（與新增紀錄樣式一致）
struct SheetTopHandle: View {
    var topPadding: CGFloat = BottomSheetLayoutMetrics.handleTopPadding
    var bottomPadding: CGFloat = BottomSheetLayoutMetrics.handleBottomPadding

    var body: some View {
        Capsule()
            .fill(Color(.systemGray5))
            .frame(width: 58, height: 7)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
    }
}

/// Bottom sheet 頂部骨架（Handle + Top Bar）共用容器
struct BottomSheetScaffold<Leading: View, Title: View, Trailing: View, Content: View>: View {
    var showsHandle: Bool = true
    var showsTopBar: Bool = true
    var handleTopPadding: CGFloat = BottomSheetLayoutMetrics.handleTopPadding
    var handleBottomPadding: CGFloat = BottomSheetLayoutMetrics.handleBottomPadding
    var topBarHorizontalPadding: CGFloat = BottomSheetLayoutMetrics.topBarHorizontalPadding
    var topBarHeight: CGFloat = BottomSheetLayoutMetrics.topBarHeight
    var topBarBottomPadding: CGFloat = BottomSheetLayoutMetrics.topBarBottomPadding

    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var title: () -> Title
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            if showsHandle {
                SheetTopHandle(topPadding: handleTopPadding, bottomPadding: handleBottomPadding)
            }

            if showsTopBar {
                ZStack {
                    title()

                    HStack {
                        leading()
                        Spacer()
                        trailing()
                    }
                }
                .padding(.horizontal, topBarHorizontalPadding)
                .frame(height: topBarHeight)
                .padding(.bottom, topBarBottomPadding)
            }

            content()
        }
    }
}
