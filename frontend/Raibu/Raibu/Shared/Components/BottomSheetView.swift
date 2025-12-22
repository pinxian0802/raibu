//
//  BottomSheetView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI

/// 3/4 高度 Bottom Sheet
struct BottomSheetView<Content: View>: View {
    @Binding var isPresented: Bool
    let content: Content
    let onDismiss: (() -> Void)?
    
    @State private var offset: CGFloat = 0
    @GestureState private var isDragging = false
    
    private let height: CGFloat = UIScreen.main.bounds.height * 0.75
    private let dismissThreshold: CGFloat = 100
    
    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content, onDismiss: (() -> Void)? = nil) {
        self._isPresented = isPresented
        self.content = content()
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 背景遮罩
                if isPresented {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            dismiss()
                        }
                        .transition(.opacity)
                }
                
                // Bottom Sheet 內容
                VStack(spacing: 0) {
                    // 拖動控制條 (Handle)
                    handleView
                    
                    // 內容
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: height)
                .background(Color(.systemBackground))
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: -5)
                .offset(y: isPresented ? offset : height)
                .gesture(dragGesture)
                .animation(.spring(response: 0.3), value: isPresented)
                .animation(.spring(response: 0.3), value: offset)
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Subviews
    
    private var handleView: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
    
    // MARK: - Gestures
    
    private var dragGesture: some Gesture {
        DragGesture()
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .onChanged { value in
                let translation = value.translation.height
                if translation > 0 {
                    offset = translation
                }
            }
            .onEnded { value in
                if value.translation.height > dismissThreshold {
                    dismiss()
                } else {
                    offset = 0
                }
            }
    }
    
    // MARK: - Actions
    
    private func dismiss() {
        withAnimation {
            isPresented = false
            offset = 0
        }
        onDismiss?()
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isPresented = true
        
        var body: some View {
            ZStack {
                Color.gray.opacity(0.3)
                    .ignoresSafeArea()
                
                Button("Show Sheet") {
                    isPresented = true
                }
                
                BottomSheetView(isPresented: $isPresented) {
                    VStack {
                        Text("這是 Bottom Sheet 內容")
                            .font(.title2)
                            .padding()
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    return PreviewWrapper()
}
