//
//  ClusterAnnotation.swift
//  Raibu
//
//  Created for MapContainerView refactoring.
//

import MapKit

/// 群集標註類別
/// 用於在 MKMapView 上顯示群集標點
class ClusterAnnotation: NSObject, MKAnnotation {
    let cluster: ClusterResult
    let mode: MapMode
    let clusterIdentifier: String
    
    var coordinate: CLLocationCoordinate2D {
        cluster.center
    }
    
    init(cluster: ClusterResult, mode: MapMode, identifier: String) {
        self.cluster = cluster
        self.mode = mode
        self.clusterIdentifier = identifier
    }
}
