//
//  NavigationCoordinator.swift
//  Raibu
//
//  Created on 2025/12/23.
//

import Foundation
import SwiftUI
import MapKit
import Combine

/// 導航協調器 - 管理跨頁籤的導航狀態
class NavigationCoordinator: ObservableObject {
    /// 當前選中的 tab
    @Published var selectedTab: Int = 0
    
    /// 當前地圖模式（供全域新增按鈕判斷要開哪種建立流程）
    @Published var currentMapMode: MapMode = .record
    
    /// 當前地圖中心點（供詢問模式從 tabbar 新增時作為預設位置）
    @Published var currentMapCenter: Coordinate = Coordinate(lat: 25.033, lng: 121.565)
    
    /// 要跳轉到的座標（當設定時，地圖會移動到此位置）
    /// 使用 Coordinate 而非 CLLocationCoordinate2D，因為需要 Equatable
    @Published var targetCoordinate: Coordinate?
    
    /// 要切換到的地圖模式（當設定時，地圖會切換到此模式）
    @Published var targetMapMode: MapMode?
    
    /// 新增詢問標點的位置（長按地圖觸發，由 MainTabView 承接 sheet）
    @Published var createAskLocation: CreateAskLocation?
    
    /// 個人頁編輯狀態（避免切頁後 Profile 視圖重建造成退出編輯）
    @Published var isProfileEditing: Bool = false
    @Published var profileEditDraftDisplayName: String = ""
    @Published var profileEditDraftBio: String = ""
    
    /// 跳轉到地圖並移動到指定座標
    /// - Parameters:
    ///   - coordinate: 目標座標
    ///   - mapMode: 要切換到的地圖模式（可選，若不指定則保持當前模式）
    func navigateToMap(coordinate: CLLocationCoordinate2D, mapMode: MapMode? = nil) {
        targetCoordinate = Coordinate(from: coordinate)
        targetMapMode = mapMode
        selectedTab = 0  // 地圖 tab
    }
    
    /// 清除跳轉目標（地圖已處理完畢後呼叫）
    func clearTarget() {
        targetCoordinate = nil
        targetMapMode = nil
    }

    /// 登入後重置到地圖首頁，避免沿用前一次登入的 tab 狀態
    func resetToMapHome() {
        selectedTab = 0
        createAskLocation = nil
        isProfileEditing = false
        clearTarget()
    }
}
