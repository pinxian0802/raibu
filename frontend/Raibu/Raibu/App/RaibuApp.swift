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
    @StateObject private var detailSheetRouter = DetailSheetRouter()
    @State private var pendingDetailRoute: DetailSheetRoute?
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
                .environmentObject(container.authService)
                .environmentObject(container.locationManager)
                .environmentObject(navigationCoordinator)
                .environmentObject(detailSheetRouter)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onChange(of: container.authService.isAuthenticated) { _, isAuthenticated in
                    // 登入成功後，處理先前暫存的 deep link
                    if isAuthenticated {
                        consumePendingDetailRouteIfNeeded()
                    }
                }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        if let route = DeepLinkParser.parseDetailRoute(from: url) {
            openDetailRoute(route)
            return
        }

        handleAuthCallback(url: url)
    }

    private func openDetailRoute(_ route: DetailSheetRoute) {
        if case .authenticated = container.authService.authState {
            detailSheetRouter.present(route)
            return
        }

        // 未登入時先暫存，待 authenticated 再打開
        pendingDetailRoute = route
    }

    private func consumePendingDetailRouteIfNeeded() {
        guard let route = pendingDetailRoute else { return }
        pendingDetailRoute = nil
        detailSheetRouter.present(route)
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
