//
//  DetailDeleteConfirmation.swift
//  Raibu
//
//  共用元件：刪除確認彈窗
//

import SwiftUI

/// 刪除確認 overlay
/// 用於 Record / Ask 詳情頁的刪除確認
struct DetailDeleteConfirmation: View {
    @Binding var isPresented: Bool
    let onDelete: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let popupWidth = min(max(proxy.size.width - 40, 260), 320)

            ZStack {
                Color.appOverlay.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isPresented = false
                        }
                    }

                VStack(spacing: 0) {
                    VStack(spacing: 10) {
                        Text("確認刪除")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)

                        Text("確定要刪除此標點嗎？此動作無法復原")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)

                    Divider()

                    HStack(spacing: 0) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isPresented = false
                            }
                        } label: {
                            Text("取消")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Divider()

                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isPresented = false
                            }
                            onDelete()
                        } label: {
                            Text("刪除")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.appDanger)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(height: 54)
                }
                .frame(width: popupWidth)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(.systemGray5), lineWidth: 0.8)
                )
                .shadow(color: Color.appOverlay.opacity(0.15), radius: 14, x: 0, y: 5)
                .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .transition(.scale(scale: 0.94).combined(with: .opacity))
        .zIndex(200)
    }
}
