//
//  ClusterGridSheetView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI
import Kingfisher

/// 群集 Sheet 視圖 - 使用 NavigationStack 管理內部導航
struct ClusterGridSheetView: View {
    let items: [ClusterItem]
    let mapSpanLatitudeDelta: Double
    let recordRepository: RecordRepository
    let askRepository: AskRepository
    let replyRepository: ReplyRepository
    
    @Environment(\.dismiss) private var dismiss
    @State private var navigationPath = NavigationPath()
    @State private var isResolvingLocationTitle = true
    @State private var locationPrimaryTitle = "重疊標點"
    @State private var locationSecondaryTitle: String? = nil
    @State private var selectedSortOption: ClusterSortOption = .latest
    @State private var showSortMenu = false
    @State private var randomRanksByItemId: [String: Int] = [:]
    
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
        VStack(spacing: 0) {
            SheetTopHandle(topPadding: 8, bottomPadding: 4)
            locationTitleView

            NavigationStack(path: $navigationPath) {
                gridContent
                    .navigationBarHidden(true)
                    .navigationDestination(for: ClusterDetailDestination.self) { destination in
                        detailView(for: destination)
                    }
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
            RecordDetailContentView(
                recordId: id,
                initialImageIndex: imageIndex,
                recordRepository: recordRepository,
                replyRepository: replyRepository
            )
        case .ask(let id):
            AskDetailSheetView(
                askId: id,
                askRepository: askRepository,
                replyRepository: replyRepository
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
                    Text("詢問標點")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    
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
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("定位中")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
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
}

// MARK: - Record Detail Content View (嵌入式版本，用於 NavigationStack)

struct RecordDetailContentView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var container: DIContainer
    @StateObject private var viewModel: RecordDetailViewModel
    @State private var showReplyInput = false
    @State private var showMoreOptions = false
    @State private var showEditSheet = false
    
    init(
        recordId: String,
        initialImageIndex: Int = 0,
        recordRepository: RecordRepository,
        replyRepository: ReplyRepository
    ) {
        _viewModel = StateObject(wrappedValue: RecordDetailViewModel(
            recordId: recordId,
            initialImageIndex: initialImageIndex,
            recordRepository: recordRepository,
            replyRepository: replyRepository
        ))
    }
    
    var body: some View {
        ZStack {
            if viewModel.isLoading {
                loadingView
            } else if let record = viewModel.record {
                contentView(record: record)
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else {
                loadingView
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                moreOptionsButton
            }
        }
        .task {
            viewModel.loadRecord()
        }
        .confirmationDialog("管理", isPresented: $showMoreOptions) {
            Button("編輯", role: nil) {
                showEditSheet = true
            }
            Button("刪除", role: .destructive) {
                viewModel.showDeleteConfirmation = true
            }
            Button("取消", role: .cancel) {}
        }
        .navigationDestination(isPresented: $showEditSheet) {
            if let record = viewModel.record {
                EditRecordView(
                    recordId: viewModel.recordId,
                    record: record,
                    uploadService: container.uploadService,
                    recordRepository: container.recordRepository,
                    onComplete: {
                        Task {
                            viewModel.loadRecord()
                        }
                    }
                )
            } else {
                VStack(spacing: 0) {
                    SheetTopHandle()
                    RecordDetailSkeleton()
                }
                .background(Color.appSurface)
                .task {
                    viewModel.loadRecord()
                }
            }
        }
        .alert("確認刪除", isPresented: $viewModel.showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("刪除", role: .destructive) {
                Task {
                    await viewModel.deleteRecord()
                }
            }
        } message: {
            Text("確定要刪除此標點嗎？此動作無法復原。")
        }
    }
    
    // MARK: - Content View
    
    private func contentView(record: Record) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 圖片輪播
                if let images = record.images, !images.isEmpty {
                    ImageCarouselView(
                        images: images,
                        initialIndex: viewModel.initialImageIndex,
                        onLocationTap: { image in
                            // 點擊「查看位置」按鈕跳轉到地圖位置
                            if let coordinate = image.clLocationCoordinate {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    navigationCoordinator.navigateToMap(coordinate: coordinate, mapMode: .record)
                                }
                            }
                        }
                    )
                    .frame(height: 280)
                }
                
                // 內容區
                VStack(alignment: .leading, spacing: 16) {
                    // 描述
                    Text(record.description)
                        .font(.body)
                    
                    // 時間
                    Text(formatDate(record.createdAt))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // 作者資訊 & 愛心
                    HStack {
                        if let author = record.author {
                            authorView(author: author)
                        }
                        
                        Spacer()
                        
                        LikeButtonLarge(
                            count: viewModel.likeCount,
                            isLiked: viewModel.isLiked
                        ) {
                            Task {
                                await viewModel.toggleLike()
                            }
                        }
                    }
                    
                    Divider()
                    
                    // 回覆區
                    repliesSection
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Author View
    
    private func authorView(author: User) -> some View {
        NavigationLink {
            OtherUserProfileContentView(
                userId: author.id,
                userRepository: container.userRepository
            )
        } label: {
            HStack(spacing: 10) {
                KFImage(URL(string: author.avatarUrl ?? ""))
                    .placeholder {
                        Circle()
                            .fill(Color(.systemGray4))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.secondary)
                            )
                    }
                    .retry(maxCount: 2, interval: .seconds(1))
                    .cacheOriginalImage()
                    .fade(duration: 0.2)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                
                Text(author.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Replies Section
    
    private var repliesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("回覆")
                    .font(.headline)
                
                Text("(\(viewModel.replies.count))")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            if viewModel.replies.isEmpty {
                Text("還沒有回覆")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                ForEach(viewModel.replies) { reply in
                    ReplyRowView(reply: reply) { replyId in
                        Task { await viewModel.toggleReplyLike(replyId: replyId) }
                    }
                    
                    if reply.id != viewModel.replies.last?.id {
                        Divider()
                    }
                }
            }
            
            // 新增回覆按鈕
            Button {
                showReplyInput = true
            } label: {
                HStack {
                    Image(systemName: "plus.bubble")
                    Text("新增回覆")
                }
                .font(.subheadline)
                .foregroundColor(.brandBlue)
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - Supporting Views
    
    private var loadingView: some View {
        RecordDetailSkeleton()
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text(message)
                .foregroundColor(.secondary)
            
            Button("重試") {
                Task {
                    viewModel.loadRecord()
                }
            }
        }
    }
    
    private var moreOptionsButton: some View {
        Button {
            showMoreOptions = true
        } label: {
            Image(systemName: "ellipsis")
                .font(.title3)
        }
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
