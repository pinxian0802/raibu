//
//  CustomTabBar.swift
//  Raibu
//
//  Custom tab bar component for main navigation
//

import SwiftUI

/// 自定義 Tab Bar - 簡潔扁平設計
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    let onCreateTapped: () -> Void
    
    @State private var isCreateButtonPressed = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // 主要內容
            HStack(spacing: 0) {
                // 地圖 Tab
                TabBarButton(
                    icon: "map",
                    iconFilled: "map.fill",
                    title: "地圖",
                    isSelected: selectedTab == 0
                ) {
                    selectedTab = 0
                }
                
                // 新增按鈕（簡潔版本，不凸起）
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    onCreateTapped()
                }) {
                    Image(systemName: "plus.app.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .scaleEffect(isCreateButtonPressed ? 0.9 : 1.0)
                }
                .buttonStyle(PlainButtonStyle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            isCreateButtonPressed = true
                        }
                        .onEnded { _ in
                            isCreateButtonPressed = false
                        }
                )
                
                // 個人 Tab
                TabBarButton(
                    icon: "person",
                    iconFilled: "person.fill",
                    title: "個人",
                    isSelected: selectedTab == 2
                ) {
                    selectedTab = 2
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 9)
            .padding(.bottom, 0)
            .background(
                Color(colorScheme == .dark ? UIColor.systemBackground : UIColor.systemBackground)
            )
        }
        .background(
            Color(colorScheme == .dark ? UIColor.systemBackground : UIColor.systemBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 10, y: -3)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Tab Bar Button

private struct TabBarButton: View {
    let icon: String
    let iconFilled: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(spacing: 2) {
                Image(systemName: isSelected ? iconFilled : icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .blue : .gray)
                
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        CustomTabBar(
            selectedTab: .constant(0),
            onCreateTapped: {}
        )
    }
    .background(Color.gray.opacity(0.3))
}
