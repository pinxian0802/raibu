//
//  OptimisticReplyRowView.swift
//  Raibu
//
//  送出中 / 失敗狀態的暫時留言 Row
//

import SwiftUI
import Kingfisher

struct OptimisticReplyRowView: View {
    let optimistic: OptimisticReply
    let onRetry: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            avatarView

            VStack(alignment: .leading, spacing: hasOptimisticText ? 5 : 3) {
                // 作者名稱
                Text(displayName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)

                // 留言內容（半透明表示未完成，僅在有內容時顯示）
                if hasOptimisticText {
                    Text(optimistic.content)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.primary.opacity(isPending ? 0.45 : 1.0))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }

                // 選取的圖片預覽（本地縮圖，尺寸與已發佈回覆一致）
                if !optimistic.selectedPhotos.isEmpty {
                    let replyImageHeight: CGFloat = 96 * 375 / 260
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(optimistic.selectedPhotos) { photo in
                                if let img = UIImage(data: photo.thumbnailData) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: replyImageHeight)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .opacity(isPending ? 0.5 : 1.0)
                                }
                            }
                        }
                    }
                }

                // 狀態列
                statusRow
                    .padding(.top, (!hasOptimisticText && hasOptimisticImages) ? 5 : 0)
            }

            Spacer(minLength: 8)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Status Row

    @ViewBuilder
    private var statusRow: some View {
        switch optimistic.status {
        case .pending:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.secondary)
                Text("發佈中…")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }

        case .failed:
            HStack(spacing: 10) {
                // 錯誤提示
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.appDanger)
                    Text("發佈失敗")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.appDanger)
                }

                // 重新傳送按鈕
                Button {
                    onRetry()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                        Text("重試")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.brandBlue)
                }
                .buttonStyle(.plain)

                // 刪除按鈕
                Button {
                    onRemove()
                } label: {
                    Text("刪除")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private var isPending: Bool {
        if case .pending = optimistic.status { return true }
        return false
    }

    private var hasOptimisticText: Bool {
        !optimistic.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasOptimisticImages: Bool {
        !optimistic.selectedPhotos.isEmpty
    }

    private var displayName: String {
        let candidate = optimistic.author?.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let candidate, !candidate.isEmpty { return candidate }
        return "使用者"
    }

    private var avatarView: some View {
        Group {
            if let avatarUrl = optimistic.author?.avatarUrl,
               !avatarUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                KFImage(URL(string: avatarUrl))
                    .placeholder { Circle().fill(Color(.systemGray4)) }
                    .retry(maxCount: 2, interval: .seconds(1))
                    .cacheOriginalImage()
                    .fade(duration: 0.2)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Color(.systemGray4))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.appOnPrimary)
                    )
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
        .opacity(isPending ? 0.6 : 1.0)
    }
}
