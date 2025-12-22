//
//  APIEndpoint.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation

/// API 端點定義
enum APIEndpoint {
    // MARK: - 上傳模組 (Module A)
    case uploadRequest
    
    // MARK: - 紀錄模組 (Module B)
    case createRecord
    case getMapRecords(minLat: Double, maxLat: Double, minLng: Double, maxLng: Double)
    case getRecordDetail(id: String)
    case updateRecord(id: String)
    case deleteRecord(id: String)
    
    // MARK: - 詢問模組 (Module C)
    case createAsk
    case getMapAsks(minLat: Double, maxLat: Double, minLng: Double, maxLng: Double)
    case getAskDetail(id: String)
    case updateAsk(id: String)
    case deleteAsk(id: String)
    
    // MARK: - 回覆模組 (Module D)
    case createReply
    case getReplies(recordId: String?, askId: String?)
    case toggleLike
    
    // MARK: - 使用者模組 (Module E)
    case getMe
    case getMyRecords
    case getMyAsks
    
    /// 產生完整 URL
    func url(baseURL: String) throws -> URL {
        let path = self.path
        var urlString = "\(baseURL)\(path)"
        
        // 加入 Query Parameters
        if let queryItems = self.queryItems, !queryItems.isEmpty {
            var components = URLComponents(string: urlString)
            components?.queryItems = queryItems
            urlString = components?.string ?? urlString
        }
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        return url
    }
    
    // MARK: - Private Properties
    
    private var path: String {
        switch self {
        // 上傳
        case .uploadRequest:
            return "/upload/request"
            
        // 紀錄
        case .createRecord:
            return "/records"
        case .getMapRecords:
            return "/records/map"
        case .getRecordDetail(let id):
            return "/records/\(id)"
        case .updateRecord(let id):
            return "/records/\(id)"
        case .deleteRecord(let id):
            return "/records/\(id)"
            
        // 詢問
        case .createAsk:
            return "/asks"
        case .getMapAsks:
            return "/asks/map"
        case .getAskDetail(let id):
            return "/asks/\(id)"
        case .updateAsk(let id):
            return "/asks/\(id)"
        case .deleteAsk(let id):
            return "/asks/\(id)"
            
        // 回覆
        case .createReply:
            return "/replies"
        case .getReplies:
            return "/replies"
        case .toggleLike:
            return "/likes"
            
        // 使用者
        case .getMe:
            return "/users/me"
        case .getMyRecords:
            return "/users/me/records"
        case .getMyAsks:
            return "/users/me/asks"
        }
    }
    
    private var queryItems: [URLQueryItem]? {
        switch self {
        case .getMapRecords(let minLat, let maxLat, let minLng, let maxLng):
            return [
                URLQueryItem(name: "min_lat", value: String(minLat)),
                URLQueryItem(name: "max_lat", value: String(maxLat)),
                URLQueryItem(name: "min_lng", value: String(minLng)),
                URLQueryItem(name: "max_lng", value: String(maxLng))
            ]
            
        case .getMapAsks(let minLat, let maxLat, let minLng, let maxLng):
            return [
                URLQueryItem(name: "min_lat", value: String(minLat)),
                URLQueryItem(name: "max_lat", value: String(maxLat)),
                URLQueryItem(name: "min_lng", value: String(minLng)),
                URLQueryItem(name: "max_lng", value: String(maxLng))
            ]
            
        case .getReplies(let recordId, let askId):
            if let recordId = recordId {
                return [URLQueryItem(name: "record_id", value: recordId)]
            } else if let askId = askId {
                return [URLQueryItem(name: "ask_id", value: askId)]
            }
            return nil
            
        default:
            return nil
        }
    }
}
