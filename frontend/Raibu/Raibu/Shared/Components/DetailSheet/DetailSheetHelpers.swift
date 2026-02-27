//
//  DetailSheetHelpers.swift
//  Raibu
//
//  共用 helper：詳情頁格式化工具
//

import Foundation

/// 詳情頁共用的格式化工具
enum DetailSheetHelpers {
    /// 格式化相對時間
    static func formatTimeAgo(_ date: Date) -> String {
        let now = Date()
        let diff = now.timeIntervalSince(date)

        if diff < 60 {
            return "Now"
        } else if diff < 3600 {
            return "\(Int(diff / 60))m ago"
        } else if diff < 86400 {
            return "\(Int(diff / 3600))h ago"
        } else {
            return "\(Int(diff / 86400))d ago"
        }
    }

    /// 格式化拍攝日期
    static func formatCapturedAt(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }

    /// 取得當前使用者頭像 URL
    static func currentUserAvatarURL(from authService: AuthService) -> String? {
        if let avatar = authService.currentUser?.avatarUrl,
           !avatar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return avatar
        }
        return nil
    }
}
