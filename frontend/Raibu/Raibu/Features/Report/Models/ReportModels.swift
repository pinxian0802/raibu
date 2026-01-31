//
//  ReportModels.swift
//  raibu
//
//  Created on 2026/01/27.
//

import Foundation

// MARK: - 檢舉類別

/// 檢舉原因類別
enum ReportCategory: String, CaseIterable, Identifiable {
    case spam = "SPAM"
    case inappropriate = "INAPPROPRIATE"
    case harassment = "HARASSMENT"
    case falseInfo = "FALSE_INFO"
    case other = "OTHER"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .spam: return "垃圾訊息 / 廣告"
        case .inappropriate: return "不當內容"
        case .harassment: return "騷擾或霸凌"
        case .falseInfo: return "不實資訊"
        case .other: return "其他"
        }
    }
    
    var description: String {
        switch self {
        case .spam: return "商業廣告、重複發送的內容"
        case .inappropriate: return "不雅圖片、暴力或色情內容"
        case .harassment: return "針對個人的攻擊或騷擾行為"
        case .falseInfo: return "誤導性或不實的資訊"
        case .other: return "其他違規行為"
        }
    }
}

// MARK: - 檢舉目標類型

/// 檢舉目標類型
enum ReportTargetType {
    case record(id: String)
    case ask(id: String)
    case reply(id: String)
    
    var recordId: String? {
        if case .record(let id) = self { return id }
        return nil
    }
    
    var askId: String? {
        if case .ask(let id) = self { return id }
        return nil
    }
    
    var replyId: String? {
        if case .reply(let id) = self { return id }
        return nil
    }
}

// MARK: - API 請求/回應模型

/// 建立檢舉請求
struct CreateReportRequest: Codable {
    let recordId: String?
    let askId: String?
    let replyId: String?
    let reasonCategory: String
    let reason: String
    
    enum CodingKeys: String, CodingKey {
        case recordId = "record_id"
        case askId = "ask_id"
        case replyId = "reply_id"
        case reasonCategory = "reason_category"
        case reason
    }
}

/// 建立檢舉回應
struct CreateReportResponse: Codable {
    let success: Bool
    let id: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case success
        case id
        case createdAt = "created_at"
    }
}

/// 檢查檢舉回應
struct CheckReportResponse: Codable {
    let hasReported: Bool
    let reportId: String?
    
    enum CodingKeys: String, CodingKey {
        case hasReported = "has_reported"
        case reportId = "report_id"
    }
}

/// 刪除檢舉回應
struct DeleteReportResponse: Codable {
    let success: Bool
    let message: String
}
