//
//  MainTabView.swift
//  Raibu
//
//  Main tab navigation (Map, Create, Profile)
//

import SwiftUI

/// 主 Tab 導航視圖
struct MainTabView: View {
    @EnvironmentObject var container: DIContainer
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var showCreateRecord = false
    @State private var previousTab: Int = 0
    
    // 保持頁面狀態的標記
    @State private var hasLoadedMap = false
    @State private var hasLoadedProfile = false
    
    var body: some View {
        ZStack {
            // 使用 ZStack + opacity 保持頁面狀態，避免切換時重新載入
            MapContainerView()
                .opacity(navigationCoordinator.selectedTab == 0 ? 1 : 0)
                .zIndex(navigationCoordinator.selectedTab == 0 ? 1 : 0)
                .onAppear {
                    hasLoadedMap = true
                }
            
            if hasLoadedProfile || navigationCoordinator.selectedTab == 2 {
                ProfileView()
                    .opacity(navigationCoordinator.selectedTab == 2 ? 1 : 0)
                    .zIndex(navigationCoordinator.selectedTab == 2 ? 1 : 0)
                    .onAppear {
                        hasLoadedProfile = true
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: navigationCoordinator.selectedTab)
        .overlay(alignment: .bottom) {
            // 自定義 Tab Bar
            CustomTabBar(
                selectedTab: Binding(
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
                ),
                onCreateTapped: {
                    showCreateRecord = true
                }
            )
        }
        .sheet(isPresented: $showCreateRecord) {
            CreateRecordFullView(
                uploadService: container.uploadService,
                recordRepository: container.recordRepository
            )
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(DIContainer())
        .environmentObject(NavigationCoordinator())
        .environmentObject(AuthService())
}
