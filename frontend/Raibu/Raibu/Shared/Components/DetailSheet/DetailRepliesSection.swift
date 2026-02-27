//
//  DetailRepliesSection.swift
//  Raibu
//
//  共用元件：回覆列表區域
//  含 skeleton / 空狀態 / 回覆清單
//

import SwiftUI

/// 回覆列表區域
/// 包含 loading skeleton、空狀態提示、以及回覆列表
struct DetailRepliesSection: View {
    let replies: [Reply]
    let isLoadingReplies: Bool
    let onAuthorTap: (String) -> Void
    let onLikeToggle: (String) -> Void
    var onImageTapForFullScreen: ((_ images: [ImageMedia], _ index: Int) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoadingReplies {
                ForEach(0..<2, id: \.self) { _ in
                    ReplyRowSkeleton()
                }
            } else if replies.isEmpty {
                Text("目前沒有回覆")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(replies) { reply in
                    ReplyRowView(
                        reply: reply,
                        onAuthorTap: { userId in
                            onAuthorTap(userId)
                        },
                        onLikeToggle: { replyId in
                            onLikeToggle(replyId)
                        },
                        onImageTapForFullScreen: onImageTapForFullScreen
                    )

                    if reply.id != replies.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}
