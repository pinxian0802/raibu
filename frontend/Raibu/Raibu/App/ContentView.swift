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
    @State private var isSyncingCurrentUserProfile = false
    
    var body: some View {
        Group {
            switch authService.authState {
            case .authenticated:
                MainTabView()
            case .awaitingProfileSetup:
                ProfileSetupView()
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
                await syncCurrentUserProfileIfNeeded()
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            guard isAuthenticated else { return }
            Task {
                await syncCurrentUserProfileIfNeeded()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // App 回到前景時檢查並刷新 Token
            if newPhase == .active {
                Task {
                    await authService.checkAuthStatus()
                    await syncCurrentUserProfileIfNeeded()
                }
            }
        }
    }

    @MainActor
    private func syncCurrentUserProfileIfNeeded() async {
        guard authService.isAuthenticated else { return }
        guard !authService.isCurrentUserProfileSynced else { return }
        guard !isSyncingCurrentUserProfile else { return }

        isSyncingCurrentUserProfile = true
        defer { isSyncingCurrentUserProfile = false }

        do {
            let profile = try await container.userRepository.getMe()
            authService.cacheCurrentUserProfile(profile.toUser())
        } catch {
            #if DEBUG
            print("⚠️ syncCurrentUserProfileIfNeeded failed: \(error.localizedDescription)")
            #endif
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
