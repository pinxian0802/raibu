//
//  AuthContainerView.swift
//  Raibu
//
//  Container view managing Login/Register navigation
//

import SwiftUI

/// 認證容器視圖 - 管理 Login/Register 切換
struct AuthContainerView: View {
    @State private var showRegister = false
    
    var body: some View {
        if showRegister {
            RegisterView(showRegister: $showRegister)
        } else {
            LoginView(showRegister: $showRegister)
        }
    }
}

// MARK: - Preview

#Preview {
    AuthContainerView()
        .environmentObject(AuthService())
}
