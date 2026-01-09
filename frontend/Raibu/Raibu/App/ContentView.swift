//
//  ContentView.swift
//  Raibu
//
//  Root navigation view based on authentication state
//

import SwiftUI

/// 根導航視圖 - 根據 AuthState 顯示對應頁面
struct ContentView: View {
    @EnvironmentObject var container: DIContainer
    @EnvironmentObject var authService: AuthService
    @Environment(\.scenePhase) var scenePhase
    
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
        .onChange(of: scenePhase) { _, newPhase in
            // App 回到前景時檢查並刷新 Token
            if newPhase == .active {
                Task {
                    await authService.checkAuthStatus()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(DIContainer())
        .environmentObject(AuthService())
        .environmentObject(LocationManager())
}
