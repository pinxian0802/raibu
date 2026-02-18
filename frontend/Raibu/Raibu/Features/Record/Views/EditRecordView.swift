//
//  EditRecordView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI
import Combine
import Kingfisher

/// 編輯紀錄視圖
struct EditRecordView: View {
    let recordId: String
    let record: Record
    let uploadService: UploadService
    let recordRepository: RecordRepository
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EditRecordViewModel
    @State private var showErrorAlert = false
    
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
        VStack(spacing: 0) {
            SheetTopHandle()

            NavigationView {
                ScrollView {
                    VStack(spacing: 20) {
                        // 現有圖片
                        existingImagesSection
                        
                        // 描述
                        descriptionSection
                    }
                    .padding()
                }
                .navigationTitle("編輯紀錄")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("儲存") {
                            Task {
                                await viewModel.save()
                                if viewModel.isCompleted {
                                    onComplete()
                                    dismiss()
                                }
                            }
                        }
                        .disabled(!viewModel.canSave || viewModel.isSaving)
                    }
                }
                .overlay {
                    if viewModel.isSaving {
                        ProgressView("儲存中...")
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(radius: 10)
                    }
                }
                .alert("錯誤", isPresented: $showErrorAlert) {
                    Button("確定") {
                        viewModel.errorMessage = nil
                    }
                } message: {
                    if let error = viewModel.errorMessage {
                        Text(error)
                    }
                }
                .onChange(of: viewModel.errorMessage) { newValue in
                    showErrorAlert = newValue != nil
                }
            }
        }
        .presentationDragIndicator(.hidden)
    }
    
    // MARK: - Existing Images Section
    
    private var existingImagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("圖片")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.existingImages) { image in
                        ZStack(alignment: .topTrailing) {
                            KFImage(URL(string: image.thumbnailPublicUrl ?? ""))
                                .placeholder {
                                    Rectangle()
                                        .fill(Color.appDisabled.opacity(0.2))
                                        .frame(width: 100, height: 100)
                                        .cornerRadius(8)
                                }
                                .retry(maxCount: 2, interval: .seconds(1))
                                .cacheOriginalImage()
                                .fade(duration: 0.2)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipped()
                                .cornerRadius(8)
                            
                            // 刪除按鈕
                            Button {
                                viewModel.removeImage(image)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.appOnPrimary)
                                    .background(Circle().fill(Color.appOverlay.opacity(0.5)))
                            }
                            .padding(4)
                        }
                    }
                }
            }
            
            if viewModel.existingImages.isEmpty {
                Text("至少需要一張圖片")
                    .font(.caption)
                    .foregroundColor(.appDanger)
            }
        }
    }
    
    // MARK: - Description Section
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("描述")
                .font(.headline)
            
            TextEditor(text: $viewModel.description)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
}

// MARK: - View Model

@MainActor
class EditRecordViewModel: ObservableObject {
    @Published var description: String
    @Published var existingImages: [ImageMedia]
    @Published var isSaving = false
    @Published var isCompleted = false
    @Published var errorMessage: String?
    
    private let recordId: String
    private let uploadService: UploadService
    private let recordRepository: RecordRepository
    
    var canSave: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !existingImages.isEmpty
    }
    
    init(record: Record, uploadService: UploadService, recordRepository: RecordRepository) {
        self.recordId = record.id
        self.description = record.description
        self.existingImages = record.images ?? []
        self.uploadService = uploadService
        self.recordRepository = recordRepository
    }
    
    func removeImage(_ image: ImageMedia) {
        existingImages.removeAll { $0.id == image.id }
    }
    
    func save() async {
        guard canSave else { return }
        
        isSaving = true
        errorMessage = nil
        
        do {
            // 建立 sorted_images (按 images 陣列順序即為 display_order)
            let sortedImages = existingImages.map { image in
                SortedImageItem(
                    type: .existing,
                    imageId: image.id,
                    uploadId: nil,
                    location: image.location,
                    capturedAt: image.capturedAt
                )
            }
            
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
