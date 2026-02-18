//
//  CreateRecordView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI
import Kingfisher

/// 建立紀錄視圖
struct CreateRecordFullView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var container: DIContainer

    @StateObject private var viewModel: CreateRecordViewModel
    @State private var showPhotoPicker = false
    @State private var showErrorAlert = false
    @State private var currentUserAvatarURLFromProfile: String?
    @State private var currentUserDisplayNameFromProfile: String?
    @State private var hasLoadedCurrentUserProfile = false
    @FocusState private var isDescriptionFocused: Bool

    private let placeholderFont = Font.custom("PingFangTC-Medium", size: 39 / 2)
    private let bodyFont = Font.custom("PingFangTC-Regular", size: 18)
    private let metaFont = Font.custom("PingFangTC-Medium", size: 12)
    private let actionGreen = Color(red: 29 / 255, green: 223 / 255, blue: 97 / 255)

    init(uploadService: UploadService, recordRepository: RecordRepository) {
        _viewModel = StateObject(wrappedValue: CreateRecordViewModel(
            uploadService: uploadService,
            recordRepository: recordRepository
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            handleView
            headerBar
            composerSection

            Divider()
                .padding(.horizontal, 24)

            attachmentsSection
            photoActionBar
        }
        .background(Color.appSurface)
        .sheet(isPresented: $showPhotoPicker) {
            CustomPhotoPickerView(
                photoPickerService: container.photoPickerService,
                requireGPS: true,
                maxSelection: 10,
                initialSelectedPhotos: viewModel.selectedPhotos
            ) { photos in
                viewModel.setPhotos(photos)
            }
        }
        .alert("錯誤", isPresented: $showErrorAlert) {
            Button("確定") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: viewModel.errorMessage) { newValue in
            showErrorAlert = newValue != nil
        }
        .onChange(of: viewModel.isCompleted) { completed in
            if completed {
                dismiss()
            }
        }
        .presentationDragIndicator(.hidden)
        .task {
            guard !hasLoadedCurrentUserProfile else { return }
            hasLoadedCurrentUserProfile = true
            await loadCurrentUserProfileIfNeeded()
        }
    }

    // MARK: - Top Section

    private var handleView: some View {
        SheetTopHandle()
    }

    private var headerBar: some View {
        ZStack {
            Text("新增紀錄")
                .font(.custom("PingFangTC-Semibold", size: 37 / 2))
                .foregroundColor(.primary)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(Color(uiColor: .systemIndigo).opacity(0.8))
                .disabled(viewModel.isUploading)

                Spacer()

                Button {
                    isDescriptionFocused = false
                    Task {
                        await viewModel.submit()
                    }
                } label: {
                    Group {
                        if viewModel.isUploading {
                            ProgressView()
                                .tint(actionGreen)
                        } else {
                            Text("新增")
                        }
                    }
                    .font(.custom("PingFangTC-Semibold", size: 17))
                }
                .foregroundColor(viewModel.canSubmit ? actionGreen : .secondary)
                .disabled(!viewModel.canSubmit)
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 56)
        .padding(.bottom, 8)
    }

    private var composerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                avatarView

                Text(currentUserDisplayName)
                    .font(.custom("PingFangTC-Medium", size: 17))
                    .foregroundColor(.primary)
                    .padding(.top, 2)

                Spacer()
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.description)
                    .font(bodyFont)
                    .foregroundColor(.primary)
                    .scrollContentBackground(.hidden)
                    .focused($isDescriptionFocused)
                    .textInputAutocapitalization(.sentences)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, -5)

                if viewModel.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("輸入你想分享的內容...")
                        .font(placeholderFont)
                        .foregroundColor(Color(.systemGray3))
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var avatarView: some View {
        Group {
            if let avatarURL = currentUserAvatarURL {
                KFImage(URL(string: avatarURL))
                    .placeholder {
                        Circle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            )
                    }
                    .retry(maxCount: 2, interval: .seconds(1))
                    .cacheOriginalImage()
                    .fade(duration: 0.2)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Color(red: 196 / 255, green: 222 / 255, blue: 219 / 255))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(.systemGray))
                    )
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }

    private var currentUserAvatarURL: String? {
        if let avatar = container.authService.currentUser?.avatarUrl?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !avatar.isEmpty {
            return avatar
        }

        if let fallback = currentUserAvatarURLFromProfile?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !fallback.isEmpty {
            return fallback
        }

        return nil
    }

    private var currentUserDisplayName: String {
        if let name = container.authService.currentUser?.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }

        if let fallback = currentUserDisplayNameFromProfile?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !fallback.isEmpty {
            return fallback
        }

        return "使用者"
    }

    private func loadCurrentUserProfileIfNeeded() async {
        let authAvatar = container.authService.currentUser?.avatarUrl?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let authName = container.authService.currentUser?.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasAvatarInAuth = !authAvatar.isEmpty
        let hasNameInAuth = !authName.isEmpty

        if hasAvatarInAuth && hasNameInAuth {
            return
        }

        do {
            let profileUser: User
            if let currentUserId = container.authService.currentUserId {
                profileUser = try await container.userRepository.getUserProfile(id: currentUserId)
            } else {
                let me = try await container.userRepository.getMe()
                profileUser = me.toUser()
            }

            let profileAvatar = profileUser.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
            let profileName = profileUser.displayName.trimmingCharacters(in: .whitespacesAndNewlines)

            await MainActor.run {
                if let profileAvatar, !profileAvatar.isEmpty {
                    currentUserAvatarURLFromProfile = profileAvatar
                }
                if !profileName.isEmpty {
                    currentUserDisplayNameFromProfile = profileName
                }
            }
        } catch {
            // 失敗時保持靜默，沿用目前 auth 資料或預設值。
        }
    }

    // MARK: - Attachment Section

    private var attachmentsSection: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("最多可選取 10 張照片")
                        .font(.custom("PingFangTC-Medium", size: 13))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(viewModel.photoCount)/10 張")
                        .font(metaFont)
                }

                if viewModel.selectedPhotos.isEmpty {
                    emptyPhotosHintView
                } else {
                    selectedPhotosView
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
    }

    private var emptyPhotosHintView: some View {
        Text("分享你的照片吧")
            .font(.custom("PingFangTC-Medium", size: 18))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 172)
    }

    private var selectedPhotosView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(viewModel.selectedPhotos.enumerated()), id: \.element.id) { index, photo in
                    photoThumbnail(photo: photo, index: index)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(height: 184)
    }

    private func photoThumbnail(photo: SelectedPhoto, index: Int) -> some View {
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
        .frame(width: 136, height: 176)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topLeading) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.removePhoto(at: index)
                }
            } label: {
                Circle()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: 33, height: 33)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }
            .padding(8)
        }
    }

    // MARK: - Photo Action

    private var photoActionBar: some View {
        VStack(spacing: 8) {
            Button {
                showPhotoPicker = true
            } label: {
                HStack(spacing: 0) {
                    Text("新增圖片")
                }
                .font(.custom("PingFangTC-Semibold", size: 17))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(viewModel.photoCount < 10 && !viewModel.isUploading ? Color.brandBlue : Color.appDisabled)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.photoCount >= 10 || viewModel.isUploading)

            if viewModel.photoCount >= 10 {
                Text("已達 10 張照片上限")
                    .font(.custom("PingFangTC-Medium", size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .background(
            Color.appSurface
                .shadow(color: Color.appOverlay.opacity(0.08), radius: 12, x: 0, y: -4)
        )
    }
}

#Preview {
    CreateRecordFullView(
        uploadService: UploadService(apiClient: APIClient(baseURL: "", authService: AuthService())),
        recordRepository: RecordRepository(apiClient: APIClient(baseURL: "", authService: AuthService()))
    )
    .environmentObject(DIContainer())
}
