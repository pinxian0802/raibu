//
//  RegisterView.swift
//  Raibu
//
//  Registration screen with form validation
//

import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authService: AuthService
    @Binding var showRegister: Bool
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private var isFormValid: Bool {
        !displayName.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        isValidPassword
    }
    
    private var isValidPassword: Bool {
        let hasMinimumLength = password.count >= 8
        let hasLetter = password.rangeOfCharacter(from: .letters) != nil
        let hasNumber = password.rangeOfCharacter(from: .decimalDigits) != nil
        return hasMinimumLength && hasLetter && hasNumber
    }
    
    private var passwordMismatch: Bool {
        !confirmPassword.isEmpty && password != confirmPassword
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("建立帳號")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("加入 Raibu 開始分享")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Register Form
                    VStack(spacing: 16) {
                        // Display Name
                        VStack(alignment: .leading, spacing: 4) {
                            Text("顯示名稱")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("你的暱稱", text: $displayName)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.name)
                        }
                        
                        // Email
                        VStack(alignment: .leading, spacing: 4) {
                            Text("電子郵件")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("", text: $email)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                        }
                        
                        // Password
                        PasswordValidationView(
                            title: "密碼",
                            placeholder: "請輸入密碼",
                            text: $password
                        )
                        
                        // Confirm Password
                        VStack(alignment: .leading, spacing: 4) {
                            Text("確認密碼")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            SecureField("再次輸入密碼", text: $confirmPassword)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.newPassword)
                            
                            if passwordMismatch {
                                Text("密碼不一致")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }
                        
                        // Register Button
                        Button(action: register) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("註冊")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(!isFormValid || isLoading)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 32)
                    
                    // Login Link
                    HStack {
                        Text("已經有帳號？")
                            .foregroundColor(.secondary)
                        Button("返回登入") {
                            withAnimation {
                                showRegister = false
                            }
                        }
                        .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private func register() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.signUp(
                    email: email,
                    password: password,
                    displayName: displayName
                )
                // 註冊成功後會自動切換到驗證等待畫面（由 authState 控制）
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RegisterView(showRegister: .constant(true))
        .environmentObject(AuthService())
}
