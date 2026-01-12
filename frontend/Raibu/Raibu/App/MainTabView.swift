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
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(DIContainer())
        .environmentObject(NavigationCoordinator())
        .environmentObject(AuthService())
}
