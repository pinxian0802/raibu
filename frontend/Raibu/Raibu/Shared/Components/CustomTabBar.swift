//
//  CustomTabBar.swift
//  Raibu
//
//  Custom tab bar component for main navigation
//

import SwiftUI

/// 自定義 Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    let onCreateTapped: () -> Void
    
    @State private var isCreateButtonPressed = false
    
    var body: some View {
        HStack(spacing: 0) {
            // 地圖 Tab
            TabBarButton(
                icon: "map",
                title: "地圖",
                isSelected: selectedTab == 0
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = 0
                }
            }
            
            // 新增按鈕（中間大按鈕）
            Button(action: {
                // 觸覺反饋
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isCreateButtonPressed = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isCreateButtonPressed = false
                    }
                    onCreateTapped()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 56, height: 56)
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, y: 4)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(isCreateButtonPressed ? 90 : 0))
                }
                .scaleEffect(isCreateButtonPressed ? 0.9 : 1.0)
            }
            .offset(y: -16)
            
            // 個人 Tab
            TabBarButton(
                icon: "person.circle",
                title: "個人",
                isSelected: selectedTab == 2
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = 2
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: Color.black.opacity(0.05), radius: 8, y: -4)
        )
    }
}

// MARK: - Tab Bar Button

private struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // 觸覺反饋
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .blue : .gray)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                
                Text(title)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(isPressed ? 0.7 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
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
}
