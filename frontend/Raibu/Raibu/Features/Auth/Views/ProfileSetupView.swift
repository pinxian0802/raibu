//
//  ProfileSetupView.swift
//  Raibu
//
//  新用戶完善個人資料頁面（設定頭貼）
//

import SwiftUI

/// 個人資料設定視圖（新用戶首次登入/註冊後顯示）
struct ProfileSetupView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var container: DIContainer
    
    @State private var avatarImage: UIImage?
    @State private var bio: String = ""
    @State private var isUploading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // 標題
            VStack(spacing: 8) {
                Text("🎉")
                    .font(.system(size: 60))
                
                Text("歡迎加入 Raibu！")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("設定你的頭貼和個人描述")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // 頭貼選擇器
            VStack(spacing: 12) {
                AvatarPickerView(selectedImage: $avatarImage, size: 150)
                
                Text("點擊選擇頭貼")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 個人描述輸入框
            VStack(alignment: .leading, spacing: 8) {
                Text("個人描述")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                TextField("介紹一下自己吧...", text: $bio, axis: .vertical)
                    .lineLimit(3...5)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 32)
            }
            .padding(.horizontal, 32)
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // 按鈕區
            VStack(spacing: 12) {
                // 確認按鈕
                Button(action: uploadAndContinue) {
                    if isUploading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("確認")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(avatarImage != nil ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(avatarImage == nil || isUploading)
                
                // 跳過按鈕
                Button(action: skip) {
                    Text("稍後設定")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .disabled(isUploading)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Actions
    
    private func uploadAndContinue() {
        guard let image = avatarImage else { return }
        
        isUploading = true
        errorMessage = nil
        
        Task {
            do {
                // Step 1: 請求 avatar 上傳憑證
                let credential = try await requestAvatarUploadCredential()
                
                // Step 2: 上傳頭貼到 R2
                try await uploadAvatarToR2(image: image, credential: credential)
                
                // Step 3: 更新 user profile（包含頭貼和描述）
                try await updateUserProfile(avatarUrl: credential.publicUrl, bio: bio.isEmpty ? nil : bio)
                
                // Step 4: 完成，進入 App
                await MainActor.run {
                    isUploading = false
                    authService.completeProfileSetup()
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    errorMessage = "上傳失敗：\(error.localizedDescription)"
                }
            }
        }
    }
    
    private func skip() {
        authService.skipProfileSetup()
    }
    
    // MARK: - API Calls
    
    private func requestAvatarUploadCredential() async throws -> AvatarUploadCredential {
        return try await container.apiClient.post(
            .uploadAvatar,
            body: AvatarUploadRequest(fileType: "image/jpeg")
        )
    }
    
    private func uploadAvatarToR2(image: UIImage, credential: AvatarUploadCredential) async throws {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ProfileSetupError.imageConversionFailed
        }
        
        guard let uploadUrl = URL(string: credential.uploadUrl) else {
            throw ProfileSetupError.invalidUrl
        }
        
        try await container.apiClient.uploadToPresignedURL(
            data: imageData,
            url: uploadUrl,
            contentType: "image/jpeg"
        )
    }
    
    private func updateUserProfile(avatarUrl: String, bio: String?) async throws {
        let requestBody = UpdateUserRequest(avatarUrl: avatarUrl, bio: bio)
        let _: UpdateUserResponse = try await container.apiClient.patch(
            .updateMe,
            body: requestBody
        )
    }
}

// MARK: - Models

struct AvatarUploadRequest: Encodable {
    let fileType: String
    
    enum CodingKeys: String, CodingKey {
        case fileType = "file_type"
    }
}

struct AvatarUploadCredential: Decodable {
    let uploadId: String
    let uploadUrl: String
    let publicUrl: String
    
    enum CodingKeys: String, CodingKey {
        case uploadId = "upload_id"
        case uploadUrl = "upload_url"
        case publicUrl = "public_url"
    }
}

struct UpdateUserRequest: Encodable {
    let avatarUrl: String
    let bio: String?
    
    enum CodingKeys: String, CodingKey {
        case avatarUrl = "avatar_url"
        case bio
    }
}

struct UpdateUserResponse: Decodable {
    let success: Bool
}

// MARK: - Errors

enum ProfileSetupError: LocalizedError {
    case imageConversionFailed
    case invalidUrl
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "圖片轉換失敗"
        case .invalidUrl:
            return "無效的上傳 URL"
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileSetupView()
        .environmentObject(AuthService())
        .environmentObject(DIContainer())
}
