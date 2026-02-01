//
//  MockRepositories.swift
//  RaibuTests
//
//  Created for testing purposes
//

import Foundation
@testable import raibu

// MARK: - Mock Record Repository

class MockRecordRepository: RecordRepositoryProtocol {
    
    // 控制 Mock 行為的屬性
    var mockRecords: [Record] = []
    var mockMapRecords: [MapRecordImage] = []
    var shouldThrowError: Bool = false
    var errorToThrow: Error = APIError.internalError
    
    // 追蹤方法調用
    var createRecordCalled = false
    var getMapRecordsCalled = false
    var getRecordDetailCalled = false
    var updateRecordCalled = false
    var deleteRecordCalled = false
    
    var lastCreateDescription: String?
    var lastCreateImages: [UploadedImage]?
    var lastRecordId: String?
    
    func createRecord(description: String, images: [UploadedImage]) async throws -> Record {
        createRecordCalled = true
        lastCreateDescription = description
        lastCreateImages = images
        
        if shouldThrowError { throw errorToThrow }
        
        return mockRecords.first ?? Record(
            id: UUID().uuidString,
            userId: "mock-user-id",
            description: description,
            mainImageUrl: nil,
            mediaCount: images.count,
            likeCount: 0,
            viewCount: 0,
            createdAt: Date(),
            updatedAt: nil
        )
    }
    
    func getMapRecords(minLat: Double, maxLat: Double, minLng: Double, maxLng: Double) async throws -> [MapRecordImage] {
        getMapRecordsCalled = true
        
        if shouldThrowError { throw errorToThrow }
        
        return mockMapRecords
    }
    
    func getRecordDetail(id: String) async throws -> Record {
        getRecordDetailCalled = true
        lastRecordId = id
        
        if shouldThrowError { throw errorToThrow }
        
        return mockRecords.first(where: { $0.id == id }) ?? mockRecords.first ?? Record(
            id: id,
            userId: "mock-user-id",
            description: "Mock record",
            mainImageUrl: nil,
            mediaCount: 1,
            likeCount: 0,
            viewCount: 0,
            createdAt: Date(),
            updatedAt: nil
        )
    }
    
    func updateRecord(id: String, description: String?, sortedImages: [SortedImageItem]) async throws -> Record {
        updateRecordCalled = true
        lastRecordId = id
        
        if shouldThrowError { throw errorToThrow }
        
        return mockRecords.first ?? Record(
            id: id,
            userId: "mock-user-id",
            description: description ?? "Updated",
            mainImageUrl: nil,
            mediaCount: sortedImages.count,
            likeCount: 0,
            viewCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func deleteRecord(id: String) async throws {
        deleteRecordCalled = true
        lastRecordId = id
        
        if shouldThrowError { throw errorToThrow }
    }
    
    func reset() {
        mockRecords = []
        mockMapRecords = []
        shouldThrowError = false
        createRecordCalled = false
        getMapRecordsCalled = false
        getRecordDetailCalled = false
        updateRecordCalled = false
        deleteRecordCalled = false
        lastCreateDescription = nil
        lastCreateImages = nil
        lastRecordId = nil
    }
}

// MARK: - Mock Ask Repository

class MockAskRepository: AskRepositoryProtocol {
    
    var mockAsks: [Ask] = []
    var mockMapAsks: [MapAsk] = []
    var shouldThrowError: Bool = false
    var errorToThrow: Error = APIError.internalError
    
    var createAskCalled = false
    var getMapAsksCalled = false
    var getAskDetailCalled = false
    var updateAskCalled = false
    var deleteAskCalled = false
    
    func createAsk(center: Coordinate, radiusMeters: Int, question: String, images: [UploadedImage]?) async throws -> Ask {
        createAskCalled = true
        
        if shouldThrowError { throw errorToThrow }
        
        return mockAsks.first ?? Ask(
            id: UUID().uuidString,
            userId: "mock-user-id",
            center: center,
            radiusMeters: radiusMeters,
            question: question,
            mainImageUrl: nil,
            status: .active,
            likeCount: 0,
            viewCount: 0,
            createdAt: Date(),
            updatedAt: nil
        )
    }
    
    func getMapAsks(minLat: Double, maxLat: Double, minLng: Double, maxLng: Double) async throws -> [MapAsk] {
        getMapAsksCalled = true
        
        if shouldThrowError { throw errorToThrow }
        
        return mockMapAsks
    }
    
    func getAskDetail(id: String) async throws -> Ask {
        getAskDetailCalled = true
        
        if shouldThrowError { throw errorToThrow }
        
        return mockAsks.first(where: { $0.id == id }) ?? mockAsks.first ?? Ask(
            id: id,
            userId: "mock-user-id",
            center: Coordinate(lat: 25.033, lng: 121.565),
            radiusMeters: 500,
            question: "Mock question",
            mainImageUrl: nil,
            status: .active,
            likeCount: 0,
            viewCount: 0,
            createdAt: Date(),
            updatedAt: nil
        )
    }
    
    func updateAsk(id: String, question: String?, status: AskStatus?, sortedImages: [SortedImageItem]?) async throws {
        updateAskCalled = true
        
        if shouldThrowError { throw errorToThrow }
    }
    
    func deleteAsk(id: String) async throws {
        deleteAskCalled = true
        
        if shouldThrowError { throw errorToThrow }
    }
    
    func reset() {
        mockAsks = []
        mockMapAsks = []
        shouldThrowError = false
        createAskCalled = false
        getMapAsksCalled = false
        getAskDetailCalled = false
        updateAskCalled = false
        deleteAskCalled = false
    }
}

// MARK: - Mock Reply Repository

class MockReplyRepository: ReplyRepositoryProtocol {
    
    var mockReplies: [Reply] = []
    var shouldThrowError: Bool = false
    var errorToThrow: Error = APIError.internalError
    
    var createReplyCalled = false
    var createReplyForRecordCalled = false
    var createReplyForAskCalled = false
    var getRepliesForRecordCalled = false
    var getRepliesForAskCalled = false
    var deleteReplyCalled = false
    
    func createReply(recordId: String?, askId: String?, content: String, images: [UploadedImage]?) async throws -> Reply {
        createReplyCalled = true
        
        if shouldThrowError { throw errorToThrow }
        
        return Reply(
            id: UUID().uuidString,
            recordId: recordId,
            askId: askId,
            userId: "mock-user-id",
            content: content,
            isOnsite: nil,
            likeCount: 0,
            createdAt: Date(),
            author: nil,
            images: nil,
            userHasLiked: false
        )
    }
    
    func createReplyForRecord(recordId: String, content: String, images: [UploadedImage]?) async throws -> Reply {
        createReplyForRecordCalled = true
        
        if shouldThrowError { throw errorToThrow }
        
        return Reply(
            id: UUID().uuidString,
            recordId: recordId,
            askId: nil,
            userId: "mock-user-id",
            content: content,
            isOnsite: nil,
            likeCount: 0,
            createdAt: Date(),
            author: nil,
            images: nil,
            userHasLiked: false
        )
    }
    
    func createReplyForAsk(askId: String, content: String, images: [UploadedImage]?, currentLocation: Coordinate?) async throws -> Reply {
        createReplyForAskCalled = true
        
        if shouldThrowError { throw errorToThrow }
        
        return Reply(
            id: UUID().uuidString,
            recordId: nil,
            askId: askId,
            userId: "mock-user-id",
            content: content,
            isOnsite: currentLocation != nil,
            likeCount: 0,
            createdAt: Date(),
            author: nil,
            images: nil,
            userHasLiked: false
        )
    }
    
    func getRepliesForRecord(recordId: String) async throws -> [Reply] {
        getRepliesForRecordCalled = true
        
        if shouldThrowError { throw errorToThrow }
        
        return mockReplies.filter { $0.recordId == recordId }
    }
    
    func getRepliesForAsk(askId: String) async throws -> [Reply] {
        getRepliesForAskCalled = true
        
        if shouldThrowError { throw errorToThrow }
        
        return mockReplies.filter { $0.askId == askId }
    }
    
    func deleteReply(id: String) async throws {
        deleteReplyCalled = true
        
        if shouldThrowError { throw errorToThrow }
    }
    
    func reset() {
        mockReplies = []
        shouldThrowError = false
        createReplyForRecordCalled = false
        createReplyForAskCalled = false
        getRepliesForRecordCalled = false
        getRepliesForAskCalled = false
        deleteReplyCalled = false
    }
}

// MARK: - Mock User Repository

class MockUserRepository: UserRepositoryProtocol {
    
    var mockUser: User?
    var mockRecords: [Record] = []
    var mockAsks: [Ask] = []
    var shouldThrowError: Bool = false
    var errorToThrow: Error = APIError.internalError
    
    func getUserProfile(id: String) async throws -> User {
        if shouldThrowError { throw errorToThrow }
        
        return mockUser ?? User(
            id: id,
            displayName: "Mock User",
            avatarUrl: nil,
            totalViews: 0,
            createdAt: Date()
        )
    }
    
    func updateProfile(displayName: String?, avatarUrl: String?) async throws -> User {
        if shouldThrowError { throw errorToThrow }
        
        return User(
            id: mockUser?.id ?? "mock-id",
            displayName: displayName ?? mockUser?.displayName ?? "Mock User",
            avatarUrl: avatarUrl ?? mockUser?.avatarUrl,
            totalViews: mockUser?.totalViews ?? 0,
            createdAt: mockUser?.createdAt ?? Date()
        )
    }
    
    func getUserRecords(userId: String, page: Int, limit: Int) async throws -> [Record] {
        if shouldThrowError { throw errorToThrow }
        return mockRecords
    }
    
    func getUserAsks(userId: String, page: Int, limit: Int) async throws -> [Ask] {
        if shouldThrowError { throw errorToThrow }
        return mockAsks
    }
    
    func reset() {
        mockUser = nil
        mockRecords = []
        mockAsks = []
        shouldThrowError = false
    }
}
