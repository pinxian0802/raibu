//
//  MapMode.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation

/// 地圖模式
enum MapMode: String, CaseIterable {
    case record = "紀錄"
    case ask = "詢問"
    
    var iconName: String {
        switch self {
        case .record: return "camera.fill"
        case .ask: return "questionmark.circle.fill"
        }
    }
}
