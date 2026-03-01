//
//  CreateAskFullView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI
import MapKit
import Kingfisher

/// 建立詢問視圖
struct CreateAskFullView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var container: DIContainer

    @StateObject private var viewModel: CreateAskViewModel
    @State private var showPhotoPicker = false
    @State private var showErrorAlert = false
    @FocusState private var isQuestionFocused: Bool

    private let placeholderFont = Font.custom("PingFangTC-Medium", size: 39 / 2)
    private let bodyFont = Font.custom("PingFangTC-Regular", size: 18)
    private let metaFont = Font.custom("PingFangTC-Medium", size: 12)
    private let actionGreen = Color(red: 29 / 255, green: 223 / 255, blue: 97 / 255)

    init(
        initialLocation: CLLocationCoordinate2D,
        uploadService: UploadService,
        askRepository: AskRepository
    ) {
        _viewModel = StateObject(wrappedValue: CreateAskViewModel(
            initialLocation: initialLocation,
            uploadService: uploadService,
            askRepository: askRepository
        ))
    }

    var body: some View {
        BottomSheetScaffold(
            topBarBottomPadding: 12,
            leading: {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(Color(uiColor: .systemIndigo).opacity(0.8))
                .disabled(viewModel.isUploading)
                .buttonStyle(.plain)
            },
            title: {
                Text("新增詢問")
                    .font(.custom("PingFangTC-Semibold", size: 37 / 2))
                    .foregroundColor(.primary)
            },
            trailing: {
                Button {
                    isQuestionFocused = false
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
                .buttonStyle(.plain)
            },
            content: {
                VStack(spacing: 0) {
                    composerSection

                    Divider()
                        .padding(.horizontal, 24)

                    mapAndRadiusSection

                    Divider()
                        .padding(.horizontal, 24)

                    attachmentsSection
                    photoActionBar
                }
            }
        )
        .background(Color.appSurface)
        .sheet(isPresented: $showPhotoPicker) {
            CustomPhotoPickerView(
                photoPickerService: container.photoPickerService,
                requireGPS: false,
                maxSelection: 5,
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
    }

    // MARK: - Composer Section

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
                TextEditor(text: $viewModel.question)
                    .font(bodyFont)
                    .foregroundColor(.primary)
                    .scrollContentBackground(.hidden)
                    .focused($isQuestionFocused)
                    .textInputAutocapitalization(.sentences)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, -5)

                if viewModel.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("描述你想詢問的問題...")
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

    // MARK: - Avatar

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
        return nil
    }

    private var currentUserDisplayName: String {
        if let name = container.authService.currentUser?.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        return "使用者"
    }

    // MARK: - Map & Radius Section

    private var mapAndRadiusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 地圖預覽
            ZStack {
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: viewModel.center,
                    span: MKCoordinateSpan(
                        latitudeDelta: Double(viewModel.radiusMeters) / 50000,
                        longitudeDelta: Double(viewModel.radiusMeters) / 50000
                    )
                )), annotationItems: [MapPin(coordinate: viewModel.center)]) { pin in
                    MapAnnotation(coordinate: pin.coordinate) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.brandOrange)
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .disabled(true)

                // 範圍圓圈
                Circle()
                    .stroke(Color.brandOrange.opacity(0.5), lineWidth: 2)
                    .background(Circle().fill(Color.brandOrange.opacity(0.1)))
                    .frame(width: 100, height: 100)
            }

            // 範圍選擇
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("詢問範圍")
                        .font(.custom("PingFangTC-Semibold", size: 16))

                    Spacer()

                    Text(viewModel.radiusText)
                        .font(.custom("PingFangTC-Medium", size: 14))
                        .foregroundColor(.brandOrange)
                }

                HStack(spacing: 8) {
                    ForEach(viewModel.radiusOptions, id: \.self) { radius in
                        Button {
                            withAnimation {
                                viewModel.radiusMeters = radius
                            }
                        } label: {
                            Text(radius >= 1000 ? "\(radius / 1000)km" : "\(radius)m")
                                .font(.custom("PingFangTC-Medium", size: 14))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    viewModel.radiusMeters == radius ?
                                    Color.brandOrange : Color(.systemGray6)
                                )
                                .foregroundColor(
                                    viewModel.radiusMeters == radius ?
                                    .white : .primary
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("在此範圍內的回覆會被標記為實地回報")
                    .font(.custom("PingFangTC-Medium", size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Attachment Section

    private var attachmentsSection: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("最多可選取 5 張照片")
                        .font(.custom("PingFangTC-Medium", size: 13))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(viewModel.selectedPhotos.count)/5 張")
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
        Text("附上照片作為參考（選填）")
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
                .background(viewModel.selectedPhotos.count < 5 && !viewModel.isUploading ? Color.brandBlue : Color.appDisabled)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.selectedPhotos.count >= 5 || viewModel.isUploading)

            if viewModel.selectedPhotos.count >= 5 {
                Text("已達 5 張照片上限")
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

// MARK: - Helper

struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

#Preview {
    CreateAskFullView(
        initialLocation: CLLocationCoordinate2D(latitude: 25.033, longitude: 121.565),
        uploadService: UploadService(apiClient: APIClient(baseURL: "", authService: AuthService())),
        askRepository: AskRepository(apiClient: APIClient(baseURL: "", authService: AuthService()))
    )
    .environmentObject(DIContainer())
}
