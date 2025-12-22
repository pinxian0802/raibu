//
//  LocationManager.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation
import CoreLocation
import SwiftUI
import Combine

/// 定位服務管理器
class LocationManager: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: LocationError?
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    // MARK: - Public Methods
    
    /// 請求定位權限
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// 開始更新位置
    func startUpdating() {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            requestAuthorization()
            return
        }
        
        locationManager.startUpdatingLocation()
    }
    
    /// 停止更新位置
    func stopUpdating() {
        locationManager.stopUpdatingLocation()
    }
    
    /// 取得一次性位置
    func requestLocation() {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            requestAuthorization()
            return
        }
        
        locationManager.requestLocation()
    }
    
    /// 計算到目標座標的距離 (公尺)
    func distance(to coordinate: CLLocationCoordinate2D) -> Double? {
        guard let current = currentLocation else { return nil }
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return current.distance(from: target)
    }
    
    /// 檢查座標是否在指定範圍內
    func isWithinRange(coordinate: CLLocationCoordinate2D, center: CLLocationCoordinate2D, radiusMeters: Double) -> Bool {
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        return targetLocation.distance(from: centerLocation) <= radiusMeters
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            startUpdating()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        locationError = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                locationError = .permissionDenied
            case .locationUnknown:
                locationError = .locationUnknown
            default:
                locationError = .unknown(message: error.localizedDescription)
            }
        }
    }
}

// MARK: - Location Errors

enum LocationError: LocalizedError {
    case permissionDenied
    case locationUnknown
    case unknown(message: String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "請在設定中允許 Raibu 存取您的位置"
        case .locationUnknown:
            return "無法取得當前位置"
        case .unknown(let message):
            return message
        }
    }
}
