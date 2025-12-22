//
//  LikeButton.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI

/// 愛心按鈕
struct LikeButton: View {
    let count: Int
    let isLiked: Bool
    let action: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                isAnimating = true
            }
            
            // 觸發動作
            action()
            
            // 重置動畫
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAnimating = false
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 18))
                    .foregroundColor(isLiked ? .red : .secondary)
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 愛心按鈕 (大尺寸，用於詳細頁)
struct LikeButtonLarge: View {
    let count: Int
    let isLiked: Bool
    let action: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                isAnimating = true
            }
            
            action()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAnimating = false
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 24))
                    .foregroundColor(isLiked ? .red : .primary)
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
                
                Text("\(count)")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(isLiked ? Color.red.opacity(0.1) : Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 30) {
        // 小尺寸
        HStack(spacing: 20) {
            LikeButton(count: 0, isLiked: false) {}
            LikeButton(count: 5, isLiked: false) {}
            LikeButton(count: 42, isLiked: true) {}
        }
        
        // 大尺寸
        HStack(spacing: 20) {
            LikeButtonLarge(count: 0, isLiked: false) {}
            LikeButtonLarge(count: 42, isLiked: true) {}
        }
    }
    .padding()
}
