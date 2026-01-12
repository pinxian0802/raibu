//
//  ProfileView.swift
//  Raibu
//
//  Profile tab entry point.
//

import SwiftUI

/// 個人頁面入口視圖
struct ProfileView: View {
    @EnvironmentObject var container: DIContainer
    
    var body: some View {
        ProfileFullView(userRepository: container.userRepository)
    }
}

#Preview {
    ProfileView()
        .environmentObject(DIContainer())
}
