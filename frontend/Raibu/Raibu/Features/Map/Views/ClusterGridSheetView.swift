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
                VStack(spacing: 0) {
                    locationTitleView

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
                                    if case .ask(let ask) = item {
                                        ClusterAskDetailPreviewCard(
                                            askSummary: ask,
                                            askRepository: askRepository,
                                            replyRepository: replyRepository,
                                            onOpenDetail: {
                                                showSortMenu = false
                                                navigationPath.append(
                                                    ClusterDetailDestination.ask(id: ask.id)
                                                )
                                            }
                                        )
                                    }

                                    if item.id != askItems.last?.id {
                                        Divider()
                                    }
                                }
                            }
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
                .padding(.top, 8)
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
                        .font(.system(size: 44, weight: .bold, design: .rounded))
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
                .padding(.bottom, 8)
            }

            Divider()
                .padding(.horizontal, 16)
        }
        .animation(.easeInOut(duration: 0.2), value: isResolvingLocationTitle)
    }

    private var locationTitleLoadingView: some View {
        let primaryHeight = roundedFontLineHeight(size: 44, weight: .bold)
        let secondaryHeight = roundedFontLineHeight(size: 15, weight: .regular)
        return VStack(alignment: .leading, spacing: 6) {
            ShimmerBox(width: 220, height: primaryHeight, cornerRadius: 8)

            HStack(alignment: .center) {
                ShimmerBox(width: 140, height: secondaryHeight, cornerRadius: 4)
                Spacer(minLength: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
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

private struct ClusterAskDetailPreviewCard: View {
    let askSummary: MapAsk
    let askRepository: AskRepository
    let replyRepository: ReplyRepository
    let onOpenDetail: () -> Void

    @State private var ask: Ask?
    @State private var replyCount: Int = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasStartedInitialLoad = false
    @State private var scrolledImageId: String?
    @State private var isDescriptionExpanded = false
    @State private var isHeartAnimating = false

    private let askTitleFont = Font.custom("PingFangTC-Medium", size: 18)
    private let askBodyFont = Font.system(size: 16, weight: .regular, design: .rounded)
    private let collapsedDescriptionMaxHeight: CGFloat = 110
    private let imageCardWidth: CGFloat = 181
    private let imageCardHeight: CGFloat = 227

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                loadingView
            } else if let ask {
                contentView(ask: ask)
            } else {
                fallbackView
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
        .task {
            guard !hasStartedInitialLoad else { return }
            hasStartedInitialLoad = true
            await loadAskDetail()
        }
    }

    private func contentView(ask: Ask) -> some View {
        let hasImages = !(ask.images?.isEmpty ?? true)
        return VStack(alignment: .leading, spacing: 0) {
            authorRow(
                displayName: ask.author?.displayName ?? "使用者",
                avatarURL: ask.author?.avatarUrl ?? askSummary.authorAvatarUrl,
                createdAt: ask.createdAt,
                onTap: onOpenDetail
            )

            if let images = ask.images, !images.isEmpty {
                let currentImage = currentVisibleImage(in: images)
                DetailImageCarouselView(
                    images: images,
                    initialImageIndex: 0,
                    cardWidth: imageCardWidth,
                    cardHeight: imageCardHeight,
                    layoutStyle: .edgeAligned,
                    scrolledImageId: $scrolledImageId,
                    onImageTap: { _, _ in onOpenDetail() }
                )
                .padding(.horizontal, 20)

                if shouldShowImageMeta(for: currentImage) {
                    DetailImageMetaRowView(
                        image: currentImage,
                        scrolledImageId: scrolledImageId,
                        onLocationTap: { _ in onOpenDetail() }
                    )
                    .padding(.top, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onOpenDetail()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    if let title = ask.title, !title.isEmpty {
                        Text(title)
                            .font(askTitleFont)
                            .foregroundColor(.primary)
                    }

                    DetailDescriptionSection(
                        description: ask.question,
                        isExpanded: $isDescriptionExpanded,
                        font: askBodyFont,
                        minHeight: nil,
                        collapsedMaxHeight: collapsedDescriptionMaxHeight
                    )

                    if ask.status == .resolved {
                        Label("已解決", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.appSuccess)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onOpenDetail()
                }

                interactionSummaryRow(
                    isLiked: ask.userHasLiked ?? false,
                    likeCount: ask.likeCount,
                    replyCount: replyCount,
                    onLikeTap: {
                        Task { await toggleLike() }
                    },
                    onOpenDetail: onOpenDetail
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, hasImages ? 12 : 4)
            .padding(.bottom, 4)
        }
    }

    private var fallbackView: some View {
        VStack(alignment: .leading, spacing: 0) {
            authorRow(
                displayName: "使用者",
                avatarURL: askSummary.authorAvatarUrl,
                createdAt: askSummary.createdAt,
                onTap: onOpenDetail
            )

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    if let title = askSummary.title, !title.isEmpty {
                        Text(title)
                            .font(askTitleFont)
                            .foregroundColor(.primary)
                    }

                    DetailDescriptionSection(
                        description: askSummary.question,
                        isExpanded: $isDescriptionExpanded,
                        font: askBodyFont,
                        minHeight: nil,
                        collapsedMaxHeight: collapsedDescriptionMaxHeight
                    )

                    if askSummary.status == .resolved {
                        Label("已解決", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.appSuccess)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onOpenDetail()
                }

                if errorMessage != nil {
                    Text("預覽載入失敗，仍可查看完整詳情")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 4)
        }
    }

    private var loadingView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ShimmerCircle(size: 40)
                VStack(alignment: .leading, spacing: 6) {
                    ShimmerBox(width: 120, height: 15, cornerRadius: 4)
                    ShimmerBox(width: 78, height: 11, cornerRadius: 4)
                }
                Spacer()
            }

            ShimmerBox(height: imageCardHeight, cornerRadius: 12)
            ShimmerBox(height: 16, cornerRadius: 4)
            ShimmerBox(width: 220, height: 16, cornerRadius: 4)
            ShimmerBox(width: 160, height: 12, cornerRadius: 4)
        }
        .padding(.horizontal, 16)
    }

    private func authorRow(
        displayName: String,
        avatarURL: String?,
        createdAt: Date,
        onTap: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 12) {
            KFImage(URL(string: avatarURL ?? ""))
                .placeholder {
                    Circle().fill(Color(.systemGray5))
                }
                .retry(maxCount: 2, interval: .seconds(1))
                .cacheOriginalImage()
                .fade(duration: 0.2)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                Text(DetailSheetHelpers.formatTimeAgo(createdAt))
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }

    private func interactionSummaryRow(
        isLiked: Bool,
        likeCount: Int,
        replyCount: Int,
        onLikeTap: @escaping () -> Void,
        onOpenDetail: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 18) {
            Button {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.45)) {
                    isHeartAnimating = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                        isHeartAnimating = false
                    }
                }
                onLikeTap()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundColor(isLiked ? .red : .secondary)
                        .scaleEffect(isHeartAnimating ? 1.24 : (isLiked ? 1.08 : 1.0))
                        .animation(.spring(response: 0.28, dampingFraction: 0.6), value: isHeartAnimating)
                        .animation(.easeInOut(duration: 0.15), value: isLiked)
                    Text("\(likeCount)")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 18) {
                HStack(spacing: 6) {
                    Image(systemName: "message")
                        .foregroundColor(.secondary)
                    Text("\(replyCount)")
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                onOpenDetail()
            }
        }
        .font(.system(size: 14, weight: .medium, design: .rounded))
        .padding(.top, 1)
    }

    private func currentVisibleImage(in images: [ImageMedia]) -> ImageMedia {
        if let scrolledImageId,
           let current = images.first(where: { $0.id == scrolledImageId }) {
            return current
        }
        return images.first!
    }

    private func loadAskDetail() async {
        isLoading = true
        errorMessage = nil

        do {
            async let askTask = askRepository.getAskDetail(id: askSummary.id)
            async let repliesTask = replyRepository.getRepliesForAsk(askId: askSummary.id)

            let loadedAsk = try await askTask
            let loadedReplies: [Reply]
            do {
                loadedReplies = try await repliesTask
            } catch {
                loadedReplies = []
            }

            ask = loadedAsk
            replyCount = loadedReplies.count
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func toggleLike() async {
        guard let currentAsk = ask else { return }

        let wasLiked = currentAsk.userHasLiked ?? false
        let previousLikeCount = currentAsk.likeCount
        let optimisticLikeCount = wasLiked ? previousLikeCount - 1 : previousLikeCount + 1

        ask = askWithLikeState(currentAsk, likeCount: optimisticLikeCount, isLiked: !wasLiked)

        do {
            let response = try await replyRepository.toggleLikeForAsk(id: currentAsk.id)
            if let updatedAsk = ask {
                ask = askWithLikeState(
                    updatedAsk,
                    likeCount: response.likeCount,
                    isLiked: response.action == "liked"
                )
            }
        } catch {
            ask = askWithLikeState(currentAsk, likeCount: previousLikeCount, isLiked: wasLiked)
        }
    }

    private func askWithLikeState(_ ask: Ask, likeCount: Int, isLiked: Bool) -> Ask {
        Ask(
            id: ask.id,
            userId: ask.userId,
            center: ask.center,
            radiusMeters: ask.radiusMeters,
            title: ask.title,
            question: ask.question,
            mainImageUrl: ask.mainImageUrl,
            status: ask.status,
            likeCount: likeCount,
            viewCount: ask.viewCount,
            createdAt: ask.createdAt,
            updatedAt: ask.updatedAt,
            author: ask.author,
            images: ask.images,
            userHasLiked: isLiked
        )
    }

    private func shouldShowImageMeta(for image: ImageMedia) -> Bool {
        let hasAddress = !(image.address?.isEmpty ?? true)
        return image.location != nil || hasAddress || image.capturedAt != nil
    }
}
