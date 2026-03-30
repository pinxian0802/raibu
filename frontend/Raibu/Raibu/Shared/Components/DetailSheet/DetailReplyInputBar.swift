//
//  DetailReplyInputBar.swift
//  Raibu
//
//  共用元件：底部回覆輸入列
//

import SwiftUI
import Kingfisher
import PhotosUI

/// 底部回覆輸入列
/// 顯示使用者頭像 + 圖片縮圖列 + 文字輸入框（內建相機icon）+ 右側送出按鈕
struct DetailReplyInputBar: View {
    @Binding var replyText: String
    @Binding var selectedPhotos: [SelectedPhoto]
    let isSubmitting: Bool
    let currentUserAvatarURL: String?
    let onPhotoPickerTap: () -> Void
    let onSubmit: () -> Void

    private var trimmedText: String {
        replyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        // can send when there is text or at least one selected photo, and not currently submitting
        (!trimmedText.isEmpty || !selectedPhotos.isEmpty) && !isSubmitting
    }

    var body: some View {
        VStack(spacing: 0) {
            // 已選圖片縮圖列（有圖片時顯示）
            if !selectedPhotos.isEmpty {
                selectedPhotosRow
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }

            // 輸入列
            HStack(alignment: .center, spacing: 8) {
                // 使用者頭像
                avatarView

                // 文字框（內含相機 icon）
                inputField

                // 右側送出按鈕
                sendButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.appSurface)
    }

    // MARK: - Avatar

    private var avatarView: some View {
        Group {
            if let avatarURL = currentUserAvatarURL {
                KFImage(URL(string: avatarURL))
                    .placeholder { Circle().fill(Color(.systemGray4)) }
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
        }
    }

    // MARK: - Input Field

    private var inputField: some View {
        HStack(spacing: 0) {
            TextField("說些什麼吧", text: $replyText)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .textInputAutocapitalization(.sentences)
                .submitLabel(.send)
                .onSubmit {
                    if canSend { onSubmit() }
                }
                .padding(.leading, 14)
                .padding(.vertical, 9)

            // 相機 icon（文字框內右側）
            Button {
                onPhotoPickerTap()
            } label: {
                Image(systemName: selectedPhotos.isEmpty ? "photo" : "photo.fill")
                    .font(.system(size: 17))
                    .foregroundColor(selectedPhotos.isEmpty ? Color(.systemGray3) : .brandBlue)
                    .padding(.trailing, 12)
                    .padding(.leading, 4)
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)
        }
        .background(Color(.systemGray6))
        .clipShape(Capsule())
    }

    // MARK: - Send Button

    private var sendButton: some View {
        Button {
            if canSend { onSubmit() }
        } label: {
            ZStack {
                if isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 34, height: 34)
            .background(canSend ? Color.brandBlue : Color(.systemGray4))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .animation(.easeInOut(duration: 0.15), value: canSend)
    }

    // MARK: - Selected Photos Row

    private var selectedPhotosRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(selectedPhotos.enumerated()), id: \.element.id) { index, photo in
                    Group {
                        if let image = UIImage(data: photo.thumbnailData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.secondary)
                                )
                        }
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                var photos = selectedPhotos
                                photos.remove(at: index)
                                selectedPhotos = photos
                            }
                        } label: {
                            Circle()
                                .fill(Color.black.opacity(0.45))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Image(systemName: "xmark")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(5)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
