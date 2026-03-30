//
//  DetailMoreOptionsMenu.swift
//  Raibu
//
//  共用元件：更多選項浮動選單
//

import SwiftUI

/// 更多選項浮動選單的容器
/// 提供統一的外觀（圓角、邊框、陰影），選項內容由外部傳入
struct DetailMoreOptionsMenu<Content: View>: View {
    let menuWidth: CGFloat
    @ViewBuilder let content: () -> Content

    init(menuWidth: CGFloat = 186, @ViewBuilder content: @escaping () -> Content) {
        self.menuWidth = menuWidth
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(width: menuWidth)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 0.8)
        )
        .shadow(color: Color.appOverlay.opacity(0.12), radius: 10, x: 0, y: 3)
    }
}

/// 三個點觸發 icon 的共用樣式，避免不同頁面出現視覺漂移
struct DetailMoreOptionsTriggerIcon: View {
    var body: some View {
        Image(systemName: "ellipsis")
            .foregroundColor(.primary)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .frame(width: 32, height: 32, alignment: .center)
            .contentShape(Rectangle())
    }
}

/// 選項列 (單一按鈕)
struct DetailOptionRow: View {
    let title: String
    let systemImage: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role) {
            action()
        } label: {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(role == .destructive ? Color.appDanger : Color.primary)

                Spacer()

                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(role == .destructive ? Color.appDanger : Color.primary)
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 選單內的分隔線
struct DetailOptionDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 14)
    }
}

/// 更多選項 overlay 背景 + 定位
struct DetailMoreOptionsOverlay<MenuContent: View>: View {
    let buttonFrame: CGRect
    let menuWidth: CGFloat
    let onDismiss: () -> Void
    @ViewBuilder let menuContent: () -> MenuContent

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.appOverlay.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        onDismiss()
                    }
                }

            DetailMoreOptionsMenu(menuWidth: menuWidth) {
                menuContent()
            }
            .offset(
                x: max(12, buttonFrame.maxX - menuWidth),
                y: buttonFrame.maxY + 10
            )
            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
            .zIndex(100)
        }
    }
}
