//
//  RaibuApp.swift
//  Raibu
//
//  Created on 2025/12/20.
//
//  App entry point - minimized after modularization
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
