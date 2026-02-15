//
//  CustomPhotoPickerView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI
import Photos

/// 自定義相簿選擇器
struct CustomPhotoPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PhotoPickerViewModel
    
    let onComplete: ([SelectedPhoto]) -> Void
    
    @State private var isLoadingData = false
    
    init(
        photoPickerService: PhotoPickerService,
        requireGPS: Bool = false,
        maxSelection: Int = 10,
        onComplete: @escaping ([SelectedPhoto]) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: PhotoPickerViewModel(
            photoPickerService: photoPickerService,
            requireGPS: requireGPS,
            maxSelection: maxSelection
        ))
        self.onComplete = onComplete
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 篩選控制區
                filterControls
                
                Divider()
                
                // 照片網格
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.photos.isEmpty {
                    emptyView
                } else {
                    photoGrid
                }
            }
            .navigationTitle("選擇照片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        completeSelection()
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.selectedPhotos.isEmpty || isLoadingData)
                }
            }
            .overlay(alignment: .bottom) {
                // 選取計數
                if !viewModel.selectedPhotos.isEmpty {
                    selectionCounter
                }
            }
            .overlay {
                // Toast 提示
                if viewModel.showMaxLimitToast {
                    maxLimitToast
                }
            }
        }
        .task {
            await viewModel.loadPhotos()
        }
    }
    
    // MARK: - Filter Controls
    
    private var filterControls: some View {
        HStack {
            // 時間範圍選擇
            Menu {
                ForEach(DateRangeOption.allCases, id: \.self) { option in
                    Button {
                        Task {
                            await viewModel.changeDateRange(to: option)
                        }
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if viewModel.dateRange == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "calendar")
                    Text(viewModel.dateRange.rawValue)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .font(.subheadline)
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // GPS 篩選指示
            if viewModel.requireGPS {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                    Text("僅顯示有 GPS")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Photo Grid
    
    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2)
                ],
                spacing: 2
            ) {
                ForEach(viewModel.photos) { photo in
                    PhotoCellView(
                        photo: photo,
                        selectionNumber: viewModel.selectionNumber(for: photo),
                        isDisabled: viewModel.isDisabled(photo)
                    ) {
                        viewModel.toggleSelection(photo)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
    
    // MARK: - Supporting Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("載入照片中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("沒有符合條件的照片")
                .font(.headline)
            
            Text(viewModel.requireGPS ? "請確認照片有 GPS 資訊" : "請調整時間範圍")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var selectionCounter: some View {
        HStack {
            Text("已選: \(viewModel.selectedPhotos.count)/\(viewModel.maxSelection) 張")
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.15), radius: 5)
        .padding(.bottom, 20)
    }
    
    private var maxLimitToast: some View {
        VStack {
            Spacer()
            
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.brandOrange)
                Text("已達 \(viewModel.maxSelection) 張上限")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.15), radius: 10)
            
            Spacer()
                .frame(height: 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.3), value: viewModel.showMaxLimitToast)
    }
    
    // MARK: - Actions
    
    private func completeSelection() {
        isLoadingData = true
        
        Task {
            do {
                let selectedPhotos = try await viewModel.loadSelectedPhotosData()
                await MainActor.run {
                    onComplete(selectedPhotos)
                    dismiss()
                }
            } catch {
                // Handle error
                await MainActor.run {
                    isLoadingData = false
                }
            }
        }
    }
}

// MARK: - Photo Cell View

struct PhotoCellView: View {
    let photo: SelectablePhoto
    let selectionNumber: Int?
    let isDisabled: Bool
    let onTap: () -> Void
    
    @State private var thumbnail: UIImage?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                // 照片
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: geometry.size.width, height: geometry.size.width)
                }
                
                // 禁用遮罩
                if isDisabled {
                    Color.black.opacity(0.5)
                }
                
                // 選取編號徽章
                if let number = selectionNumber {
                    selectionBadge(number: number)
                        .padding(6)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
        .aspectRatio(1, contentMode: .fit)
        .task {
            await loadThumbnail()
        }
    }
    
    private func selectionBadge(number: Int) -> some View {
        ZStack {
            Circle()
                .fill(Color.brandBlue)
                .frame(width: 26, height: 26)
            
            Text("\(number)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
        .overlay(
            Circle()
                .stroke(Color.white, lineWidth: 2)
        )
    }
    
    private func loadThumbnail() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        
        let size = CGSize(width: 200, height: 200)
        
        await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: photo.asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image = image {
                    Task { @MainActor in
                        self.thumbnail = image
                    }
                }
                continuation.resume()
            }
        }
    }
}

#Preview {
    CustomPhotoPickerView(
        photoPickerService: PhotoPickerService(),
        requireGPS: true,
        maxSelection: 10
    ) { photos in
        print("Selected \(photos.count) photos")
    }
}
