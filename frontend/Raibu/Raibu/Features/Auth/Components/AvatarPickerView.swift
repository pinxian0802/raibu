//
//  AvatarPickerView.swift
//  Raibu
//
//  可重用的頭貼選擇器組件
//

import SwiftUI
import Kingfisher

/// 頭貼選擇器視圖
struct AvatarPickerView: View {
    @EnvironmentObject private var container: DIContainer
    @Binding var selectedImage: UIImage?
    var currentAvatarURL: String? = nil
    var size: CGFloat = 120
    var showsCameraBadge: Bool = true
    
    @State private var showPhotoPicker = false
    @State private var selectedPhoto: SelectedPhoto?
    @State private var isLoading = false
    
    var body: some View {
        Button {
            showPhotoPicker = true
        } label: {
            ZStack {
                // 頭貼預覽
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else if let avatarURLString = currentAvatarURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !avatarURLString.isEmpty,
                          let avatarURL = URL(string: avatarURLString) {
                    KFImage(avatarURL)
                        .placeholder {
                            defaultAvatarPlaceholder
                        }
                        .retry(maxCount: 2, interval: .seconds(1))
                        .cacheOriginalImage()
                        .fade(duration: 0.2)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else {
                    // 預設圖示
                    defaultAvatarPlaceholder
                }
                
                if showsCameraBadge {
                    // 相機圖示 overlay
                    Circle()
                        .fill(Color.brandBlue)
                        .frame(width: size * 0.3, height: size * 0.3)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: size * 0.12))
                                .foregroundColor(.appOnPrimary)
                        )
                        .offset(x: size * 0.35, y: size * 0.35)
                }
                
                // Loading overlay
                if isLoading {
                    Circle()
                        .fill(Color.appOverlay.opacity(0.3))
                        .frame(width: size, height: size)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showPhotoPicker) {
            CustomPhotoPickerView(
                photoPickerService: container.photoPickerService,
                requireGPS: false,
                maxSelection: 1,
                showsSelectedPreview: false,
                initialSelectedPhotos: selectedPhoto.map { [$0] } ?? []
            ) { photos in
                guard let firstPhoto = photos.first else { return }
                isLoading = true
                applySelectedPhoto(firstPhoto)
                isLoading = false
            }
        }
    }
    
    private func applySelectedPhoto(_ photo: SelectedPhoto) {
        guard let uiImage = UIImage(data: photo.originalData) else { return }

        // 裁切為正方形並調整大小
        selectedImage = cropToSquare(uiImage)
        selectedPhoto = photo
    }

    private var defaultAvatarPlaceholder: some View {
        Circle()
            .fill(Color(.systemGray5))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundColor(.gray)
            )
    }
    
    /// 裁切為正方形（包含方向修正）
    private func cropToSquare(_ image: UIImage) -> UIImage {
        // 先修正圖片方向
        let fixedImage = fixOrientation(image)
        
        let size = min(fixedImage.size.width, fixedImage.size.height)
        let x = (fixedImage.size.width - size) / 2
        let y = (fixedImage.size.height - size) / 2
        
        // 裁切為正方形並調整為 400x400
        let targetSize = CGSize(width: 400, height: 400)
        let cropRect = CGRect(x: x, y: y, width: size, height: size)
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        fixedImage.draw(in: CGRect(
            x: -cropRect.origin.x * (targetSize.width / size),
            y: -cropRect.origin.y * (targetSize.height / size),
            width: fixedImage.size.width * (targetSize.width / size),
            height: fixedImage.size.height * (targetSize.height / size)
        ))
        let croppedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return croppedImage ?? fixedImage
    }
    
    /// 修正圖片方向（將 EXIF 方向轉換為正確的像素方向）
    private func fixOrientation(_ image: UIImage) -> UIImage {
        // 如果方向已經正確，直接返回
        if image.imageOrientation == .up {
            return image
        }
        
        // 重新繪製圖片以修正方向
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? image
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State var image: UIImage?
        var body: some View {
            VStack(spacing: 20) {
                AvatarPickerView(selectedImage: $image)
                Text(image == nil ? "點擊選擇頭貼" : "已選擇頭貼")
                    .foregroundColor(.secondary)
            }
        }
    }
    return PreviewWrapper()
        .environmentObject(DIContainer())
}
