//
//  CreateAskFullView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI
import MapKit
import Kingfisher
import UIKit

/// 建立詢問視圖
struct CreateAskFullView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var container: DIContainer

    @StateObject private var viewModel: CreateAskViewModel
    @State private var showPhotoPicker = false
    @State private var showErrorAlert = false
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isQuestionFocused: Bool

    // 標點圖片選取
    @State private var isPickingPinPhoto = false
    @State private var pinPhotoScrollIndex = 0
    @State private var pinPhotoLoopedIndex = 0
    @State private var isPinPhotoDragging = false

    private let placeholderFont = Font.custom("PingFangTC-Medium", size: 17)
    private let bodyFont = Font.custom("PingFangTC-Regular", size: 17)
    private let metaFont = Font.custom("PingFangTC-Medium", size: 12)
    private let mapPinTitleFont = Font.custom("PingFangTC-Semibold", size: 13)
    private let mapPinTitleUIFont = UIFont(name: "PingFangTC-Semibold", size: 13) ?? UIFont.systemFont(ofSize: 13, weight: .semibold)
    private let mapPinTitleHorizontalPadding: CGFloat = 12
    private let mapPinTitleMaxWidth: CGFloat = 150
    private let mapPinAvatarSize: CGFloat = 70
    private let mapPinTitleMinCardWidth: CGFloat = 52
    private let actionGreen = Color(red: 29 / 255, green: 223 / 255, blue: 97 / 255)
    private let showRadiusControls = false

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
            topBarBottomPadding: 8,
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
                    ScrollView {
                        VStack(spacing: 0) {
                            mapAndRadiusSection


                            composerSection

                            Divider()
                                .padding(.horizontal, 24)

                            attachmentsSection
                        }
                    }
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
        .onTapGesture {
            isTitleFocused = false
            isQuestionFocused = false
        }
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .leading) {
                if viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("輸入標題...")
                        .font(.custom("PingFangTC-Medium", size: 24))
                        .foregroundColor(Color(.systemGray3))
                        .allowsHitTesting(false)
                }

                TextField("", text: $viewModel.title)
                    .font(.custom("PingFangTC-Medium", size: 24))
                    .foregroundColor(.primary)
                    .focused($isTitleFocused)
                    .textInputAutocapitalization(.sentences)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    // MARK: - Composer Section

    private var composerSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 12) {
                avatarView

                Text(currentUserDisplayName)
                    .font(.custom("PingFangTC-Medium", size: 19))
                    .foregroundColor(.primary)
                    .padding(.top, 2)

                Spacer()
            }

            titleSection

            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.question)
                    .font(bodyFont)
                    .foregroundColor(.primary)
                    .scrollContentBackground(.hidden)
                    .focused($isQuestionFocused)
                    .textInputAutocapitalization(.sentences)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                    .padding(.horizontal, -5)

                if viewModel.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("描述你想詢問的問題...")
                        .font(placeholderFont)
                        .foregroundColor(Color(.systemGray3))
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
            .padding(.top, 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
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
                )), annotationItems: [MapPin(id: "create-ask-pin", coordinate: viewModel.center)]) { pin in
                    MapAnnotation(coordinate: pin.coordinate) {
                        mapPinAnnotationView
                    }
                }
                .frame(height: 188)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.9), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
                .disabled(true)
            }

            if showRadiusControls {
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
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    private var mapPinTitle: String {
        viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var mapPinTitleCardWidth: CGFloat {
        let measuredTextWidth = ceil((mapPinTitle as NSString).size(withAttributes: [.font: mapPinTitleUIFont]).width)
        let preferredCardWidth = measuredTextWidth + (mapPinTitleHorizontalPadding * 2)
        return min(mapPinTitleMaxWidth, max(mapPinTitleMinCardWidth, preferredCardWidth))
    }

    private var mapPinTitleTextWidth: CGFloat {
        max(0, mapPinTitleCardWidth - (mapPinTitleHorizontalPadding * 2))
    }

    private var mapPinAnnotationView: some View {
        VStack(spacing: 8) {
            Group {
                // 優先顯示選取的標點照片
                if let idx = viewModel.pinPhotoIndex,
                   idx < viewModel.selectedPhotos.count,
                   let image = UIImage(data: viewModel.selectedPhotos[idx].thumbnailData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if let avatarURL = currentUserAvatarURL {
                    KFImage(URL(string: avatarURL))
                        .placeholder {
                            Circle()
                                .fill(Color(.systemGray5))
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 16, weight: .semibold))
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
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.35, green: 0.51, blue: 0.98), Color.brandOrange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.95))
                        )
                }
            }
            .frame(width: mapPinAvatarSize, height: mapPinAvatarSize)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 4)

            Text(mapPinTitle)
                .font(mapPinTitleFont)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: mapPinTitleTextWidth, alignment: .leading)
                .padding(.horizontal, mapPinTitleHorizontalPadding)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 4)
                )
        }
    }

    // MARK: - Attachment Section

    private var attachmentsSection: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    Text(isPickingPinPhoto ? "選取標點圖片" : "最多可選取 5 張照片")
                        .font(.custom("PingFangTC-Medium", size: 13))
                        .foregroundColor(.black)

                    Spacer()

                    if isPickingPinPhoto {
                        // 選圖模式：勾勾 / 叉叉
                        HStack(spacing: 12) {
                            // 叉叉：取消
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.pinPhotoIndex = nil
                                    isPickingPinPhoto = false
                                }
                                pinPhotoScrollIndex = 0
                                pinPhotoLoopedIndex = 0
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)

                            // 勾勾：確認
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.pinPhotoIndex = pinPhotoScrollIndex
                                    isPickingPinPhoto = false
                                }
                            } label: {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        // 一般模式：選圖按鈕 + 新增按鈕
                        HStack(spacing: 12) {
                            // 選圖按鈕（只在有照片時顯示）
                            if !viewModel.selectedPhotos.isEmpty {
                                Button {
                                    pinPhotoScrollIndex = viewModel.pinPhotoIndex ?? 0
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isPickingPinPhoto = true
                                    }
                                } label: {
                                    Image(systemName: "mappin.circle")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.black)
                                        .frame(width: 28, height: 28)
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.isUploading)
                            }

                            addPhotoButton
                        }
                    }
                }
                .frame(height: 32, alignment: .center)

                Group {
                    if isPickingPinPhoto {
                        pinPhotoCarouselView
                    } else if viewModel.selectedPhotos.isEmpty {
                        emptyPhotosHintView
                    } else {
                        selectedPhotosView
                    }
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }

    // MARK: - 標點圖片輪播選取器

    private var pinPhotoCarouselView: some View {
        let photos = viewModel.selectedPhotos
        let count = photos.count
        let itemWidth: CGFloat = 136
        let itemSpacing: CGFloat = 12
        let centerOffset = count // 從中間那組開始

        return Group {
            if count == 0 {
                EmptyView()
                    .frame(height: 184)
            } else {
                // 無限輪迴：在前後各複製一份（共 3 倍長度）
                let loopedPhotos: [(Int, Int, SelectedPhoto)] = (0..<(count * 3)).map { i in
                    (i, i % count, photos[i % count])
                }

                GeometryReader { geo in
                    let availableWidth = geo.size.width
                    let sideInset: CGFloat = 20
                    let centerX = availableWidth / 2 + sideInset

                    ScrollViewReader { proxy in
                        VStack(alignment: .leading, spacing: 8) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: itemSpacing) {
                                    ForEach(loopedPhotos, id: \.0) { loopIdx, _, photo in
                                        let isSelected = loopIdx == pinPhotoLoopedIndex

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
                                        .frame(width: itemWidth, height: 176)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .overlay(Color.clear)
                                        .shadow(
                                            color: isSelected ? Color.white.opacity(0.9) : .clear,
                                            radius: isSelected ? 6 : 0
                                        )
                                        .scaleEffect(isSelected ? 1.04 : 0.95)
                                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                                        .background(
                                            GeometryReader { itemGeo in
                                                Color.clear
                                                    .preference(
                                                        key: PinPhotoItemMidXPreferenceKey.self,
                                                        value: [loopIdx: itemGeo.frame(in: .named("pinCarousel")).midX]
                                                    )
                                            }
                                        )
                                        .id(loopIdx)
                                    }
                                }
                                .padding(.horizontal, sideInset)
                                .padding(.vertical, 4)
                                .scrollTargetLayout()
                            }
                            .padding(.horizontal, -sideInset)
                            .frame(height: 176)
                            .scrollClipDisabled()
                            .coordinateSpace(name: "pinCarousel")
                            .scrollTargetBehavior(.viewAligned)
                            .onPreferenceChange(PinPhotoItemMidXPreferenceKey.self) { midXValues in
                                guard !midXValues.isEmpty else { return }
                                let nearest = midXValues.min { lhs, rhs in
                                    abs(lhs.value - centerX) < abs(rhs.value - centerX)
                                }
                                guard let nearestLoopedIndex = nearest?.key else { return }
                                updatePinPhotoSelection(loopedIndex: nearestLoopedIndex, count: count)
                            }
                            .onAppear {
                                let startIndex = min(viewModel.pinPhotoIndex ?? 0, count - 1)
                                pinPhotoScrollIndex = startIndex
                                pinPhotoLoopedIndex = centerOffset + startIndex
                                viewModel.pinPhotoIndex = startIndex
                                DispatchQueue.main.async {
                                    proxy.scrollTo(pinPhotoLoopedIndex, anchor: .center)
                                }
                            }
                            .simultaneousGesture(
                                DragGesture()
                                    .onChanged { _ in
                                        if !isPinPhotoDragging {
                                            isPinPhotoDragging = true
                                        }
                                    }
                                    .onEnded { _ in
                                        isPinPhotoDragging = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                            recenterPinCarouselIfNeeded(count: count, proxy: proxy)
                                        }
                                    }
                            )
                            .onChange(of: pinPhotoLoopedIndex) { _, _ in
                                guard !isPinPhotoDragging else { return }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                    recenterPinCarouselIfNeeded(count: count, proxy: proxy)
                                }
                            }

                            Text(" ")
                                .font(metaFont)
                                .opacity(0)
                                .padding(.leading, 2)
                        }
                        .frame(height: 184, alignment: .bottomLeading)
                    }
                }
                .frame(height: 184)
            }
        }
    }

    private var emptyPhotosHintView: some View {
        Text("附上照片作為參考（選填）")
            .font(.custom("PingFangTC-Medium", size: 18))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 184)
    }

    private var selectedPhotosView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(viewModel.selectedPhotos.enumerated()), id: \.element.id) { index, photo in
                        photoThumbnail(photo: photo, index: index)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }
            .padding(.horizontal, -20)
            .frame(height: 176)

            Text("\(viewModel.selectedPhotos.count)/5 張")
                .font(metaFont)
                .foregroundColor(.secondary)
                .padding(.leading, 2)
        }
        .frame(height: 184, alignment: .bottomLeading)
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
                    // 如果刪除的是目前標點圖片，重設為預設
                    if viewModel.pinPhotoIndex == index {
                        viewModel.pinPhotoIndex = nil
                    } else if let current = viewModel.pinPhotoIndex, current > index {
                        viewModel.pinPhotoIndex = current - 1
                    }
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

    private var addPhotoButton: some View {
        Button {
            showPhotoPicker = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(viewModel.selectedPhotos.count < 5 && !viewModel.isUploading ? .black : .secondary)
                .frame(width: 28, height: 28, alignment: .center)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.selectedPhotos.count >= 5 || viewModel.isUploading)
    }

    private func normalizedPinPhotoLoopedIndex(_ loopedIndex: Int, count: Int) -> Int {
        guard count > 0 else { return loopedIndex }
        if loopedIndex < count {
            return loopedIndex + count
        }
        if loopedIndex >= count * 2 {
            return loopedIndex - count
        }
        return loopedIndex
    }

    private func updatePinPhotoSelection(loopedIndex: Int, count: Int) {
        guard count > 0 else { return }
        if pinPhotoLoopedIndex != loopedIndex {
            pinPhotoLoopedIndex = loopedIndex
        }
        let realIdx = loopedIndex % count
        if pinPhotoScrollIndex != realIdx {
            pinPhotoScrollIndex = realIdx
        }
        if viewModel.pinPhotoIndex != realIdx {
            // 即時更新地圖標點
            viewModel.pinPhotoIndex = realIdx
        }
    }

    private func recenterPinCarouselIfNeeded(count: Int, proxy: ScrollViewProxy) {
        guard count > 0 else { return }
        let normalizedIndex = normalizedPinPhotoLoopedIndex(pinPhotoLoopedIndex, count: count)
        guard normalizedIndex != pinPhotoLoopedIndex else { return }
        pinPhotoLoopedIndex = normalizedIndex
        pinPhotoScrollIndex = normalizedIndex % count
        withAnimation(.none) {
            proxy.scrollTo(normalizedIndex, anchor: .center)
        }
    }
}

// MARK: - Pin Photo Carousel Preference Key

private struct PinPhotoItemMidXPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - Helper

struct MapPin: Identifiable {
    let id: String
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
