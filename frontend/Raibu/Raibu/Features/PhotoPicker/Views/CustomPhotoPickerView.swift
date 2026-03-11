//
//  CustomPhotoPickerView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI
import Photos
import UIKit

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
        initialSelectedPhotos: [SelectedPhoto] = [],
        initialSelectedAssetIDs: [String]? = nil,
        onComplete: @escaping ([SelectedPhoto]) -> Void
    ) {
        let initialSelectedAssetIDs = initialSelectedAssetIDs
            ?? initialSelectedPhotos.map { $0.asset.localIdentifier }
        _viewModel = StateObject(wrappedValue: PhotoPickerViewModel(
            photoPickerService: photoPickerService,
            requireGPS: requireGPS,
            maxSelection: maxSelection,
            initialSelectedAssetIDs: initialSelectedAssetIDs
        ))
        self.onComplete = onComplete
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SheetTopHandle()
            sheetHeader

            // 已選照片預覽區
            if !viewModel.selectedPhotos.isEmpty {
                selectedPhotosPreviewSection
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 7)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // 照片內容區
            photoContent
        }
        .background(Color.appSurface)
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
        .task {
            await viewModel.loadPhotos()
        }
        .presentationDragIndicator(.hidden)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.selectedPhotos.map(\.id))
    }
    
    // MARK: - Filter Controls

    private var sheetHeader: some View {
        ZStack {
            Text("選擇照片")
                .font(.system(size: 38 / 2, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            HStack {
                Button("取消") {
                    dismiss()
                }
                .font(.custom("PingFangTC-Medium", size: 17))
                .foregroundColor(.secondary)
                .buttonStyle(.plain)
                
                Spacer()
                
                Button("完成") {
                    completeSelection()
                }
                .font(.custom("PingFangTC-Semibold", size: 17))
                .foregroundColor((viewModel.selectedPhotos.isEmpty || isLoadingData) ? .secondary : .brandBlue)
                .disabled(viewModel.selectedPhotos.isEmpty || isLoadingData)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var selectedPhotosPreviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("已選照片")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                Spacer()

                Text("\(viewModel.selectedPhotos.count)/\(viewModel.maxSelection) 張")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(.systemBackground).opacity(0.92))
                    .overlay(
                        Capsule()
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
                    .clipShape(Capsule())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.selectedPhotos) { photo in
                        SelectedPhotoPreviewCellView(photo: photo) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.toggleSelection(photo)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
            .padding(.horizontal, -16)
            .frame(height: 184)
        }
    }
    
    // MARK: - Photo Grid

    private var photoContent: some View {
        Group {
            if viewModel.photos.isEmpty {
                if viewModel.isLoading {
                    loadingView
                } else {
                    emptyView
                }
            } else {
                ZStack {
                    photoGrid

                    if viewModel.isLoading {
                        Color.appOverlay.opacity(0.08)
                            .ignoresSafeArea()

                        VStack(spacing: 8) {
                            ProgressView()
                            Text("更新中...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: Color.appOverlay.opacity(0.08), radius: 6, x: 0, y: 2)
                    }
                }
            }
        }
    }
    
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
            
            Text(viewModel.requireGPS ? "請確認照片有 GPS 資訊" : "相簿中沒有可選取的照片")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var selectionCounter: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.brandBlue)
            Text("已選 \(viewModel.selectedPhotos.count)/\(viewModel.maxSelection) 張")
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.appOverlay.opacity(0.68))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.appOverlay.opacity(0.22), radius: 6, x: 0, y: 2)
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
            .shadow(color: Color.appOverlay.opacity(0.15), radius: 10)
            
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
                    Color.appOverlay.opacity(0.5)
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
                .fill(Color.black.opacity(0.45))
                .frame(width: 26, height: 26)
            
            Text("\(number)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
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

private struct SelectedPhotoPreviewCellView: View {
    let photo: SelectablePhoto
    let onRemove: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    )
            }
        }
        .frame(width: 136, height: 176)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topLeading) {
            Button(action: onRemove) {
                Circle()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: 33, height: 33)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .task(id: photo.id) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true

        let size = CGSize(width: 420, height: 540)

        await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: photo.asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image = image {
                    Task { @MainActor in
                        thumbnail = image
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
