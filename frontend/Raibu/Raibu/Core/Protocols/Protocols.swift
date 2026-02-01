//
//  Protocols.swift
//  Raibu
//
//  Created on 2026/02/01.
//

import Foundation
import CoreLocation
import MapKit
import Photos

// MARK: - Repository Protocols

/// 紀錄 Repository 協議
protocol RecordRepositoryProtocol {
    func createRecord(description: String, images: [UploadedImage]) async throws -> Record
    func getMapRecords(minLat: Double, maxLat: Double, minLng: Double, maxLng: Double) async throws -> [MapRecordImage]
    func getRecordDetail(id: String) async throws -> Record
    func updateRecord(id: String, description: String?, sortedImages: [SortedImageItem]) async throws -> Record
    func deleteRecord(id: String) async throws
}

/// 詢問 Repository 協議
protocol AskRepositoryProtocol {
    func createAsk(center: Coordinate, radiusMeters: Int, question: String, images: [UploadedImage]?) async throws -> Ask
    func getMapAsks(minLat: Double, maxLat: Double, minLng: Double, maxLng: Double) async throws -> [MapAsk]
    func getAskDetail(id: String) async throws -> Ask
    func updateAsk(id: String, question: String?, status: AskStatus?, sortedImages: [SortedImageItem]?) async throws
    func deleteAsk(id: String) async throws
}

/// 回覆 Repository 協議
protocol ReplyRepositoryProtocol {
    func createReply(recordId: String?, askId: String?, content: String, images: [UploadedImage]?) async throws -> Reply
    func createReplyForRecord(recordId: String, content: String, images: [UploadedImage]?) async throws -> Reply
    func createReplyForAsk(askId: String, content: String, images: [UploadedImage]?, currentLocation: Coordinate?) async throws -> Reply
    func getRepliesForRecord(recordId: String) async throws -> [Reply]
    func getRepliesForAsk(askId: String) async throws -> [Reply]
    func deleteReply(id: String) async throws
}

/// 使用者 Repository 協議
protocol UserRepositoryProtocol {
    func getUserProfile(id: String) async throws -> User
    func updateProfile(displayName: String?, avatarUrl: String?) async throws -> User
    func getUserRecords(userId: String, page: Int, limit: Int) async throws -> [Record]
    func getUserAsks(userId: String, page: Int, limit: Int) async throws -> [Ask]
}

// MARK: - Service Protocols

/// 認證服務協議
protocol AuthServiceProtocol: AnyObject {
    var authState: AuthState { get }
    var currentUser: User? { get }
    var currentUserId: String? { get }
    var isAuthenticated: Bool { get }
    
    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String, displayName: String) async throws
    func signOut() async throws
    func verifyOTP(email: String, token: String) async throws
    func getAuthorizationHeaders() -> [String: String]?
    func refreshTokenIfNeeded() async throws -> Bool
}

/// 上傳服務協議
protocol UploadServiceProtocol {
    func requestUploadCredentials(images: [ImageUploadRequest]) async throws -> [String: UploadCredential]
    func uploadImage(data: Data, to url: URL, contentType: String) async throws
}

/// 位置服務協議
protocol LocationServiceProtocol: AnyObject {
    var currentLocation: CLLocationCoordinate2D? { get }
    var authorizationStatus: CLAuthorizationStatus { get }
    
    func requestAuthorization()
    func startUpdating()
    func stopUpdating()
}

/// 相簿服務協議
protocol PhotoPickerServiceProtocol {
    func requestAuthorization() async -> Bool
}

/// 群集服務協議
protocol ClusteringServiceProtocol {
    func clusterImages(_ images: [MapRecordImage], in region: MKCoordinateRegion, mapSize: CGSize) -> [ClusterResult]
}
