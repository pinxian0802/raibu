//
//  SelectablePhoto.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import Foundation
import Photos

/// 可選照片模型 (用於相簿選擇器)
struct SelectablePhoto: Identifiable, Equatable {
    let id: String
    let asset: PHAsset
    let hasGPS: Bool
    let creationDate: Date?
    
    static func == (lhs: SelectablePhoto, rhs: SelectablePhoto) -> Bool {
        lhs.id == rhs.id
    }
    
    init(asset: PHAsset) {
        self.id = asset.localIdentifier
        self.asset = asset
        self.hasGPS = asset.location != nil
        self.creationDate = asset.creationDate
    }
}
