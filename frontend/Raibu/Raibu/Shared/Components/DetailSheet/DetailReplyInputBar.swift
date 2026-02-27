//
//  DetailReplyInputBar.swift
//  Raibu
//
//  共用元件：底部回覆輸入列
//

import SwiftUI
import Kingfisher

/// 底部回覆輸入列
/// 顯示使用者頭像 + 文字輸入框 + 送出按鈕
struct DetailReplyInputBar: View {
    @Binding var replyText: String
    let isSubmitting: Bool
    let currentUserAvatarURL: String?
    let onSubmit: () -> Void

    private var trimmedText: String {
        replyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var showSendButton: Bool {
        !trimmedText.isEmpty
    }

    private var canSend: Bool {
        showSendButton && !isSubmitting
    }

    var body: some View {
        HStack(spacing: 12) {
            // Current User Avatar
            if let avatarURL = currentUserAvatarURL {
                KFImage(URL(string: avatarURL))
                    .placeholder {
                        Circle().fill(Color(.systemGray4))
                    }
                    .retry(maxCount: 2, interval: .seconds(1))
                    .cacheOriginalImage()
                    .fade(duration: 0.2)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.gray)
            }

            ZStack(alignment: .trailing) {
                TextField("說些什麼吧", text: $replyText)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.send)
                    .onSubmit {
                        if canSend { onSubmit() }
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, showSendButton ? 44 : 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())

                if showSendButton {
                    Button {
                        if canSend { onSubmit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.brandBlue)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.brandBlue)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .padding(.trailing, 14)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.appSurface)
    }
}
