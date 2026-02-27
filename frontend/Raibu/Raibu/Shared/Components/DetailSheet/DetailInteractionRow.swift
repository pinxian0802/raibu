//
//  DetailInteractionRow.swift
//  Raibu
//
//  共用元件：詳情頁互動列
//  ❤️ 讚 + 💬 回覆數
//

import SwiftUI

/// 詳情頁互動列
/// 顯示讚數按鈕 + 回覆數
struct DetailInteractionRow: View {
    let isLiked: Bool
    let likeCount: Int
    let replyCount: Int
    let onLikeTap: () -> Void
    @Binding var isHeartAnimating: Bool

    private let actionFont = Font.system(size: 14, weight: .medium, design: .rounded)

    var body: some View {
        HStack(spacing: 18) {
            Button {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.45)) {
                    isHeartAnimating = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                        isHeartAnimating = false
                    }
                }
                onLikeTap()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundColor(isLiked ? .red : .secondary)
                        .scaleEffect(isHeartAnimating ? 1.24 : (isLiked ? 1.08 : 1.0))
                        .animation(.spring(response: 0.28, dampingFraction: 0.6), value: isHeartAnimating)
                        .animation(.easeInOut(duration: 0.15), value: isLiked)
                    Text("\(likeCount)")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Image(systemName: "message")
                    .foregroundColor(.secondary)
                Text("\(replyCount)")
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .font(actionFont)
        .padding(.top, 2)
    }
}
