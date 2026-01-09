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
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            PasswordTestButton()
                .padding(.top, 50)
                .padding(.trailing, 10)
        }
        #endif
    }
}

#if DEBUG
// MARK: - Debug: 密碼更新測試按鈕
struct PasswordTestButton: View {
    @EnvironmentObject var authService: AuthService
    @State private var showTestAlert = false
    @State private var testPassword = ""
    @State private var testResult = ""
    @State private var showResultAlert = false
    
    var body: some View {
        Button(action: { showTestAlert = true }) {
            Image(systemName: "hammer.fill")
                .foregroundColor(.white)
                .padding(8)
                .background(Color.purple)
                .clipShape(Circle())
        }
        .alert("🧪 測試更新密碼 API", isPresented: $showTestAlert) {
            TextField("輸入測試密碼", text: $testPassword)
            Button("測試") {
                Task {
                    // 執行測試並獲得結果字串
                    let result = await authService.testUpdatePassword(testPassword)
                    // 更新結果狀態並顯示結果 Alert
                    await MainActor.run {
                        testResult = result
                        showResultAlert = true
                    }
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("這會直接呼叫密碼更新 API")
        }
        // 新增：顯示測試結果的 Alert
        .alert("測試結果", isPresented: $showResultAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(testResult)
        }
    }
}
#endif

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(DIContainer())
        .environmentObject(NavigationCoordinator())
        .environmentObject(AuthService())
}
