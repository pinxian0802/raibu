//
//  SearchLocationAnnotation.swift
//  Raibu
//
//  Created on 2026/01/12.
//

import MapKit

/// 搜尋位置標記模型
/// 用於傳遞搜尋結果到地圖顯示
struct SearchLocationMarker: Equatable {
    let coordinate: CLLocationCoordinate2D
    let title: String
    let subtitle: String?
    
    static func == (lhs: SearchLocationMarker, rhs: SearchLocationMarker) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.title == rhs.title
    }
}

/// 搜尋位置標註類別
/// 用於在 MKMapView 上顯示搜尋結果的標點
class SearchLocationAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    
    init(coordinate: CLLocationCoordinate2D, title: String, subtitle: String?) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        super.init()
    }
}
