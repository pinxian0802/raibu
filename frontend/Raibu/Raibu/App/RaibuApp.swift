//
//  RaibuApp.swift
//  Raibu
//
//  Created on 2025/12/20.
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
        }
    }
}

// MARK: - Content View (Root Navigation)
struct ContentView: View {
    @EnvironmentObject var container: DIContainer
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .onAppear {
            Task {
                await authService.checkAuthStatus()
            }
        }
    }
}

// MARK: - Main Tab View
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

// MARK: - Placeholder Views
struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                // Logo
                VStack(spacing: 8) {
                    Image(systemName: "map.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Raibu")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("即時影像分享")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Login Form
                VStack(spacing: 16) {
                    TextField("電子郵件", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("密碼", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Button(action: login) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("登入")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
    }
    
    private func login() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.signIn(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DIContainer())
        .environmentObject(AuthService())
        .environmentObject(LocationManager())
}
