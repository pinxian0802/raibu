//
//  HorizontalImageEditor.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI
import Photos
import Kingfisher

/// 編輯頁面圖片項目
struct EditableImageItem: Identifiable, Equatable {
    let id: String
    let type: ItemType
    
    // 既有圖片資訊
    var imageMedia: ImageMedia?
    
    // 新增圖片資訊
    var selectedPhoto: SelectedPhoto?
    
    // 縮圖 (用於顯示)
    var thumbnailURL: String? {
        imageMedia?.thumbnailPublicUrl
    }
    
    enum ItemType {
        case existing
        case new
    }
    
    static func existing(_ media: ImageMedia) -> EditableImageItem {
        EditableImageItem(id: media.id, type: .existing, imageMedia: media)
    }
    
    static func new(_ photo: SelectedPhoto) -> EditableImageItem {
        EditableImageItem(id: photo.id, type: .new, selectedPhoto: photo)
    }
}

/// 橫向圖片編輯器
struct HorizontalImageEditor: View {
    @Binding var items: [EditableImageItem]
    let maxCount: Int
    let onAddPhotos: () -> Void
    let onReplacePhoto: (Int) -> Void
    
    @State private var draggedItem: EditableImageItem?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 圖片項目
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    imageItemView(item: item, index: index)
                        .onDrag {
                            draggedItem = item
                            return NSItemProvider(object: item.id as NSString)
                        }
                        .onDrop(
                            of: [.text],
                            delegate: ImageDropDelegate(
                                item: item,
                                items: $items,
                                draggedItem: $draggedItem
                            )
                        )
                }
                
                // 新增按鈕
                if items.count < maxCount {
                    addButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Image Item View
    
    private func imageItemView(item: EditableImageItem, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            // 圖片縮圖
            imageView(for: item)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .onTapGesture {
                    // 點擊更換圖片
                    onReplacePhoto(index)
                }
            
            // 刪除按鈕
            Button {
                withAnimation {
                    _ = items.remove(at: index)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 20, height: 20)
                    )
            }
            .offset(x: 6, y: -6)
            
            // 順序編號
            Text("\(index + 1)")
                .font(.caption2.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.brandBlue))
                .position(x: 16, y: 70)
        }
    }
    
    @ViewBuilder
    private func imageView(for item: EditableImageItem) -> some View {
        switch item.type {
        case .existing:
            if let url = item.thumbnailURL {
                KFImage(URL(string: url))
                    .placeholder {
                        placeholderView
                    }
                    .retry(maxCount: 2, interval: .seconds(1))
                    .cacheOriginalImage()
                    .fade(duration: 0.2)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholderView
            }
            
        case .new:
            if let photo = item.selectedPhoto {
                Image(uiImage: UIImage(data: photo.thumbnailData) ?? UIImage())
                    .resizable()
                    .scaledToFill()
            } else {
                placeholderView
            }
        }
    }
    
    private var placeholderView: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
            )
    }
    
    // MARK: - Add Button
    
    private var addButton: some View {
        Button(action: onAddPhotos) {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.title3)
                Text("新增")
                    .font(.caption)
            }
            .foregroundColor(.brandBlue)
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.brandBlue, style: StrokeStyle(lineWidth: 2, dash: [6]))
            )
        }
    }
}

// MARK: - Drop Delegate

struct ImageDropDelegate: DropDelegate {
    let item: EditableImageItem
    @Binding var items: [EditableImageItem]
    @Binding var draggedItem: EditableImageItem?
    
    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem,
              draggedItem != item,
              let fromIndex = items.firstIndex(of: draggedItem),
              let toIndex = items.firstIndex(of: item) else {
            return
        }
        
        withAnimation(.spring(response: 0.3)) {
            items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var items: [EditableImageItem] = [
            .existing(ImageMedia(
                id: "1",
                originalPublicUrl: "https://picsum.photos/200",
                thumbnailPublicUrl: "https://picsum.photos/100",
                location: nil,
                capturedAt: nil,
                displayOrder: 0,
                address: nil
            )),
            .existing(ImageMedia(
                id: "2",
                originalPublicUrl: "https://picsum.photos/201",
                thumbnailPublicUrl: "https://picsum.photos/101",
                location: nil,
                capturedAt: nil,
                displayOrder: 1,
                address: nil
            ))
        ]
        
        var body: some View {
            HorizontalImageEditor(
                items: $items,
                maxCount: 10,
                onAddPhotos: { print("Add photos") },
                onReplacePhoto: { index in print("Replace photo at \(index)") }
            )
        }
    }
    
    return PreviewWrapper()
}
