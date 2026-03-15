//
//  EditAskView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI
import Combine
import MapKit
import Kingfisher
import UIKit

/// 編輯詢問視圖
struct EditAskView: View {
    let askId: String
    let ask: Ask
    let uploadService: UploadService
    let askRepository: AskRepository
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var container: DIContainer

    @StateObject private var viewModel: EditAskViewModel
    @State private var showPhotoPicker = false
    @State private var showErrorAlert = false
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isQuestionFocused: Bool

    // 標點圖片選取
    @State private var isPickingPinPhoto = false
    @State private var pinPhotoScrollIndex = 0
    @State private var pinPhotoLoopedIndex = 0
    @State private var isPinPhotoDragging = false

    private let maxPhotoCount = 5
    private let placeholderFont = Font.custom("PingFangTC-Medium", size: 17)
    private let bodyFont = Font.custom("PingFangTC-Regular", size: 17)
    private let metaFont = Font.custom("PingFangTC-Medium", size: 12)
    private let mapPinTitleFont = Font.custom("PingFangTC-Semibold", size: 13)
    private let mapPinTitleUIFont = UIFont(name: "PingFangTC-Semibold", size: 13) ?? UIFont.systemFont(ofSize: 13, weight: .semibold)
    private let mapPinTitleHorizontalPadding: CGFloat = 8
    private let mapPinTitleMaxWidth: CGFloat = 150
    private let mapPinAvatarSize: CGFloat = 70
    private let mapPinTitleMinCardWidth: CGFloat = 52
    private let actionGreen = Color(red: 29 / 255, green: 223 / 255, blue: 97 / 255)
    private let showRadiusControls = false

    init(
        askId: String,
        ask: Ask,
        uploadService: UploadService,
        askRepository: AskRepository,
        onComplete: @escaping () -> Void
    ) {
        self.askId = askId
        self.ask = ask
        self.uploadService = uploadService
        self.askRepository = askRepository
        self.onComplete = onComplete

        _viewModel = StateObject(wrappedValue: EditAskViewModel(
            ask: ask,
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
                .disabled(viewModel.isSaving)
                .buttonStyle(.plain)
            },
            title: {
                Text("編輯詢問")
                    .font(.custom("PingFangTC-Semibold", size: 37 / 2))
                    .foregroundColor(.primary)
            },
            trailing: {
                Button {
                    isTitleFocused = false
                    isQuestionFocused = false
                    Task {
                        await viewModel.save()
                    }
                } label: {
                    Group {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(actionGreen)
                        } else {
                            Text("儲存")
                        }
                    }
                    .font(.custom("PingFangTC-Semibold", size: 17))
                }
                .foregroundColor(viewModel.canSave ? actionGreen : .secondary)
                .disabled(!viewModel.canSave)
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

                            statusSection
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
                maxSelection: max(0, maxPhotoCount - viewModel.existingImages.count),
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
                onComplete()
                dismiss()
            }
        }
        .onTapGesture {
            isTitleFocused = false
            isQuestionFocused = false
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
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

        if let avatar = ask.author?.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
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

        if let name = ask.author?.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }

        return "使用者"
    }

    // MARK: - Map & Radius Section

    private var mapAndRadiusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: viewModel.center,
                    span: MKCoordinateSpan(
                        latitudeDelta: Double(viewModel.radiusMeters) / 50000,
                        longitudeDelta: Double(viewModel.radiusMeters) / 50000
                    )
                )), annotationItems: [EditAskMapPin(id: "edit-ask-pin", coordinate: viewModel.center)]) { pin in
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
                if let idx = viewModel.pinPhotoIndex,
                   idx < attachmentItems.count {
                    attachmentPreviewView(for: attachmentItems[idx])
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
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 4)
                )
        }
    }

    private func attachmentPreviewView(for attachment: AskAttachmentItem) -> some View {
        Group {
            switch attachment {
            case .existing(let image):
                KFImage(URL(string: image.thumbnailPublicUrl))
                    .placeholder {
                        Circle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.secondary)
                            )
                    }
                    .retry(maxCount: 2, interval: .seconds(1))
                    .cacheOriginalImage()
                    .fade(duration: 0.2)
                    .resizable()
                    .scaledToFill()
            case .new(let photo):
                if let image = UIImage(data: photo.thumbnailData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Circle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.secondary)
                        )
                }
            }
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
                        HStack(spacing: 12) {
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
                        HStack(spacing: 12) {
                            if !attachmentItems.isEmpty {
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
                                .disabled(viewModel.isSaving)
                            }

                            addPhotoButton
                        }
                    }
                }
                .frame(height: 32, alignment: .center)

                Group {
                    if isPickingPinPhoto {
                        pinPhotoCarouselView
                    } else if attachmentItems.isEmpty {
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

    private var attachmentItems: [AskAttachmentItem] {
        viewModel.existingImages.map { AskAttachmentItem.existing($0) } +
        viewModel.selectedPhotos.map { AskAttachmentItem.new($0) }
    }

    // MARK: - 標點圖片輪播選取器

    private var pinPhotoCarouselView: some View {
        let items = attachmentItems
        let count = items.count
        let itemWidth: CGFloat = 136
        let itemSpacing: CGFloat = 12
        let centerOffset = count

        return Group {
            if count == 0 {
                EmptyView()
                    .frame(height: 184)
            } else {
                let loopedItems: [(Int, Int, AskAttachmentItem)] = (0..<(count * 3)).map { i in
                    (i, i % count, items[i % count])
                }

                GeometryReader { geo in
                    let availableWidth = geo.size.width
                    let sideInset: CGFloat = 20
                    let centerX = availableWidth / 2 + sideInset

                    ScrollViewReader { proxy in
                        VStack(alignment: .leading, spacing: 8) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: itemSpacing) {
                                    ForEach(loopedItems, id: \.0) { loopIdx, _, item in
                                        let isSelected = loopIdx == pinPhotoLoopedIndex

                                        attachmentThumbnailView(for: item)
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
                                                            key: EditAskPinPhotoItemMidXPreferenceKey.self,
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
                            .onPreferenceChange(EditAskPinPhotoItemMidXPreferenceKey.self) { midXValues in
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
                    ForEach(Array(attachmentItems.enumerated()), id: \.element.id) { index, item in
                        attachmentItemView(item: item, index: index)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }
            .padding(.horizontal, -20)
            .frame(height: 176)

            Text("\(attachmentItems.count)/\(maxPhotoCount) 張")
                .font(metaFont)
                .foregroundColor(.secondary)
                .padding(.leading, 2)
        }
        .frame(height: 184, alignment: .bottomLeading)
    }

    private func attachmentItemView(item: AskAttachmentItem, index: Int) -> some View {
        attachmentThumbnailView(for: item)
            .frame(width: 136, height: 176)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .topLeading) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        removeAttachment(at: index)
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

    private func attachmentThumbnailView(for attachment: AskAttachmentItem) -> some View {
        Group {
            switch attachment {
            case .existing(let image):
                KFImage(URL(string: image.thumbnailPublicUrl))
                    .placeholder {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            )
                    }
                    .retry(maxCount: 2, interval: .seconds(1))
                    .cacheOriginalImage()
                    .fade(duration: 0.2)
                    .resizable()
                    .scaledToFill()
            case .new(let photo):
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
        }
    }

    private func removeAttachment(at index: Int) {
        if viewModel.pinPhotoIndex == index {
            viewModel.pinPhotoIndex = nil
        } else if let current = viewModel.pinPhotoIndex, current > index {
            viewModel.pinPhotoIndex = current - 1
        }

        let items = attachmentItems
        guard index >= 0, index < items.count else { return }
        switch items[index] {
        case .existing(let image):
            viewModel.removeExistingImage(image)
        case .new(let photo):
            viewModel.removeNewPhoto(photo)
        }
    }

    private var addPhotoButton: some View {
        Button {
            showPhotoPicker = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(viewModel.photoCount < maxPhotoCount && !viewModel.isSaving ? .black : .secondary)
                .frame(width: 28, height: 28, alignment: .center)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.photoCount >= maxPhotoCount || viewModel.isSaving)
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

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("狀態")
                .font(.custom("PingFangTC-Semibold", size: 16))

            Picker("狀態", selection: $viewModel.status) {
                Text("進行中").tag(AskStatus.active)
                Text("已解決").tag(AskStatus.resolved)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 24)
    }
}

private enum AskAttachmentItem: Identifiable {
    case existing(ImageMedia)
    case new(SelectedPhoto)

    var id: String {
        switch self {
        case .existing(let image):
            return "existing-\(image.id)"
        case .new(let photo):
            return "new-\(photo.id)"
        }
    }
}

// MARK: - Route Entry

struct AskEditRouteView: View {
    let askId: String
    let prefetchedAsk: Ask?
    let uploadService: UploadService
    let askRepository: AskRepository
    let onComplete: () -> Void

    @State private var ask: Ask?
    @State private var isLoading: Bool
    @State private var errorMessage: String?
    @State private var hasStartedInitialLoad = false

    init(
        askId: String,
        prefetchedAsk: Ask?,
        uploadService: UploadService,
        askRepository: AskRepository,
        onComplete: @escaping () -> Void
    ) {
        self.askId = askId
        self.prefetchedAsk = prefetchedAsk
        self.uploadService = uploadService
        self.askRepository = askRepository
        self.onComplete = onComplete
        _ask = State(initialValue: prefetchedAsk)
        _isLoading = State(initialValue: prefetchedAsk == nil)
    }

    var body: some View {
        Group {
            if let ask {
                EditAskView(
                    askId: askId,
                    ask: ask,
                    uploadService: uploadService,
                    askRepository: askRepository,
                    onComplete: onComplete
                )
            } else if isLoading {
                VStack(spacing: 0) {
                    SheetTopHandle()
                    AskDetailSkeleton()
                }
                .background(Color.appSurface)
            } else {
                VStack(spacing: 16) {
                    SheetTopHandle()
                    Spacer()

                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)

                    Text(errorMessage ?? "載入失敗")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("重試") {
                        Task {
                            await loadAsk()
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
        }
        .task {
            guard !hasStartedInitialLoad else { return }
            hasStartedInitialLoad = true
            guard ask == nil else { return }
            await loadAsk()
        }
    }

    @MainActor
    private func loadAsk() async {
        isLoading = true
        errorMessage = nil

        do {
            ask = try await askRepository.getAskDetail(id: askId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Pin Photo Carousel Preference Key

private struct EditAskPinPhotoItemMidXPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - Helper

private struct EditAskMapPin: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
}

// MARK: - View Model

@MainActor
class EditAskViewModel: ObservableObject {
    @Published var center: CLLocationCoordinate2D
    @Published var radiusMeters: Int
    @Published var title: String
    @Published var question: String
    @Published var existingImages: [ImageMedia]
    @Published var selectedPhotos: [SelectedPhoto] = []
    @Published var pinPhotoIndex: Int? = nil
    @Published var status: AskStatus
    @Published var isSaving = false
    @Published var isCompleted = false
    @Published var errorMessage: String?

    private let askId: String
    private let uploadService: UploadService
    private let askRepository: AskRepository

    let radiusOptions = [100, 500, 1000]

    var canSave: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSaving
    }

    var photoCount: Int {
        existingImages.count + selectedPhotos.count
    }

    var radiusText: String {
        if radiusMeters >= 1000 {
            return "\(radiusMeters / 1000) 公里"
        }
        return "\(radiusMeters) 公尺"
    }

    init(ask: Ask, uploadService: UploadService, askRepository: AskRepository) {
        self.askId = ask.id
        self.center = ask.center.clLocationCoordinate
        self.radiusMeters = ask.radiusMeters
        self.title = ask.title ?? ""
        self.question = ask.question
        self.existingImages = (ask.images ?? []).sorted { $0.displayOrder < $1.displayOrder }
        self.status = ask.status
        self.uploadService = uploadService
        self.askRepository = askRepository
    }

    func setPhotos(_ photos: [SelectedPhoto]) {
        selectedPhotos = photos
    }

    func removeExistingImage(_ image: ImageMedia) {
        existingImages.removeAll { $0.id == image.id }
    }

    func removeNewPhoto(_ photo: SelectedPhoto) {
        selectedPhotos.removeAll { $0.id == photo.id }
    }

    func save() async {
        guard canSave else { return }

        isSaving = true
        errorMessage = nil

        do {
            let uploadedImages: [UploadedImage]
            if selectedPhotos.isEmpty {
                uploadedImages = []
            } else {
                uploadedImages = try await uploadService.uploadPhotos(selectedPhotos, context: .ask)
            }

            let existingItems = existingImages.map { image in
                SortedImageItem(
                    type: .existing,
                    imageId: image.id,
                    uploadId: nil,
                    location: image.location,
                    capturedAt: image.capturedAt
                )
            }

            let newItems = uploadedImages.map { image in
                SortedImageItem(
                    type: .new,
                    imageId: nil,
                    uploadId: image.uploadId,
                    location: image.location,
                    capturedAt: image.capturedAt
                )
            }

            let sortedImages = existingItems + newItems

            try await askRepository.updateAsk(
                id: askId,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                question: question.trimmingCharacters(in: .whitespacesAndNewlines),
                status: status,
                sortedImages: sortedImages
            )

            isCompleted = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
