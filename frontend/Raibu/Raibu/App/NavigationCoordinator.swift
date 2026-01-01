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
    
    /// 要跳轉到的座標（當設定時，地圖會移動到此位置）
    /// 使用 Coordinate 而非 CLLocationCoordinate2D，因為需要 Equatable
    @Published var targetCoordinate: Coordinate?
    
    /// 要切換到的地圖模式（當設定時，地圖會切換到此模式）
    @Published var targetMapMode: MapMode?
    
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
}
