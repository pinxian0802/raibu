//
//  EmailVerificationPendingView.swift
//  Raibu
//
//  OTP verification screen after registration
//

import SwiftUI

struct EmailVerificationPendingView: View {
    @EnvironmentObject var authService: AuthService
    let email: String
    @State private var otpDigits: [String] = Array(repeating: "", count: 6)
    @State private var isVerifying = false
    @State private var isResending = false
    @State private var showResendSuccess = false
    @State private var errorMessage: String?
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
    
    private var canVerify: Bool {
        isValidOTP && !isVerifying && !isLocked
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.brandBlue.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 45))
                    .foregroundColor(.brandBlue)
            }
            
            // Title
            VStack(spacing: 8) {
                Text("輸入驗證碼")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("我們已發送 6 位數驗證碼到")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                Text(email)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandBlue)
                    .font(.subheadline)
            }
            
            // OTP Individual Digit Boxes
            VStack(spacing: 20) {
                HStack(spacing: 10) {
                    ForEach(0..<6, id: \.self) { index in
                        OTPDigitBox(
                            digit: $otpDigits[index],
                            isFocused: focusedField == index,
                            onDigitEntered: {
                                // 自動跳到下一格
                                if index < 5 {
                                    focusedField = index + 1
                                } else {
                                    // 最後一格，收起鍵盤
                                    focusedField = nil
                                }
                            },
                            onBackspace: {
                                // 刪除時跳到前一格
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
                        .foregroundColor(.appDanger)
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
                        .foregroundColor(.appDanger)
                }
                
                // Verify Button
                Button(action: verifyOTP) {
                    if isVerifying {
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
                .background(canVerify ? Color.brandBlue : Color.appDisabled)
                .foregroundColor(.appOnPrimary)
                .cornerRadius(10)
                .disabled(!canVerify)
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            
            Spacer()
            
            // Actions
            VStack(spacing: 12) {
                // Resend Button
                Button(action: resendOTP) {
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
                .disabled(isResending)
                .font(.subheadline)
                
                // Back to Login
                Button("返回登入") {
                    authService.cancelVerificationPending()
                }
                .foregroundColor(.secondary)
                .font(.subheadline)
            }
            .padding(.bottom, 40)
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
    
    private func verifyOTP() {
        // 檢查是否被鎖定
        guard !isLocked else { return }
        
        isVerifying = true
        errorMessage = nil
        otpAttempts += 1
        
        Task {
            do {
                try await authService.verifyOTP(email: email, token: otpCode)
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
                isVerifying = false
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
    
    private func resendOTP() {
        isResending = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.resendOTP(email: email)
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
    
    private func clearOTP() {
        otpDigits = Array(repeating: "", count: 6)
        focusedField = 0
    }
}

// MARK: - Preview

#Preview {
    EmailVerificationPendingView(email: "test@example.com")
        .environmentObject(AuthService())
}
