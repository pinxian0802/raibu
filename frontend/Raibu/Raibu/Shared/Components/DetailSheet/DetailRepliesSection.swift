//
//  DetailRepliesSection.swift
//  Raibu
//
//  共用元件：回覆列表區域
//  含 skeleton / 空狀態 / 回覆清單
//

import SwiftUI

/// 回覆列表區域
/// 包含 loading skeleton、空狀態提示、以及回覆列表（含 optimistic）
struct DetailRepliesSection: View {
    let replies: [Reply]
    var optimisticReplies: [OptimisticReply] = []
    let isLoadingReplies: Bool
    let onAuthorTap: (String) -> Void
    let onLikeToggle: (String) -> Void
    let onReplyReport: (String) -> Void
    var canReportReply: ((Reply) -> Bool)? = nil
    var onReplyDelete: ((String) -> Void)? = nil
    var canDeleteReply: ((Reply) -> Bool)? = nil
    var onRetry: ((String) -> Void)? = nil
    var onRemoveFailed: ((String) -> Void)? = nil
    var onImageTapForFullScreen: ((_ images: [ImageMedia], _ index: Int) -> Void)? = nil
    @State private var activeReplyMenuId: String? = nil

    private var hasContent: Bool {
        !optimisticReplies.isEmpty || !replies.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoadingReplies {
                ForEach(0..<2, id: \.self) { _ in
                    ReplyRowSkeleton()
                }
            } else if !hasContent {
                Text("目前沒有回覆")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                // Optimistic replies 排在最前面
                ForEach(optimisticReplies) { optimistic in
                    OptimisticReplyRowView(
                        optimistic: optimistic,
                        onRetry: { onRetry?(optimistic.id) },
                        onRemove: { onRemoveFailed?(optimistic.id) }
                    )

                    if optimistic.id != optimisticReplies.last?.id || !replies.isEmpty {
                        Divider()
                    }
                }

                // 真實回覆（已倒序）
                ForEach(replies) { reply in
                    let shouldShowReport = canReportReply?(reply) ?? true
                    ReplyRowView(
                        reply: reply,
                        onAuthorTap: { userId in onAuthorTap(userId) },
                        onLikeToggle: { replyId in onLikeToggle(replyId) },
                        canDelete: canDeleteReply?(reply) ?? false,
                        onReportTap: shouldShowReport ? { replyId in onReplyReport(replyId) } : nil,
                        onDeleteTap: onReplyDelete,
                        isMenuPresented: activeReplyMenuId == reply.id,
                        onMenuPresentedChange: { isPresented in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if isPresented {
                                    activeReplyMenuId = reply.id
                                } else if activeReplyMenuId == reply.id {
                                    activeReplyMenuId = nil
                                }
                            }
                        },
                        onImageTapForFullScreen: onImageTapForFullScreen
                    )

                    if reply.id != replies.last?.id {
                        Divider()
                    }
                }
            }
        }
        .onChange(of: replies.map(\.id)) { _, ids in
            if let activeReplyMenuId, !ids.contains(activeReplyMenuId) {
                self.activeReplyMenuId = nil
            }
        }
    }
}
