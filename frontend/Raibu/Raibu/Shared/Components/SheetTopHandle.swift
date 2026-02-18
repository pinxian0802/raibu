//
//  SheetTopHandle.swift
//  Raibu
//
//  Created on 2026/02/18.
//

import SwiftUI

/// Bottom sheet 頂部拖曳指示條（與新增紀錄樣式一致）
struct SheetTopHandle: View {
    var topPadding: CGFloat = 10
    var bottomPadding: CGFloat = 14

    var body: some View {
        Capsule()
            .fill(Color(.systemGray5))
            .frame(width: 58, height: 7)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
    }
}

