//
//  MainTabView.swift
//  Raibu
//
//  Main tab navigation (Map, Create, Profile)
//

import SwiftUI
import CoreLocation

/// 主 Tab 導航視圖
struct MainTabView: View {
    @EnvironmentObject var container: DIContainer
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var detailSheetRouter: DetailSheetRouter
    @State private var showCreateRecord = false
    @State private var previousTab: Int = 0
    @State private var isWaitingForUserLocationToCreateAsk = false
    
    // 保持頁面狀態的標記
    @State private var hasLoadedMap = false
    @State private var hasLoadedProfile = false
    @State private var didResolveInitialAuthenticatedTab = false

    private var effectiveSelectedTab: Int {
        if authService.isAuthenticated && !didResolveInitialAuthenticatedTab {
            return 0
        }
        return navigationCoordinator.selectedTab
    }
    
    var body: some View {
        ZStack {
            ZStack {
                // 使用 ZStack + opacity 保持頁面狀態，避免切換時重新載入
                MapContainerView()
                    .opacity(effectiveSelectedTab == 0 ? 1 : 0)
                    .zIndex(effectiveSelectedTab == 0 ? 1 : 0)
                    .onAppear {
                        hasLoadedMap = true
                    }
                
                if hasLoadedProfile || effectiveSelectedTab == 2 {
                    ProfileView()
                        .opacity(effectiveSelectedTab == 2 ? 1 : 0)
                        .zIndex(effectiveSelectedTab == 2 ? 1 : 0)
                        .onAppear {
                            hasLoadedProfile = true
                        }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: effectiveSelectedTab)
            .disabled(authService.activeBanNotice != nil)

            // 自定義 Tab Bar
            VStack {
                Spacer()
                CustomTabBar(
                    selectedTab: Binding(
                        get: { effectiveSelectedTab },
                        set: { newValue in
                            if newValue == 1 {
                                // 點擊「新增」Tab：不切換，直接開啟 sheet
                                handleCreateTapped()
                            } else {
                                // 正常切換，並記錄為 previousTab
                                previousTab = newValue
                                navigationCoordinator.selectedTab = newValue
                            }
                        }
                    ),
                    onCreateTapped: {
                        handleCreateTapped()
                    }
                )
                .allowsHitTesting(authService.activeBanNotice == nil)
            }

            if let banNotice = authService.activeBanNotice {
                bannedUserOverlay(message: banNotice.message)
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        .onAppear {
            if authService.isAuthenticated {
                navigationCoordinator.resetToMapHome()
                didResolveInitialAuthenticatedTab = true
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                navigationCoordinator.resetToMapHome()
                didResolveInitialAuthenticatedTab = true
            }
        }
        .sheet(isPresented: $showCreateRecord) {
            CreateRecordFullView(
                uploadService: container.uploadService,
                recordRepository: container.recordRepository
            )
        }
        .onReceive(container.locationManager.$currentLocation) { location in
            guard isWaitingForUserLocationToCreateAsk,
                  let coordinate = location?.coordinate else {
                return
            }
            
            isWaitingForUserLocationToCreateAsk = false
            navigationCoordinator.createAskLocation = CreateAskLocation(coordinate: coordinate)
        }
        .onReceive(container.locationManager.$locationError) { error in
            guard isWaitingForUserLocationToCreateAsk, error != nil else {
                return
            }
            isWaitingForUserLocationToCreateAsk = false
        }
        .withGlobalDetailSheetHost()
    }
    
    private func handleCreateTapped() {
        switch navigationCoordinator.currentMapMode {
        case .record:
            showCreateRecord = true
        case .ask:
            if let userCoordinate = container.locationManager.currentLocation?.coordinate {
                navigationCoordinator.createAskLocation = CreateAskLocation(coordinate: userCoordinate)
            } else {
                isWaitingForUserLocationToCreateAsk = true
                container.locationManager.requestLocation()
            }
        }
    }

    @ViewBuilder
    private func bannedUserOverlay(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { }

            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundColor(.red)

                Text("帳號已被封鎖")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button("確定") {
                    Task {
                        await authService.signOut()
                    }
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(24)
            .frame(maxWidth: 320)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(radius: 20)
            .padding(.horizontal, 24)
        }
        .ignoresSafeArea()
    }

}

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(DIContainer())
        .environmentObject(NavigationCoordinator())
        .environmentObject(AuthService())
        .environmentObject(DetailSheetRouter())
}
