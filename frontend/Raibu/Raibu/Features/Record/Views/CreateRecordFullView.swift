//
//  CreateRecordView.swift (Complete Implementation)
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI

/// 建立紀錄視圖
struct CreateRecordFullView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var container: DIContainer
    
    @StateObject private var viewModel: CreateRecordViewModel
    @State private var showPhotoPicker = false
    @State private var showErrorAlert = false
    
    init(uploadService: UploadService, recordRepository: RecordRepository) {
        _viewModel = StateObject(wrappedValue: CreateRecordViewModel(
            uploadService: uploadService,
            recordRepository: recordRepository
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 照片選擇區
                        photoSection
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // 描述輸入區
                        descriptionSection
                    }
                    .padding(.vertical, 16)
                }
                
                // 底部提交按鈕
                submitButton
            }
            .navigationTitle("新增紀錄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(viewModel.isUploading)
                }
            }
            .sheet(isPresented: $showPhotoPicker) {
                CustomPhotoPickerView(
                    photoPickerService: container.photoPickerService,
                    requireGPS: true,
                    maxSelection: 10
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
        }
    }
    
    // MARK: - Photo Section
    
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("照片")
                    .font(.headline)
                
                Text("(必填，最多 10 張)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            if viewModel.selectedPhotos.isEmpty {
                // 空狀態
                emptyPhotoView
            } else {
                // 已選照片
                selectedPhotosView
            }
            
            // GPS 提示
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                Text("僅顯示有 GPS 資訊的照片")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
    }
    
    private var emptyPhotoView: some View {
        Button {
            showPhotoPicker = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                Text("選擇照片")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Text("從相簿中選取有 GPS 資訊的照片")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [8]))
            )
        }
        .padding(.horizontal)
    }
    
    private var selectedPhotosView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(viewModel.selectedPhotos.enumerated()), id: \.element.id) { index, photo in
                        photoThumbnail(photo: photo, index: index)
                    }
                    
                    // 新增按鈕
                    if viewModel.photoCount < 10 {
                        addMoreButton
                    }
                }
                .padding(.horizontal)
            }
            
            Text("\(viewModel.photoCount)/10 張")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }
    
    private func photoThumbnail(photo: SelectedPhoto, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: UIImage(data: photo.thumbnailData) ?? UIImage())
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // 刪除按鈕
            Button {
                withAnimation {
                    viewModel.removePhoto(at: index)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .offset(x: 6, y: -6)
            
            // 順序編號
            Text("\(index + 1)")
                .font(.caption2.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.blue))
                .position(x: 14, y: 68)
        }
    }
    
    private var addMoreButton: some View {
        Button {
            showPhotoPicker = true
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.title3)
                Text("新增")
                    .font(.caption)
            }
            .foregroundColor(.blue)
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [6]))
            )
        }
    }
    
    // MARK: - Description Section
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("描述")
                .font(.headline)
                .padding(.horizontal)
            
            TextEditor(text: $viewModel.description)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
                .overlay(
                    Group {
                        if viewModel.description.isEmpty {
                            Text("分享這個地點的故事...")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 28)
                                .padding(.top, 16)
                        }
                    },
                    alignment: .topLeading
                )
        }
    }
    
    // MARK: - Submit Button
    
    private var submitButton: some View {
        VStack(spacing: 0) {
            Divider()
            
            Button {
                Task {
                    await viewModel.submit()
                }
            } label: {
                ZStack {
                    if viewModel.isUploading {
                        HStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("上傳中... \(Int(viewModel.uploadProgress * 100))%")
                        }
                    } else {
                        Text("發布")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(viewModel.canSubmit ? Color.blue : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!viewModel.canSubmit)
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    CreateRecordFullView(
        uploadService: UploadService(apiClient: APIClient(baseURL: "", authService: AuthService())),
        recordRepository: RecordRepository(apiClient: APIClient(baseURL: "", authService: AuthService()))
    )
    .environmentObject(DIContainer())
}
