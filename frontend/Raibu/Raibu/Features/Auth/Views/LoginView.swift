//
//  LoginView.swift
//  Raibu
//
//  Login screen with email/password authentication
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @Binding var showRegister: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showForgotPassword = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                // Logo
                VStack(spacing: 8) {
                    Image(systemName: "map.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)

                    Text("Raibu")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("即時影像分享")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Login Form
                VStack(spacing: 16) {
                    TextField("電子郵件", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)

                    SecureField("密碼", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)

                    // Forgot Password Link
                    HStack {
                        Spacer()
                        Button("忘記密碼？") {
                            showForgotPassword = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: login) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("登入")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                }
                .padding(.horizontal, 32)

                // Register Link
                HStack {
                    Text("還沒有帳號？")
                        .foregroundColor(.secondary)
                    Button("立即註冊") {
                        withAnimation {
                            showRegister = true
                        }
                    }
                    .fontWeight(.semibold)
                }
                .font(.subheadline)

                Spacer()
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
    }

    private func login() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authService.signIn(email: email, password: password)
            } catch AuthError.emailNotVerified {
                // Email 未驗證，引導用戶到驗證頁面
                await MainActor.run {
                    authService.authState = .awaitingEmailVerification(email: email)
                }
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
    LoginView(showRegister: .constant(false))
        .environmentObject(AuthService())
}
