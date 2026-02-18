//
//  ReplyCreateView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI

/// 建立回覆視圖
struct ReplyCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var container: DIContainer
    
    let recordId: String?
    let askId: String?
    let onReplyCreated: () -> Void
    
    @State private var content = ""
    @State private var selectedPhotos: [SelectedPhoto] = []
    @State private var showPhotoPicker = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            SheetTopHandle()

            NavigationView {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // 文字輸入
                            TextEditor(text: $content)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .overlay(
                                    Group {
                                        if content.isEmpty {
                                            Text("分享你的看法...")
                                                .foregroundColor(.secondary)
                                                .padding(.leading, 12)
                                                .padding(.top, 16)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                            
                            // 照片區
                            photoSection
                        }
                        .padding()
                    }
                    
                    // 提交按鈕
                    submitButton
                }
                .navigationTitle("新增回覆")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") {
                            dismiss()
                        }
                        .disabled(isSubmitting)
                    }
                }
                .sheet(isPresented: $showPhotoPicker) {
                    CustomPhotoPickerView(
                        photoPickerService: container.photoPickerService,
                        requireGPS: false,
                        maxSelection: 5,
                        initialSelectedPhotos: selectedPhotos
                    ) { photos in
                        selectedPhotos = photos
                    }
                }
                .alert("錯誤", isPresented: $showErrorAlert) {
                    Button("確定") {
                        errorMessage = nil
                    }
                } message: {
                    Text(errorMessage ?? "")
                }
                .onChange(of: errorMessage) { newValue in
                    showErrorAlert = newValue != nil
                }
            }
        }
        .presentationDragIndicator(.hidden)
    }
    
    // MARK: - Photo Section
    
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("附圖")
                    .font(.headline)
                
                Text("(選填，最多 5 張)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if selectedPhotos.isEmpty {
                Button {
                    showPhotoPicker = true
                } label: {
                    HStack {
                        Image(systemName: "photo.badge.plus")
                        Text("新增照片")
                    }
                    .font(.subheadline)
                    .foregroundColor(.brandBlue)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(selectedPhotos.enumerated()), id: \.element.id) { index, photo in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: UIImage(data: photo.thumbnailData) ?? UIImage())
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                Button {
                                    withAnimation {
                                        _ = selectedPhotos.remove(at: index)
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.appOnPrimary)
                                        .background(Circle().fill(Color.appOverlay.opacity(0.5)))
                                }
                                .offset(x: 6, y: -6)
                            }
                        }
                        
                        if selectedPhotos.count < 5 {
                            Button {
                                showPhotoPicker = true
                            } label: {
                                Image(systemName: "plus")
                                    .foregroundColor(.brandBlue)
                                    .frame(width: 60, height: 60)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.brandBlue, style: StrokeStyle(lineWidth: 2, dash: [6]))
                                    )
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Submit Button
    
    private var submitButton: some View {
        VStack(spacing: 0) {
            Divider()
            
            Button {
                submitReply()
            } label: {
                ZStack {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("送出回覆")
                    }
                }
                .font(.headline)
                .foregroundColor(.appOnPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canSubmit ? Color.brandBlue : Color.appDisabled)
                .cornerRadius(12)
            }
            .disabled(!canSubmit)
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helpers
    
    private var canSubmit: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }
    
    private func submitReply() {
        isSubmitting = true
        
        Task {
            do {
                var uploadedImages: [UploadedImage]?
                
                if !selectedPhotos.isEmpty {
                    uploadedImages = try await container.uploadService.uploadPhotos(selectedPhotos, context: .reply)
                }
                
                let _ = try await container.replyRepository.createReply(
                    recordId: recordId,
                    askId: askId,
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                    images: uploadedImages
                )
                
                await MainActor.run {
                    onReplyCreated()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmitting = false
                }
            }
        }
    }
}

#Preview {
    ReplyCreateView(
        recordId: "test-record-id",
        askId: nil,
        onReplyCreated: {}
    )
    .environmentObject(DIContainer())
}
