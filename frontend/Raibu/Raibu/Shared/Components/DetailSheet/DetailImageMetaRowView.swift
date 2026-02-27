//
//  DetailImageMetaRowView.swift
//  Raibu
//
//  共用元件：圖片 metadata 列
//  顯示地址 + 拍攝時間 + 查看位置按鈕
//

import SwiftUI

/// 圖片下方的 metadata 列
/// 顯示目前可見圖片的地址、拍攝時間、以及查看位置按鈕
struct DetailImageMetaRowView: View {
    let image: ImageMedia
    let scrolledImageId: String?
    var onLocationTap: ((ImageMedia) -> Void)?

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                if image.location != nil {
                    if let address = image.address, !address.isEmpty {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                if let capturedAt = image.capturedAt {
                    Text(DetailSheetHelpers.formatCapturedAt(capturedAt))
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }

            Spacer()

            if image.location != nil {
                Button {
                    onLocationTap?(image)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12, weight: .medium))
                        Text("查看位置")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.2), value: scrolledImageId)
    }
}
