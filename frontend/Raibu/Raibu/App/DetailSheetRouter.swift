//
//  DetailSheetRouter.swift
//  Raibu
//
//  Global bottom sheet routing for detail flows.
//

import SwiftUI
import Combine

/// 全域詳情路由
enum DetailSheetRoute: Hashable, Identifiable {
    case record(id: String, imageIndex: Int)
    case ask(id: String)
    case userProfile(id: String)

    var id: String {
        switch self {
        case .record(let id, let imageIndex):
            return "record-\(id)-\(imageIndex)"
        case .ask(let id):
            return "ask-\(id)"
        case .userProfile(let id):
            return "user-\(id)"
        }
    }
}

/// 全域詳情 Bottom Sheet 狀態管理
class DetailSheetRouter: ObservableObject {
    @Published var isPresented = false
    @Published var rootRoute: DetailSheetRoute?
    @Published var path: [DetailSheetRoute] = []

    /// 根據當前狀態決定 present 或 push
    func open(_ route: DetailSheetRoute) {
        if isPresented {
            push(route)
        } else {
            present(route)
        }
    }

    /// 開啟新的詳情流程
    func present(_ route: DetailSheetRoute) {
        rootRoute = route
        path = []
        isPresented = true
    }

    /// 在既有詳情流程中推進下一頁
    func push(_ route: DetailSheetRoute) {
        guard isPresented, rootRoute != nil else {
            present(route)
            return
        }
        path.append(route)
    }

    /// 關閉並清空路由
    func dismiss() {
        isPresented = false
        rootRoute = nil
        path = []
    }
}
