//
//  EditRecordView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI
import Combine
import Photos
import Kingfisher

/// 編輯紀錄視圖
struct EditRecordView: View {
    let recordId: String
    let record: Record
    let uploadService: UploadService
    let recordRepository: RecordRepository
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var container: DIContainer
    @StateObject private var viewModel: EditRecordViewModel
    @State private var showErrorAlert = false
    @State private var showPhotoPicker = false
    @State private var photoPickerPresentationID = UUID()
    @State private var pickerInitialSelectedAssetIDs: [String] = []
    @State private var inferredExistingAssetIDSet: Set<String> = []
    @State private var isPreparingPhotoPicker = false
    @FocusState private var isDescriptionFocused: Bool
    
    private let maxPhotoCount = 10
    private let placeholderFont = Font.custom("PingFangTC-Medium", size: 39 / 2)
    private let bodyFont = Font.custom("PingFangTC-Regular", size: 18)
    private let metaFont = Font.custom("PingFangTC-Medium", size: 12)
    private let actionGreen = Color(red: 29 / 255, green: 223 / 255, blue: 97 / 255)
    
    init(
        recordId: String,
        record: Record,
        uploadService: UploadService,
        recordRepository: RecordRepository,
        onComplete: @escaping () -> Void
    ) {
        self.recordId = recordId
        self.record = record
        self.uploadService = uploadService
        self.recordRepository = recordRepository
        self.onComplete = onComplete
        
        _viewModel = StateObject(wrappedValue: EditRecordViewModel(
            record: record,
            uploadService: uploadService,
            recordRepository: recordRepository
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
                .disabled(viewModel.isSaving)
                .buttonStyle(.plain)
            },
            title: {
                Text("編輯紀錄")
                    .font(.custom("PingFangTC-Semibold", size: 37 / 2))
                    .foregroundColor(.primary)
            },
            trailing: {
                Button {
                    isDescriptionFocused = false
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
                    composerSection
                    
                    Divider()
                        .padding(.horizontal, 24)
                    
                    attachmentsSection
                }
            }
        )
        .background(Color.appSurface)
        .sheet(isPresented: $showPhotoPicker) {
            CustomPhotoPickerView(
                photoPickerService: container.photoPickerService,
                requireGPS: true,
                maxSelection: maxPhotoCount,
                initialSelectedAssetIDs: pickerInitialSelectedAssetIDs
            ) { photos in
                let newPhotosOnly = photos.filter { photo in
                    !inferredExistingAssetIDSet.contains(photo.asset.localIdentifier)
                }
                viewModel.setPhotos(newPhotosOnly)
            }
            .id(photoPickerPresentationID)
        }
        .alert("錯誤", isPresented: $showErrorAlert) {
            Button("確定") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showErrorAlert = newValue != nil
        }
        .onChange(of: viewModel.isCompleted) { _, completed in
            if completed {
                onComplete()
                dismiss()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .presentationDragIndicator(.hidden)
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
                    Text("更新你想分享的內容...")
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
        
        if let avatar = record.author?.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
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
        
        if let name = record.author?.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        
        return "使用者"
    }
    
    // MARK: - Attachment Section
    
    private var attachmentsSection: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("最多可選取 10 張照片")
                        .font(.custom("PingFangTC-Medium", size: 13))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    addPhotoButton
                }
                
                if viewModel.photoCount == 0 {
                    emptyPhotosHintView
                } else {
                    selectedPhotosView
                        .padding(.top, 8)
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
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(attachmentThumbnails) { thumbnail in
                        attachmentThumbnailView(thumbnail)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }
            .padding(.horizontal, -20)
            .frame(height: 176)
            
            Text("\(viewModel.photoCount)/\(maxPhotoCount) 張")
                .font(metaFont)
                .foregroundColor(.secondary)
                .padding(.leading, 2)
        }
        .frame(height: 184, alignment: .bottomLeading)
    }
    
    private func attachmentThumbnailView(_ thumbnail: AttachmentThumbnail) -> some View {
        Group {
            switch thumbnail {
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
        .frame(width: 136, height: 176)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topLeading) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    switch thumbnail {
                    case .existing(let image):
                        viewModel.removeExistingImage(image)
                    case .new(let photo):
                        viewModel.removeNewPhoto(photo)
                    }
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
    
    private var attachmentThumbnails: [AttachmentThumbnail] {
        let existing = viewModel.existingImages.map { AttachmentThumbnail.existing($0) }
        let selected = viewModel.selectedPhotos.map { AttachmentThumbnail.new($0) }
        return existing + selected
    }
    
    // MARK: - Photo Action
    
    @MainActor
    private func preparePhotoPickerAndPresent() async {
        guard !isPreparingPhotoPicker else { return }
        
        isPreparingPhotoPicker = true
        defer { isPreparingPhotoPicker = false }
        
        let inferredExistingIDs = await container.photoPickerService.inferAssetLocalIdentifiers(
            for: viewModel.existingImages
        )
        let selectedIDs = viewModel.selectedPhotos.map { $0.asset.localIdentifier }
        
        var mergedIDs: [String] = []
        var seenIDs: Set<String> = []
        for assetID in inferredExistingIDs + selectedIDs {
            if seenIDs.insert(assetID).inserted {
                mergedIDs.append(assetID)
            }
        }
        
        inferredExistingAssetIDSet = Set(inferredExistingIDs)
        pickerInitialSelectedAssetIDs = mergedIDs
        photoPickerPresentationID = UUID()
        showPhotoPicker = true
    }
    
    private var addPhotoButton: some View {
        Button {
            Task {
                await preparePhotoPickerAndPresent()
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(viewModel.photoCount < maxPhotoCount && !viewModel.isSaving && !isPreparingPhotoPicker ? .black : .secondary)
                .frame(width: 28, height: 28, alignment: .center)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.photoCount >= maxPhotoCount || viewModel.isSaving || isPreparingPhotoPicker)
    }
}

private enum AttachmentThumbnail: Identifiable {
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

struct RecordEditRouteView: View {
    let recordId: String
    let prefetchedRecord: Record?
    let recordRepository: RecordRepository
    let uploadService: UploadService
    let onComplete: () -> Void

    @State private var record: Record?
    @State private var isLoading: Bool
    @State private var errorMessage: String?
    @State private var hasStartedInitialLoad = false

    init(
        recordId: String,
        prefetchedRecord: Record?,
        recordRepository: RecordRepository,
        uploadService: UploadService,
        onComplete: @escaping () -> Void
    ) {
        self.recordId = recordId
        self.prefetchedRecord = prefetchedRecord
        self.recordRepository = recordRepository
        self.uploadService = uploadService
        self.onComplete = onComplete
        _record = State(initialValue: prefetchedRecord)
        _isLoading = State(initialValue: prefetchedRecord == nil)
    }

    var body: some View {
        Group {
            if let record {
                EditRecordView(
                    recordId: recordId,
                    record: record,
                    uploadService: uploadService,
                    recordRepository: recordRepository,
                    onComplete: onComplete
                )
            } else if isLoading {
                VStack(spacing: 0) {
                    SheetTopHandle()
                    RecordDetailSkeleton()
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
                            await loadRecord()
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
            guard record == nil else { return }
            await loadRecord()
        }
    }

    @MainActor
    private func loadRecord() async {
        isLoading = true
        errorMessage = nil

        do {
            record = try await recordRepository.getRecordDetail(id: recordId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - View Model

@MainActor
class EditRecordViewModel: ObservableObject {
    @Published var description: String
    @Published var existingImages: [ImageMedia]
    @Published var selectedPhotos: [SelectedPhoto] = []
    @Published var isSaving = false
    @Published var isCompleted = false
    @Published var errorMessage: String?
    
    private let recordId: String
    private let uploadService: UploadService
    private let recordRepository: RecordRepository
    
    var canSave: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        photoCount > 0 &&
        !isSaving
    }
    
    var photoCount: Int {
        existingImages.count + selectedPhotos.count
    }
    
    init(record: Record, uploadService: UploadService, recordRepository: RecordRepository) {
        self.recordId = record.id
        self.description = record.description
        self.existingImages = record.images ?? []
        self.uploadService = uploadService
        self.recordRepository = recordRepository
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
                uploadedImages = try await uploadService.uploadPhotos(selectedPhotos, context: .record)
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
            
            _ = try await recordRepository.updateRecord(
                id: recordId,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                sortedImages: sortedImages
            )
            
            isCompleted = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSaving = false
    }
}
