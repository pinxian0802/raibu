//
//  MapTimeFilter.swift
//  Raibu
//
//  地圖時間篩選器選項
//

import Foundation

/// 地圖時間篩選器
enum MapTimeFilter: Equatable {
    case today
    case week
    case month
    case threeMonths
    case specificDate(Date)
    
    /// 篩選起始時間
    var startDate: Date? {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            return calendar.startOfDay(for: now)
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now)
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now)
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: now)
        case .specificDate(let date):
            return calendar.startOfDay(for: date)
        }
    }
    
    /// 篩選結束時間（只有 specificDate 需要）
    var endDate: Date? {
        switch self {
        case .specificDate(let date):
            let calendar = Calendar.current
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
        default:
            return nil
        }
    }
    
    /// 顯示標題
    var title: String {
        switch self {
        case .today: return "今天"
        case .week: return "一週"
        case .month: return "一個月"
        case .threeMonths: return "三個月"
        case .specificDate(let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/M/d"
            return formatter.string(from: date)
        }
    }
    
    /// SF Symbol icon name
    var iconName: String {
        switch self {
        case .today: return "sun.max"
        case .week: return "calendar"
        case .month: return "calendar.badge.clock"
        case .threeMonths: return "clock.arrow.circlepath"
        case .specificDate: return "calendar.circle"
        }
    }
    
    /// 預設選項（不含 specificDate）
    static var presets: [MapTimeFilter] {
        [.today, .week, .month, .threeMonths]
    }
}
