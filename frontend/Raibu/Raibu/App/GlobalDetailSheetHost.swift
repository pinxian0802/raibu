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
        
        case .recordEdit(let recordId):
            RecordEditRouteView(
                recordId: recordId,
                prefetchedRecord: detailSheetRouter.recordEditPrefetchedRecord(for: recordId),
                recordRepository: container.recordRepository,
                uploadService: container.uploadService,
                onComplete: {
                    detailSheetRouter.notifyRecordUpdated(recordId: recordId)
                }
            )
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

private struct RecordEditRouteView: View {
    let recordId: String
    let prefetchedRecord: Record?
    let recordRepository: RecordRepository
    let uploadService: UploadService
    let onComplete: () -> Void

    @State private var record: Record?
    @State private var isLoading: Bool
    @State private var errorMessage: String?
    @State private var hasStartedInitialLoad = false

    init(
        recordId: String,
        prefetchedRecord: Record?,
        recordRepository: RecordRepository,
        uploadService: UploadService,
        onComplete: @escaping () -> Void
    ) {
        self.recordId = recordId
        self.prefetchedRecord = prefetchedRecord
        self.recordRepository = recordRepository
        self.uploadService = uploadService
        self.onComplete = onComplete
        _record = State(initialValue: prefetchedRecord)
        _isLoading = State(initialValue: prefetchedRecord == nil)
    }

    var body: some View {
        Group {
            if let record {
                EditRecordView(
                    recordId: recordId,
                    record: record,
                    uploadService: uploadService,
                    recordRepository: recordRepository,
                    onComplete: onComplete
                )
            } else if isLoading {
                VStack(spacing: 0) {
                    SheetTopHandle()
                    RecordDetailSkeleton()
                }
                .background(Color.appSurface)
            } else {
                VStack(spacing: 16) {
                    SheetTopHandle()
                    Spacer()

                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)

                    Text(errorMessage ?? "載入失敗")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("重試") {
                        Task {
                            await loadRecord()
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
        }
        .task {
            guard !hasStartedInitialLoad else { return }
            hasStartedInitialLoad = true
            guard record == nil else { return }
            await loadRecord()
        }
    }

    @MainActor
    private func loadRecord() async {
        isLoading = true
        errorMessage = nil

        do {
            record = try await recordRepository.getRecordDetail(id: recordId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
