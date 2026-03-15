//
//  ClusterGridSheetView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI
import Kingfisher
import UIKit

/// 群集 Sheet 視圖 - 使用 NavigationStack 管理內部導航
struct ClusterGridSheetView: View {
    let items: [ClusterItem]
    let mapSpanLatitudeDelta: Double
    let recordRepository: RecordRepository
    let askRepository: AskRepository
    let replyRepository: ReplyRepository
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var container: DIContainer
    @State private var navigationPath = NavigationPath()
    @State private var isResolvingLocationTitle = true
    @State private var locationPrimaryTitle = "重疊標點"
    @State private var locationSecondaryTitle: String? = nil
    @State private var selectedSortOption: ClusterSortOption = .latest
    @State private var showSortMenu = false
    @State private var randomRanksByItemId: [String: Int] = [:]
    @State private var pendingRecordEditId: String? = nil
    @State private var pendingRecordEditOnComplete: (() -> Void)? = nil
    @State private var recordEditPrefetchedRecords: [String: Record] = [:]
    
    private let sortMenuWidth: CGFloat = 186
    private let sortMenuShowAnimation = Animation.spring(response: 0.32, dampingFraction: 0.82)
    private let sortMenuHideAnimation = Animation.easeOut(duration: 0.18)
    
    // 3 columns grid
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    /// 過濾紀錄圖片
    private var rawRecordImageItems: [ClusterItem] {
        items.filter { item in
            if case .recordImage = item { return true }
            return false
        }
    }
    
    /// 排序後的紀錄圖片
    private var recordImageItems: [ClusterItem] {
        rawRecordImageItems.sorted { item1, item2 in
            guard case .recordImage(let img1) = item1,
                  case .recordImage(let img2) = item2 else { return false }
            return shouldPlaceRecordImageFirst(img1, before: img2)
        }
    }
    
    /// 過濾詢問標點
    private var rawAskItems: [ClusterItem] {
        items.filter { item in
            if case .ask = item { return true }
            return false
        }
    }
    
    /// 排序後的詢問標點
    private var askItems: [ClusterItem] {
        rawAskItems.sorted { item1, item2 in
            guard case .ask(let ask1) = item1,
                  case .ask(let ask2) = item2 else { return false }
            return shouldPlaceAskFirst(ask1, before: ask2)
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                SheetTopHandle(topPadding: 8, bottomPadding: 4)
                locationTitleView
                gridContent
            }
            .navigationBarHidden(true)
            .navigationDestination(for: ClusterDetailDestination.self) { destination in
                detailView(for: destination)
            }
        }
        .presentationDragIndicator(.hidden)
        .overlayPreferenceValue(ClusterSortButtonAnchorPreferenceKey.self) { anchor in
            GeometryReader { proxy in
                if showSortMenu, let anchor {
                    let buttonFrame = proxy[anchor]
                    ZStack(alignment: .topLeading) {
                        Color.appOverlay.opacity(0.001)
                            .ignoresSafeArea()
                            .onTapGesture {
                                closeSortMenu()
                            }

                        DetailMoreOptionsMenu(menuWidth: sortMenuWidth) {
                            sortMenuContent
                        }
                        .offset(
                            x: centeredSortMenuX(
                                buttonFrame: buttonFrame,
                                containerWidth: proxy.size.width
                            ),
                            y: buttonFrame.maxY + 10
                        )
                        .transition(.asymmetric(
                            insertion: .opacity
                                .combined(with: .scale(scale: 0.92, anchor: .top))
                                .combined(with: .offset(y: -8)),
                            removal: .opacity
                                .combined(with: .scale(scale: 0.98, anchor: .top))
                                .combined(with: .offset(y: -4))
                        ))
                        .zIndex(100)
                    }
                }
            }
        }
        .onAppear {
            regenerateRandomRanks()
        }
        .onChange(of: selectedSortOption) { _, newValue in
            if newValue == .random {
                regenerateRandomRanks()
            }
        }
        .onChange(of: navigationPath.count) { _, newCount in
            if newCount > 0, showSortMenu {
                closeSortMenu()
            }
        }
        .task(id: locationTitleTaskID) {
            await resolveLocationTitle()
        }
    }
    
    // MARK: - Grid Content
    
    private var gridContent: some View {
        GeometryReader { geometry in
            let itemSize = (geometry.size.width - 4) / 3 // 3 columns with 2pt spacing
            
            ScrollView {
                VStack(spacing: 16) {
                    // 如果有圖片，顯示九宮格
                    if !recordImageItems.isEmpty {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(recordImageItems) { item in
                                Button {
                                    showSortMenu = false
                                    if case .recordImage(let image) = item {
                                        navigationPath.append(
                                            ClusterDetailDestination.record(
                                                id: image.recordId,
                                                imageIndex: image.displayOrder
                                            )
                                        )
                                    }
                                } label: {
                                    gridImageView(item, size: itemSize)
                                }
                            }
                        }
                    }
                    
                    // 如果有詢問標點，顯示列表
                    if !askItems.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(askItems) { item in
                                Button {
                                    showSortMenu = false
                                    if case .ask(let ask) = item {
                                        navigationPath.append(
                                            ClusterDetailDestination.ask(id: ask.id)
                                        )
                                    }
                                } label: {
                                    askRowView(item)
                                }
                                
                                if item.id != askItems.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 如果完全沒有資料，顯示提示
                    if recordImageItems.isEmpty && askItems.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("沒有可顯示的標點")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }
                }
            }
        }
    }
    
    // MARK: - Detail View
    
    @ViewBuilder
    private func detailView(for destination: ClusterDetailDestination) -> some View {
        switch destination {
        case .record(let id, let imageIndex):
            RecordDetailSheetView(
                recordId: id,
                initialImageIndex: imageIndex,
                recordRepository: recordRepository,
                replyRepository: replyRepository,
                onOpenUserProfile: { userId in
                    navigationPath.append(ClusterDetailDestination.userProfile(id: userId))
                },
                onOpenRecordEdit: { recordId, prefetchedRecord, onUpdated in
                    pendingRecordEditId = recordId
                    pendingRecordEditOnComplete = onUpdated
                    if let prefetchedRecord {
                        recordEditPrefetchedRecords[recordId] = prefetchedRecord
                    }
                    navigationPath.append(ClusterDetailDestination.recordEdit(id: recordId))
                },
                showsBackButtonOverride: false
            )
        case .ask(let id):
            AskDetailSheetView(
                askId: id,
                askRepository: askRepository,
                replyRepository: replyRepository
            )
        case .userProfile(let userId):
            OtherUserProfileContentView(
                userId: userId,
                userRepository: container.userRepository
            )
        case .recordEdit(let recordId):
            RecordEditRouteView(
                recordId: recordId,
                prefetchedRecord: recordEditPrefetchedRecords[recordId],
                recordRepository: recordRepository,
                uploadService: container.uploadService,
                onComplete: {
                    if pendingRecordEditId == recordId {
                        pendingRecordEditOnComplete?()
                        pendingRecordEditOnComplete = nil
                        pendingRecordEditId = nil
                    }
                }
            )
        }
    }
    
    // MARK: - Grid Image View
    
    @ViewBuilder
    private func gridImageView(_ item: ClusterItem, size: CGFloat) -> some View {
        if case .recordImage(let image) = item {
            KFImage(URL(string: image.thumbnailPublicUrl))
                .placeholder {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .shimmer()
                }
                .retry(maxCount: 2, interval: .seconds(1))
                .cacheOriginalImage()
                .fade(duration: 0.2)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipped()
        }
    }
    
    // MARK: - Ask Row View
    
    @ViewBuilder
    private func askRowView(_ item: ClusterItem) -> some View {
        if case .ask(let ask) = item {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.brandOrange.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "questionmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.brandOrange)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if let title = ask.title, !title.isEmpty {
                        Text(title)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    } else {
                        Text("詢問標點")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                    }
                    
                    Text(ask.question)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - Sort Menu

    private var locationTitleView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 返回按鈕（sheet 最左上角）
            backButton
                .padding(.leading, 16)
                .padding(.top, 4)
                .padding(.bottom, 30)

            // 地點標題 + 排序按鈕
            if isResolvingLocationTitle {
                locationTitleLoadingView
            } else {
                // 地點標題：大字 primary + 小字 secondary 行
                VStack(alignment: .leading, spacing: 6) {
                    Text(locationPrimaryTitle)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)

                    HStack(alignment: .firstTextBaseline) {
                        if let locationSecondaryTitle {
                            Text(locationSecondaryTitle)
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundStyle(Color.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)

                        sortDropdownButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
            }

            Divider()
                .padding(.horizontal, 16)
        }
        .animation(.easeInOut(duration: 0.2), value: isResolvingLocationTitle)
    }

    private var locationTitleLoadingView: some View {
        let primaryHeight = roundedFontLineHeight(size: 48, weight: .bold)
        let secondaryHeight = roundedFontLineHeight(size: 15, weight: .regular)
        return VStack(alignment: .leading, spacing: 6) {
            ShimmerBox(width: 220, height: primaryHeight, cornerRadius: 8)

            HStack(alignment: .center) {
                ShimmerBox(width: 140, height: secondaryHeight, cornerRadius: 4)
                Spacer(minLength: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private func roundedFontLineHeight(size: CGFloat, weight: UIFont.Weight) -> CGFloat {
        let baseFont = UIFont.systemFont(ofSize: size, weight: weight)
        let roundedDescriptor = baseFont.fontDescriptor.withDesign(.rounded) ?? baseFont.fontDescriptor
        let roundedFont = UIFont(descriptor: roundedDescriptor, size: baseFont.pointSize)
        return roundedFont.lineHeight
    }

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }

    private var sortDropdownButton: some View {
        Button {
            if showSortMenu {
                closeSortMenu()
            } else {
                openSortMenu()
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedSortOption.title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.secondary)
                    .rotationEffect(.degrees(showSortMenu ? 180 : 0))
                    .animation(sortMenuShowAnimation, value: showSortMenu)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .anchorPreference(key: ClusterSortButtonAnchorPreferenceKey.self, value: .bounds) { $0 }
    }

    private var sortMenuContent: some View {
        let options = ClusterSortOption.allCases
        return VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                sortOptionRow(for: option)
                if index < options.count - 1 {
                    DetailOptionDivider()
                }
            }
        }
    }

    private func sortOptionRow(for option: ClusterSortOption) -> some View {
        Button {
            selectedSortOption = option
            closeSortMenu()
        } label: {
            HStack(spacing: 12) {
                Text(option.title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.primary)

                Spacer()

                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .opacity(option == selectedSortOption ? 1 : 0)
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sort Helpers

    private func shouldPlaceRecordImageFirst(_ lhs: MapRecordImage, before rhs: MapRecordImage) -> Bool {
        switch selectedSortOption {
        case .latest:
            return isRecordImageNewer(lhs, than: rhs)

        case .mostViewed:
            let lhsCount = lhs.viewCount ?? Int.min
            let rhsCount = rhs.viewCount ?? Int.min
            if lhsCount != rhsCount { return lhsCount > rhsCount }
            return isRecordImageNewer(lhs, than: rhs)

        case .mostLiked:
            let lhsCount = lhs.likeCount ?? Int.min
            let rhsCount = rhs.likeCount ?? Int.min
            if lhsCount != rhsCount { return lhsCount > rhsCount }
            return isRecordImageNewer(lhs, than: rhs)

        case .random:
            let lhsRank = randomRanksByItemId["record_\(lhs.imageId)"] ?? Int.max
            let rhsRank = randomRanksByItemId["record_\(rhs.imageId)"] ?? Int.max
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return isRecordImageNewer(lhs, than: rhs)
        }
    }

    private func shouldPlaceAskFirst(_ lhs: MapAsk, before rhs: MapAsk) -> Bool {
        switch selectedSortOption {
        case .latest:
            return isAskNewer(lhs, than: rhs)

        case .mostViewed:
            let lhsCount = lhs.viewCount ?? Int.min
            let rhsCount = rhs.viewCount ?? Int.min
            if lhsCount != rhsCount { return lhsCount > rhsCount }
            return isAskNewer(lhs, than: rhs)

        case .mostLiked:
            let lhsCount = lhs.likeCount ?? Int.min
            let rhsCount = rhs.likeCount ?? Int.min
            if lhsCount != rhsCount { return lhsCount > rhsCount }
            return isAskNewer(lhs, than: rhs)

        case .random:
            let lhsRank = randomRanksByItemId["ask_\(lhs.id)"] ?? Int.max
            let rhsRank = randomRanksByItemId["ask_\(rhs.id)"] ?? Int.max
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return isAskNewer(lhs, than: rhs)
        }
    }

    private func isRecordImageNewer(_ lhs: MapRecordImage, than rhs: MapRecordImage) -> Bool {
        if let date1 = lhs.createdAt, let date2 = rhs.createdAt, date1 != date2 {
            return date1 > date2
        }
        if lhs.createdAt != nil, rhs.createdAt == nil { return true }
        if lhs.createdAt == nil, rhs.createdAt != nil { return false }
        if lhs.recordId != rhs.recordId { return lhs.recordId > rhs.recordId }
        return lhs.id > rhs.id
    }

    private func isAskNewer(_ lhs: MapAsk, than rhs: MapAsk) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }
        return lhs.id > rhs.id
    }

    private func regenerateRandomRanks() {
        var newRanks: [String: Int] = [:]
        for (index, id) in items.map(\.id).shuffled().enumerated() {
            newRanks[id] = index
        }
        randomRanksByItemId = newRanks
    }

    private func centeredSortMenuX(buttonFrame: CGRect, containerWidth: CGFloat) -> CGFloat {
        let horizontalPadding: CGFloat = 12
        let idealX = buttonFrame.midX - (sortMenuWidth / 2)
        let maxX = max(horizontalPadding, containerWidth - sortMenuWidth - horizontalPadding)
        return min(max(idealX, horizontalPadding), maxX)
    }

    private var locationTitleTaskID: String {
        items.map(\.id).sorted().joined(separator: "|")
    }

    private func resolveLocationTitle() async {
        isResolvingLocationTitle = true
        let coordinates = items.map(\.coordinate)
        let resolved = await ClusterLocationTitleService.shared.buildTitleParts(
            for: coordinates,
            mapSpanLatitudeDelta: mapSpanLatitudeDelta
        )

        if Task.isCancelled { return }

        locationPrimaryTitle = resolved.primary
        locationSecondaryTitle = resolved.secondary
        isResolvingLocationTitle = false
    }

    private func openSortMenu() {
        withAnimation(sortMenuShowAnimation) {
            showSortMenu = true
        }
    }

    private func closeSortMenu() {
        withAnimation(sortMenuHideAnimation) {
            showSortMenu = false
        }
    }
}

private enum ClusterSortOption: String, CaseIterable, Identifiable {
    case latest
    case mostViewed
    case random
    case mostLiked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .latest:
            return "最新"
        case .mostViewed:
            return "最多人觀看"
        case .random:
            return "隨機"
        case .mostLiked:
            return "最多愛心"
        }
    }
}

private struct ClusterSortButtonAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>?

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

// MARK: - Navigation Destination

enum ClusterDetailDestination: Hashable {
    case record(id: String, imageIndex: Int)
    case ask(id: String)
    case userProfile(id: String)
    case recordEdit(id: String)
}
