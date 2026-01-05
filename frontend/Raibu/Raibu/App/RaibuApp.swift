//
//  RaibuApp.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI

@main
struct RaibuApp: App {
    @StateObject private var container = DIContainer()
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
                .environmentObject(container.authService)
                .environmentObject(container.locationManager)
                .environmentObject(navigationCoordinator)
                .onOpenURL { url in
                    // 處理 Email 驗證回調
                    handleAuthCallback(url: url)
                }
        }
    }
    
    private func handleAuthCallback(url: URL) {
        Task {
            do {
                try await container.authService.handleAuthCallback(url: url)
            } catch {
                print("Auth callback error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Content View (Root Navigation)
struct ContentView: View {
    @EnvironmentObject var container: DIContainer
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        Group {
            switch authService.authState {
            case .authenticated:
                MainTabView()
            case .awaitingEmailVerification(let email):
                EmailVerificationPendingView(email: email)
            case .awaitingPasswordReset(let email):
                PasswordResetView(email: email)
            case .unauthenticated:
                AuthContainerView()
            }
        }
        .onAppear {
            Task {
                await authService.checkAuthStatus()
            }
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @EnvironmentObject var container: DIContainer
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var showCreateRecord = false
    @State private var previousTab: Int = 0
    
    var body: some View {
        TabView(selection: Binding(
            get: { navigationCoordinator.selectedTab },
            set: { newValue in
                if newValue == 1 {
                    // 點擊「新增」Tab：不切換，直接開啟 sheet
                    showCreateRecord = true
                } else {
                    // 正常切換，並記錄為 previousTab
                    previousTab = newValue
                    navigationCoordinator.selectedTab = newValue
                }
            }
        )) {
            MapContainerView()
                .tabItem {
                    Image(systemName: "map")
                    Text("地圖")
                }
                .tag(0)
            
            // 中間佔位（只顯示 icon，不會被選中）
            Color.clear
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                }
                .tag(1)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("個人")
                }
                .tag(2)
        }
        .sheet(isPresented: $showCreateRecord) {
            CreateRecordFullView(
                uploadService: container.uploadService,
                recordRepository: container.recordRepository
            )
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            PasswordTestButton()
                .padding(.top, 50)
                .padding(.trailing, 10)
        }
        #endif
    }
}

#if DEBUG
// MARK: - Debug: 密碼更新測試按鈕
struct PasswordTestButton: View {
    @EnvironmentObject var authService: AuthService
    @State private var showTestAlert = false
    @State private var testPassword = ""
    @State private var testResult = ""
    @State private var showResultAlert = false
    
    var body: some View {
        Button(action: { showTestAlert = true }) {
            Image(systemName: "hammer.fill")
                .foregroundColor(.white)
                .padding(8)
                .background(Color.purple)
                .clipShape(Circle())
        }
        .alert("🧪 測試更新密碼 API", isPresented: $showTestAlert) {
            TextField("輸入測試密碼", text: $testPassword)
            Button("測試") {
                Task {
                    // 執行測試並獲得結果字串
                    let result = await authService.testUpdatePassword(testPassword)
                    // 更新結果狀態並顯示結果 Alert
                    await MainActor.run {
                        testResult = result
                        showResultAlert = true
                    }
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("這會直接呼叫密碼更新 API")
        }
        // 新增：顯示測試結果的 Alert
        .alert("測試結果", isPresented: $showResultAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(testResult)
        }
    }
}
#endif

// MARK: - Auth Views Container
struct AuthContainerView: View {
    @State private var showRegister = false
    
    var body: some View {
        if showRegister {
            RegisterView(showRegister: $showRegister)
        } else {
            LoginView(showRegister: $showRegister)
        }
    }
}

// MARK: - OTP Verification View
struct EmailVerificationPendingView: View {
    @EnvironmentObject var authService: AuthService
    let email: String
    @State private var otpDigits: [String] = Array(repeating: "", count: 6)
    @State private var isVerifying = false
    @State private var isResending = false
    @State private var showResendSuccess = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Int?
    
    private var otpCode: String {
        otpDigits.joined()
    }
    
    private var isValidOTP: Bool {
        otpCode.count == 6 && otpCode.allSatisfy { $0.isNumber }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 45))
                    .foregroundColor(.blue)
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
                    .foregroundColor(.blue)
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
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                // Verify Button
                Button(action: verifyOTP) {
                    if isVerifying {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("驗證")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValidOTP ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(!isValidOTP || isVerifying)
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
        .alert("已發送", isPresented: $showResendSuccess) {
            Button("確定", role: .cancel) { }
        } message: {
            Text("驗證碼已重新發送，請查收您的信箱")
        }
    }
    
    private func verifyOTP() {
        isVerifying = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.verifyOTP(email: email, token: otpCode)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    clearOTP()
                }
            }
            await MainActor.run {
                isVerifying = false
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

// MARK: - OTP Single Digit Box
struct OTPDigitBox: View {
    @Binding var digit: String
    let isFocused: Bool
    let onDigitEntered: () -> Void
    let onBackspace: () -> Void
    
    var body: some View {
        TextField("", text: $digit)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .frame(width: 48, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 2)
            )
            .onChange(of: digit) { oldValue, newValue in
                // 只保留數字
                let filtered = newValue.filter { $0.isNumber }
                
                if filtered.isEmpty && !oldValue.isEmpty {
                    // 刪除操作
                    digit = ""
                    onBackspace()
                } else if filtered.count >= 1 {
                    // 只保留最後輸入的數字
                    digit = String(filtered.suffix(1))
                    onDigitEntered()
                }
            }
    }
}

// MARK: - Login View
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

// MARK: - Forgot Password View (Email Input)
struct ForgotPasswordView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "key.fill")
                        .font(.system(size: 45))
                        .foregroundColor(.orange)
                }
                
                // Title
                VStack(spacing: 8) {
                    Text("忘記密碼")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("請輸入您註冊時使用的電子郵件")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                }
                
                // Email Input
                VStack(spacing: 16) {
                    TextField("電子郵件", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: sendResetCode) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("發送驗證碼")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(!email.isEmpty ? Color.orange : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(isLoading || email.isEmpty)
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .navigationTitle("忘記密碼")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func sendResetCode() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.sendPasswordResetOTP(email: email)
                await MainActor.run {
                    dismiss()
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

// MARK: - Password Reset View (Two-Step: OTP then New Password)
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
    
    private var otpCode: String {
        otpDigits.joined()
    }
    
    private var isValidOTP: Bool {
        otpCode.count == 6 && otpCode.allSatisfy { $0.isNumber }
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
                            .foregroundColor(.orange)
                            .font(.subheadline)
                    }
                }
                
                // Step 1: OTP Input
                if !isOTPVerified && !isResetComplete {
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
                        
                        Button(action: verifyOTP) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("驗證")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValidOTP ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(!isValidOTP || isLoading)
                    }
                    .padding(.horizontal, 32)
                }
                
                // Step 2: New Password (OTP 驗證後顯示)
                if isOTPVerified && !isResetComplete {
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
                        .background(isPasswordValid ? Color.orange : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(!isPasswordValid || isLoading)
                    }
                    .padding(.horizontal, 32)
                }
                
                // Step 3: Success (密碼重設完成)
                if isResetComplete {
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
                
                // Actions (非成功狀態時顯示)
                if !isResetComplete {
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
            }
        }
        .onAppear {
            focusedField = 0
        }
        .alert("已發送", isPresented: $showResendSuccess) {
            Button("確定", role: .cancel) { }
        } message: {
            Text("驗證碼已重新發送，請查收您的信箱")
        }
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
            return .orange
        }
    }
    
    private var iconBackgroundColor: Color {
        if isResetComplete {
            return Color.green.opacity(0.1)
        } else if isOTPVerified {
            return Color.green.opacity(0.1)
        } else {
            return Color.orange.opacity(0.1)
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
        isLoading = true
        errorMessage = nil
        
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
                }
            }
            await MainActor.run {
                isLoading = false
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

// MARK: - Register View
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

// MARK: - Previews

#Preview("Login") {
    LoginView(showRegister: .constant(false))
        .environmentObject(AuthService())
}

#Preview("Register") {
    RegisterView(showRegister: .constant(true))
        .environmentObject(AuthService())
}

#Preview("Verification Pending") {
    EmailVerificationPendingView(email: "test@example.com")
        .environmentObject(AuthService())
}

#Preview("Content") {
    ContentView()
        .environmentObject(DIContainer())
        .environmentObject(AuthService())
        .environmentObject(LocationManager())
}
