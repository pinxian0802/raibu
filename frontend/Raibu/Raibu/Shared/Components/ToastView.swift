//
//  ToastView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI
import Combine

/// Toast 類型
enum ToastType {
    case success
    case error
    case info
    case warning
    
    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        case .warning: return .orange
        }
    }
}

/// Toast 資料
struct ToastData: Identifiable, Equatable {
    let id = UUID()
    let type: ToastType
    let message: String
    var duration: Double = 2.5
    
    static func == (lhs: ToastData, rhs: ToastData) -> Bool {
        lhs.id == rhs.id
    }
}

/// Toast 視圖
struct ToastView: View {
    let toast: ToastData
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.type.iconName)
                .font(.title3)
                .foregroundColor(toast.type.iconColor)
            
            Text(toast.message)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 20)
    }
}

/// Toast 管理器
class ToastManager: ObservableObject {
    @Published var currentToast: ToastData?
    
    private var dismissTask: Task<Void, Never>?
    
    func show(_ message: String, type: ToastType = .info, duration: Double = 2.5) {
        dismissTask?.cancel()
        
        withAnimation(.spring(response: 0.3)) {
            currentToast = ToastData(type: type, message: message, duration: duration)
        }
        
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            
            if !Task.isCancelled {
                withAnimation(.spring(response: 0.3)) {
                    currentToast = nil
                }
            }
        }
    }
    
    func showSuccess(_ message: String) {
        show(message, type: .success)
    }
    
    func showError(_ message: String) {
        show(message, type: .error, duration: 3.5)
    }
    
    func showWarning(_ message: String) {
        show(message, type: .warning)
    }
    
    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.3)) {
            currentToast = nil
        }
    }
}

/// Toast 容器修飾器
struct ToastContainerModifier: ViewModifier {
    @ObservedObject var manager: ToastManager
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            VStack {
                if let toast = manager.currentToast {
                    ToastView(toast: toast)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
            }
            .padding(.top, 50)
        }
    }
}

extension View {
    func toastContainer(_ manager: ToastManager) -> some View {
        modifier(ToastContainerModifier(manager: manager))
    }
}

#Preview {
    struct PreviewWrapper: View {
        @StateObject private var toastManager = ToastManager()
        
        var body: some View {
            VStack(spacing: 20) {
                Button("成功 Toast") {
                    toastManager.showSuccess("操作成功！")
                }
                
                Button("錯誤 Toast") {
                    toastManager.showError("發生錯誤，請重試")
                }
                
                Button("警告 Toast") {
                    toastManager.showWarning("已達 10 張上限")
                }
                
                Button("資訊 Toast") {
                    toastManager.show("這是一則資訊", type: .info)
                }
            }
            .toastContainer(toastManager)
        }
    }
    
    return PreviewWrapper()
}
