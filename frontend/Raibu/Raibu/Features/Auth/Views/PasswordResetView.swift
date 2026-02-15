//
//  PasswordResetView.swift
//  Raibu
//
//  Two-step password reset: OTP verification then new password
//

import SwiftUI

struct PasswordResetView: View {
    @EnvironmentObject var authService: AuthService
    let email: String
    @State private var otpDigits: [String] = Array(repeating: "", count: 6)
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var isResending = false
    @State private var errorMessage: String?
    @State private var showResendSuccess = false
    @State private var isOTPVerified = false  // 追蹤 OTP 是否已驗證
    @State private var isResetComplete = false  // 追蹤密碼是否已重設完成
    @FocusState private var focusedField: Int?
    
    // OTP 重試限制
    @State private var otpAttempts = 0
    @State private var isLocked = false
    @State private var lockoutEndTime: Date?
    @State private var remainingLockSeconds = 0
    @State private var lockoutTimer: Timer?
    private let maxAttempts = 5
    private let lockoutDuration: TimeInterval = 30 // 30 秒冷卻
    
    private var otpCode: String {
        otpDigits.joined()
    }
    
    private var isValidOTP: Bool {
        otpCode.count == 6 && otpCode.allSatisfy { $0.isNumber }
    }
    
    private var canVerifyOTP: Bool {
        isValidOTP && !isLoading && !isLocked
    }
    
    private var isPasswordValid: Bool {
        let hasMinimumLength = newPassword.count >= 8
        let hasLetter = newPassword.rangeOfCharacter(from: .letters) != nil
        let hasNumber = newPassword.rangeOfCharacter(from: .decimalDigits) != nil
        let meetsRequirements = hasMinimumLength && hasLetter && hasNumber
        
        return meetsRequirements && newPassword == confirmPassword
    }
    
    private var passwordMismatch: Bool {
        !confirmPassword.isEmpty && newPassword != confirmPassword
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Icon - 根據狀態顯示不同圖示
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 45))
                        .foregroundColor(iconColor)
                }
                .padding(.top, 40)
                
                // Title - 根據狀態顯示不同標題
                VStack(spacing: 8) {
                    Text(titleText)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(subtitleText)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                    
                    if !isOTPVerified && !isResetComplete {
                        Text(email)
                            .fontWeight(.semibold)
                            .foregroundColor(.brandOrange)
                            .font(.subheadline)
                    }
                }
                
                // Step 1: OTP Input
                if !isOTPVerified && !isResetComplete {
                    otpInputSection
                }
                
                // Step 2: New Password (OTP 驗證後顯示)
                if isOTPVerified && !isResetComplete {
                    newPasswordSection
                }
                
                // Step 3: Success (密碼重設完成)
                if isResetComplete {
                    successSection
                }
                
                // Actions (非成功狀態時顯示)
                if !isResetComplete {
                    actionsSection
                }
            }
        }
        .onAppear {
            focusedField = 0
        }
        .onDisappear {
            // 清理 Timer 防止記憶體洩漏
            lockoutTimer?.invalidate()
            lockoutTimer = nil
        }
        .alert("已發送", isPresented: $showResendSuccess) {
            Button("確定", role: .cancel) { }
        } message: {
            Text("驗證碼已重新發送，請查收您的信箱")
        }
    }
    
    // MARK: - View Sections
    
    private var otpInputSection: some View {
        VStack(spacing: 16) {
            Text("驗證碼")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { index in
                    OTPDigitBox(
                        digit: $otpDigits[index],
                        isFocused: focusedField == index,
                        onDigitEntered: {
                            if index < 5 {
                                focusedField = index + 1
                            } else {
                                focusedField = nil
                            }
                        },
                        onBackspace: {
                            if index > 0 {
                                focusedField = index - 1
                            }
                        }
                    )
                    .focused($focusedField, equals: index)
                }
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            // 剩餘嘗試次數提示
            if otpAttempts > 0 && !isLocked {
                Text("剩餘嘗試次數：\(maxAttempts - otpAttempts)")
                    .font(.caption)
                    .foregroundColor(.brandOrange)
            }
            
            // 鎖定倒計時
            if isLocked {
                Text("請等待 \(remainingLockSeconds) 秒後再試")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            Button(action: verifyOTP) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if isLocked {
                    Text("已鎖定")
                        .fontWeight(.semibold)
                } else {
                    Text("驗證")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canVerifyOTP ? Color.brandBlue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(!canVerifyOTP)
        }
        .padding(.horizontal, 32)
    }
    
    private var newPasswordSection: some View {
        VStack(spacing: 16) {
            PasswordValidationView(
                title: "新密碼",
                placeholder: "至少 8 個字元",
                text: $newPassword
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("確認新密碼")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("再次輸入新密碼", text: $confirmPassword)
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
            }
            
            Button(action: updatePassword) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("確認重設密碼")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isPasswordValid ? Color.brandOrange : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(!isPasswordValid || isLoading)
        }
        .padding(.horizontal, 32)
    }
    
    private var successSection: some View {
        VStack(spacing: 20) {
            Text("您的密碼已成功更新！\n現在可以使用新密碼登入。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: goToLogin) {
                Text("前往登入")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal, 32)
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            if !isOTPVerified {
                Button(action: resendCode) {
                    if isResending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("重新發送驗證碼")
                        }
                    }
                }
                .font(.subheadline)
                .disabled(isResending)
            }
            
            Button("取消") {
                authService.cancelPasswordReset()
            }
            .foregroundColor(.secondary)
            .font(.subheadline)
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Computed Properties for UI State
    
    private var iconName: String {
        if isResetComplete {
            return "checkmark.circle.fill"
        } else if isOTPVerified {
            return "checkmark.shield.fill"
        } else {
            return "key.badge.fill"
        }
    }
    
    private var iconColor: Color {
        if isResetComplete {
            return .green
        } else if isOTPVerified {
            return .green
        } else {
            return .brandOrange
        }
    }
    
    private var iconBackgroundColor: Color {
        if isResetComplete {
            return Color.green.opacity(0.1)
        } else if isOTPVerified {
            return Color.green.opacity(0.1)
        } else {
            return Color.brandOrange.opacity(0.1)
        }
    }
    
    private var titleText: String {
        if isResetComplete {
            return "密碼重設成功！"
        } else if isOTPVerified {
            return "設定新密碼"
        } else {
            return "驗證身份"
        }
    }
    
    private var subtitleText: String {
        if isResetComplete {
            return "您的密碼已成功更新"
        } else if isOTPVerified {
            return "驗證碼已確認，請設定新密碼"
        } else {
            return "我們已發送 6 位數驗證碼到"
        }
    }
    
    // MARK: - Actions
    
    private func verifyOTP() {
        // 檢查是否被鎖定
        guard !isLocked else { return }
        
        isLoading = true
        errorMessage = nil
        otpAttempts += 1
        
        Task {
            do {
                try await authService.verifyPasswordResetCode(email: email, token: otpCode)
                await MainActor.run {
                    withAnimation {
                        isOTPVerified = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    clearOTP()
                    
                    // 檢查是否達到最大嘗試次數
                    if otpAttempts >= maxAttempts {
                        startLockout()
                    }
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func startLockout() {
        // 先取消舊的 Timer
        lockoutTimer?.invalidate()
        
        isLocked = true
        lockoutEndTime = Date().addingTimeInterval(lockoutDuration)
        remainingLockSeconds = Int(lockoutDuration)
        
        // 開始倒計時
        lockoutTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [self] timer in
            if let endTime = lockoutEndTime {
                let remaining = Int(endTime.timeIntervalSinceNow)
                if remaining <= 0 {
                    timer.invalidate()
                    lockoutTimer = nil
                    isLocked = false
                    otpAttempts = 0
                    remainingLockSeconds = 0
                } else {
                    remainingLockSeconds = remaining
                }
            }
        }
    }
    
    private func updatePassword() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.updatePassword(newPassword: newPassword)
                await MainActor.run {
                    withAnimation {
                        isResetComplete = true
                    }
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
    
    private func resendCode() {
        isResending = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.sendPasswordResetOTP(email: email)
                await MainActor.run {
                    showResendSuccess = true
                    clearOTP()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            await MainActor.run {
                isResending = false
            }
        }
    }
    
    private func goToLogin() {
        authService.cancelPasswordReset()
    }
    
    private func clearOTP() {
        otpDigits = Array(repeating: "", count: 6)
        focusedField = 0
    }
}

// MARK: - Preview

#Preview("OTP Step") {
    PasswordResetView(email: "test@example.com")
        .environmentObject(AuthService())
}
