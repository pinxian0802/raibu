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
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var detailSheetRouter: DetailSheetRouter
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
                await handleAuthenticatedEntryIfNeeded()
                await syncCurrentUserProfileIfNeeded()
            }
        }
        .onReceive(authService.$authState) { state in
            Task {
                switch state {
                case .authenticated:
                    await handleAuthenticatedEntryIfNeeded()
                    await syncCurrentUserProfileIfNeeded()
                case .unauthenticated:
                    navigationCoordinator.resetToMapHome()
                    detailSheetRouter.dismiss()
                default:
                    break
                }
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
        } catch APIError.accountBanned(let message) {
            await MainActor.run {
                authService.showBanNotice(message: message)
            }
        } catch {
            #if DEBUG
            print("⚠️ syncCurrentUserProfileIfNeeded failed: \(error.localizedDescription)")
            #endif
        }
    }

    @MainActor
    private func handleAuthenticatedEntryIfNeeded() async {
        guard authService.isAuthenticated else { return }
        navigationCoordinator.resetToMapHome()
        detailSheetRouter.dismiss()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(DIContainer())
        .environmentObject(AuthService())
        .environmentObject(LocationManager())
}
