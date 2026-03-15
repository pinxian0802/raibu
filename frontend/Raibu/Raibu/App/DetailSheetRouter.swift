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
    case recordEdit(id: String)
    case ask(id: String)
    case askEdit(id: String)
    case userProfile(id: String)

    var id: String {
        switch self {
        case .record(let id, let imageIndex):
            return "record-\(id)-\(imageIndex)"
        case .recordEdit(let id):
            return "record-edit-\(id)"
        case .ask(let id):
            return "ask-\(id)"
        case .askEdit(let id):
            return "ask-edit-\(id)"
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
    @Published private(set) var recordRefreshVersions: [String: Int] = [:]
    @Published private(set) var askRefreshVersions: [String: Int] = [:]
    private var recordEditPrefetchedRecords: [String: Record] = [:]
    private var askEditPrefetchedAsks: [String: Ask] = [:]

    /// 根據當前狀態決定 present 或 push
    func open(_ route: DetailSheetRoute) {
        if isPresented {
            push(route)
        } else {
            present(route)
        }
    }

    /// 開啟編輯紀錄頁，並可帶入已載入的紀錄資料以避免重複等待
    func openRecordEdit(id: String, prefetchedRecord: Record?) {
        if let prefetchedRecord {
            recordEditPrefetchedRecords[id] = prefetchedRecord
        }
        open(.recordEdit(id: id))
    }

    /// 開啟編輯詢問頁，並可帶入已載入的詢問資料以避免重複等待
    func openAskEdit(id: String, prefetchedAsk: Ask?) {
        if let prefetchedAsk {
            askEditPrefetchedAsks[id] = prefetchedAsk
        }
        open(.askEdit(id: id))
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
        recordEditPrefetchedRecords.removeAll()
        askEditPrefetchedAsks.removeAll()
    }

    /// 通知指定紀錄需要刷新（例如編輯完成後）
    func notifyRecordUpdated(recordId: String) {
        recordRefreshVersions[recordId, default: 0] += 1
    }

    /// 取得指定紀錄目前的刷新版本（供 onChange 監聽）
    func recordRefreshVersion(for recordId: String) -> Int {
        recordRefreshVersions[recordId, default: 0]
    }

    /// 通知指定詢問需要刷新（例如編輯完成後）
    func notifyAskUpdated(askId: String) {
        askRefreshVersions[askId, default: 0] += 1
    }

    /// 取得指定詢問目前的刷新版本（供 onChange 監聽）
    func askRefreshVersion(for askId: String) -> Int {
        askRefreshVersions[askId, default: 0]
    }

    /// 取得編輯前快取的紀錄資料
    func recordEditPrefetchedRecord(for recordId: String) -> Record? {
        recordEditPrefetchedRecords[recordId]
    }

    /// 取得編輯前快取的詢問資料
    func askEditPrefetchedAsk(for askId: String) -> Ask? {
        askEditPrefetchedAsks[askId]
    }
}
