//
//  GlobalDetailSheetHost.swift
//  Raibu
//
//  Single global bottom sheet host for detail navigation.
//

import SwiftUI

private struct GlobalDetailSheetContentTopSpacingKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var globalDetailSheetContentTopSpacing: CGFloat {
        get { self[GlobalDetailSheetContentTopSpacingKey.self] }
        set { self[GlobalDetailSheetContentTopSpacingKey.self] = newValue }
    }
}

/// 全域詳情 Sheet Host（App 內僅掛載一次）
struct GlobalDetailSheetHost: ViewModifier {
    @EnvironmentObject var container: DIContainer
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var detailSheetRouter: DetailSheetRouter
    private let globalSheetContentTopSpacing: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .sheet(
                isPresented: $detailSheetRouter.isPresented,
                onDismiss: {
                    detailSheetRouter.dismiss()
                }
            ) {
                if let rootRoute = detailSheetRouter.rootRoute {
                    NavigationStack(path: $detailSheetRouter.path) {
                        routeView(for: rootRoute)
                            .navigationDestination(for: DetailSheetRoute.self) { route in
                                routeView(for: route)
                            }
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    .environment(\.globalDetailSheetContentTopSpacing, globalSheetContentTopSpacing)
                } else {
                    EmptyView()
                        .onAppear {
                            detailSheetRouter.dismiss()
                        }
                }
            }
    }

    @ViewBuilder
    private func routeView(for route: DetailSheetRoute) -> some View {
        switch route {
        case .record(let recordId, let imageIndex):
            RecordDetailSheetView(
                recordId: recordId,
                initialImageIndex: imageIndex,
                recordRepository: container.recordRepository,
                replyRepository: container.replyRepository
            )
            .environmentObject(navigationCoordinator)
            .environmentObject(container)
            .environmentObject(authService)

        case .ask(let askId):
            AskDetailSheetView(
                askId: askId,
                askRepository: container.askRepository,
                replyRepository: container.replyRepository
            )
            .environmentObject(navigationCoordinator)
            .environmentObject(container)
            .environmentObject(authService)

        case .userProfile(let userId):
            OtherUserProfileContentView(
                userId: userId,
                userRepository: container.userRepository
            )
            .environmentObject(navigationCoordinator)
            .environmentObject(container)
            .environmentObject(authService)
        }
    }
}

extension View {
    func withGlobalDetailSheetHost() -> some View {
        modifier(GlobalDetailSheetHost())
    }
}
