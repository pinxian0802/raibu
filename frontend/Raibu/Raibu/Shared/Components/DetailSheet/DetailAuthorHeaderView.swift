//
//  DetailAuthorHeaderView.swift
//  Raibu
//
//  共用元件：詳情頁作者資訊列
//  包含返回箭頭 + 頭像 + 名字 + 時間 + ⋯ 按鈕
//

import SwiftUI
import Kingfisher

/// 詳情頁作者資訊列
/// 用於 Record / Ask 詳情頁頂部
struct DetailAuthorHeaderView<AnchorKey: PreferenceKey>: View where AnchorKey.Value == Anchor<CGRect>? {
    let author: User
    let createdAt: Date
    let anchorKey: AnchorKey.Type
    let onBackTap: () -> Void
    let onAvatarTap: () -> Void
    var onMoreOptionsTap: (() -> Void)? = nil
    @Binding var showMoreOptions: Bool

    private let authorNameFont = Font.system(size: 18, weight: .semibold, design: .rounded)
    private let metaCaptionFont = Font.system(size: 12, weight: .regular, design: .rounded)

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                onBackTap()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)

            userInfoRow
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var userInfoRow: some View {
        HStack(alignment: .center, spacing: 12) {
            // Avatar
            Button {
                onAvatarTap()
            } label: {
                KFImage(URL(string: author.avatarUrl ?? ""))
                    .placeholder {
                        Circle().fill(Color(.systemGray4))
                    }
                    .retry(maxCount: 2, interval: .seconds(1))
                    .cacheOriginalImage()
                    .fade(duration: 0.2)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Name & Time
            VStack(alignment: .leading, spacing: 2) {
                Text(author.displayName)
                    .font(authorNameFont)
                    .foregroundColor(.primary)

                Text(DetailSheetHelpers.formatTimeAgo(createdAt))
                    .font(metaCaptionFont)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // More Options
            moreOptionsButton
        }
    }

    private var moreOptionsButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                showMoreOptions.toggle()
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundColor(.primary)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
        }
        .buttonStyle(.plain)
        .frame(width: 32, height: 32, alignment: .center)
        .contentShape(Rectangle())
        .anchorPreference(key: anchorKey, value: .bounds) { $0 }
    }
}
