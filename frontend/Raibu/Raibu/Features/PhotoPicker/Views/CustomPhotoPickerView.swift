//
//  CustomPhotoPickerView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI
import Photos
import UIKit

/// 自定義相簿選擇器
struct CustomPhotoPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PhotoPickerViewModel
    
    let onComplete: ([SelectedPhoto]) -> Void
    
    @State private var isLoadingData = false
    @State private var showDateFilterSheet = false
    @State private var draftStartDate = Date()
    @State private var draftEndDate = Date()
    @State private var draftSingleDate = Date()
    @State private var draftDateMode: DateSelectionMode = .range
    @State private var draftRangeEditingTarget: RangeEditingTarget = .start

    private enum DateSelectionMode: String, CaseIterable {
        case single = "單一日期"
        case range = "日期區間"
    }

    private enum RangeEditingTarget {
        case start
        case end
    }

    init(
        photoPickerService: PhotoPickerService,
        requireGPS: Bool = false,
        maxSelection: Int = 10,
        initialSelectedPhotos: [SelectedPhoto] = [],
        onComplete: @escaping ([SelectedPhoto]) -> Void
    ) {
        let initialSelectedAssetIDs = initialSelectedPhotos.map { $0.asset.localIdentifier }
        _viewModel = StateObject(wrappedValue: PhotoPickerViewModel(
            photoPickerService: photoPickerService,
            requireGPS: requireGPS,
            maxSelection: maxSelection,
            initialSelectedAssetIDs: initialSelectedAssetIDs
        ))
        self.onComplete = onComplete
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SheetTopHandle()
            sheetHeader

            // 篩選控制區
            filterControls
            
            // 照片內容區
            photoContent
        }
        .background(Color.appSurface)
        .overlay(alignment: .bottom) {
            // 選取計數
            if !viewModel.selectedPhotos.isEmpty {
                selectionCounter
            }
        }
        .overlay {
            // Toast 提示
            if viewModel.showMaxLimitToast {
                maxLimitToast
            }
        }
        .sheet(isPresented: $showDateFilterSheet) {
            dateFilterSheet
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .task {
            await viewModel.loadPhotos()
        }
        .presentationDragIndicator(.hidden)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.selectedPhotos.map(\.id))
    }
    
    // MARK: - Filter Controls

    private var sheetHeader: some View {
        ZStack {
            Text("選擇照片")
                .font(.system(size: 38 / 2, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            HStack {
                Button("取消") {
                    dismiss()
                }
                .font(.custom("PingFangTC-Medium", size: 17))
                .foregroundColor(.secondary)
                .buttonStyle(.plain)
                
                Spacer()
                
                Button("完成") {
                    completeSelection()
                }
                .font(.custom("PingFangTC-Semibold", size: 17))
                .foregroundColor((viewModel.selectedPhotos.isEmpty || isLoadingData) ? .secondary : .brandBlue)
                .disabled(viewModel.selectedPhotos.isEmpty || isLoadingData)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 18)
    }
    
    private var filterControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !viewModel.selectedPhotos.isEmpty {
                selectedPhotosPreviewSection
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack {
                Text("日期篩選")
                    .font(.headline)
                
                Spacer()
                
                // GPS 篩選指示
                if viewModel.requireGPS {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                        Text("僅顯示有 GPS的照片")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PhotoDateShortcut.allCases, id: \.self) { shortcut in
                        Button {
                            if shortcut == .custom {
                                viewModel.switchToCustomRange()
                                prepareCustomDateDraft(defaultToToday: true)
                                showDateFilterSheet = true
                            } else {
                                Task {
                                    await viewModel.applyShortcut(shortcut)
                                }
                            }
                        } label: {
                            Text(shortcut.rawValue)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(viewModel.activeShortcut == shortcut ? Color.brandBlue : Color(.systemGray6))
                                .foregroundColor(viewModel.activeShortcut == shortcut ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
            
            if viewModel.activeShortcut == .custom {
                Button {
                    prepareCustomDateDraft()
                    showDateFilterSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(customDateSummary)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("編輯")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 7)
    }

    private var selectedPhotosPreviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("已選照片")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                Spacer()

                Text("\(viewModel.selectedPhotos.count)/\(viewModel.maxSelection) 張")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(.systemBackground).opacity(0.92))
                    .overlay(
                        Capsule()
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
                    .clipShape(Capsule())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.selectedPhotos) { photo in
                        SelectedPhotoPreviewCellView(photo: photo) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.toggleSelection(photo)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: 184)
        }
    }
    
    // MARK: - Photo Grid

    private var photoContent: some View {
        Group {
            if viewModel.photos.isEmpty {
                if viewModel.isLoading {
                    loadingView
                } else {
                    emptyView
                }
            } else {
                ZStack {
                    photoGrid

                    if viewModel.isLoading {
                        Color.appOverlay.opacity(0.08)
                            .ignoresSafeArea()

                        VStack(spacing: 8) {
                            ProgressView()
                            Text("更新中...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: Color.appOverlay.opacity(0.08), radius: 6, x: 0, y: 2)
                    }
                }
            }
        }
    }
    
    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2)
                ],
                spacing: 2
            ) {
                ForEach(viewModel.photos) { photo in
                    PhotoCellView(
                        photo: photo,
                        selectionNumber: viewModel.selectionNumber(for: photo),
                        isDisabled: viewModel.isDisabled(photo)
                    ) {
                        viewModel.toggleSelection(photo)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
    
    // MARK: - Supporting Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("載入照片中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("沒有符合條件的照片")
                .font(.headline)
            
            Text(viewModel.requireGPS ? "請確認照片有 GPS 資訊" : "請調整時間範圍")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var selectionCounter: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.brandBlue)
            Text("已選 \(viewModel.selectedPhotos.count)/\(viewModel.maxSelection) 張")
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.appOverlay.opacity(0.68))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.appOverlay.opacity(0.22), radius: 6, x: 0, y: 2)
        .padding(.bottom, 20)
    }
    
    private var maxLimitToast: some View {
        VStack {
            Spacer()
            
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.brandOrange)
                Text("已達 \(viewModel.maxSelection) 張上限")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.appOverlay.opacity(0.15), radius: 10)
            
            Spacer()
                .frame(height: 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.3), value: viewModel.showMaxLimitToast)
    }
    
    // MARK: - Actions
    
    private func completeSelection() {
        isLoadingData = true
        
        Task {
            do {
                let selectedPhotos = try await viewModel.loadSelectedPhotosData()
                await MainActor.run {
                    onComplete(selectedPhotos)
                    dismiss()
                }
            } catch {
                // Handle error
                await MainActor.run {
                    isLoadingData = false
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }

    private var customDateSummary: String {
        if Calendar.current.isDate(viewModel.startDate, inSameDayAs: viewModel.endDate) {
            return "日期：\(formattedDate(viewModel.startDate))"
        }
        return "\(formattedDate(viewModel.startDate)) - \(formattedDate(viewModel.endDate))"
    }

    private func prepareCustomDateDraft(defaultToToday: Bool = false) {
        let today = Calendar.current.startOfDay(for: Date())

        if defaultToToday {
            draftStartDate = today
            draftEndDate = today
            draftSingleDate = today
            draftDateMode = .single
            draftRangeEditingTarget = .start
            return
        }

        draftStartDate = viewModel.startDate
        draftEndDate = viewModel.endDate
        draftSingleDate = viewModel.startDate
        draftDateMode = Calendar.current.isDate(viewModel.startDate, inSameDayAs: viewModel.endDate) ? .single : .range
        draftRangeEditingTarget = .start
    }

    private func applyDraftDateFilter() {
        Task {
            switch draftDateMode {
            case .single:
                await viewModel.updateSingleDate(draftSingleDate)
            case .range:
                await viewModel.updateDateRange(start: draftStartDate, end: draftEndDate)
            }
        }
    }

    private var dateFilterSheet: some View {
        VStack(spacing: 0) {
            SheetTopHandle()

            ZStack {
                Text("選擇日期")
                    .font(.custom("PingFangTC-Semibold", size: 19))
                    .foregroundColor(.primary)

                HStack {
                    Button("取消") {
                        showDateFilterSheet = false
                    }
                    .font(.custom("PingFangTC-Medium", size: 17))
                    .foregroundColor(.secondary)
                    .buttonStyle(.plain)

                    Spacer()

                    Button("套用") {
                        applyDraftDateFilter()
                        showDateFilterSheet = false
                    }
                    .font(.custom("PingFangTC-Semibold", size: 17))
                    .foregroundColor(.brandBlue)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    dateModeSelector

                    if draftDateMode == .single {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("日期")
                                .font(.custom("PingFangTC-Medium", size: 15))
                                .foregroundColor(.secondary)

                            dateInfoCard(
                                title: "已選日期",
                                value: formattedDate(draftSingleDate)
                            )

                            calendarCard(selection: $draftSingleDate)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("日期區間")
                                .font(.custom("PingFangTC-Medium", size: 15))
                                .foregroundColor(.secondary)

                            HStack(spacing: 12) {
                                rangeEndpointCard(
                                    title: "開始",
                                    value: formattedDate(draftStartDate),
                                    isActive: draftRangeEditingTarget == .start
                                ) {
                                    draftRangeEditingTarget = .start
                                }

                                rangeEndpointCard(
                                    title: "結束",
                                    value: formattedDate(draftEndDate),
                                    isActive: draftRangeEditingTarget == .end
                                ) {
                                    draftRangeEditingTarget = .end
                                }
                            }

                            dateInfoCard(
                                title: "目前範圍",
                                value: "\(formattedDate(draftStartDate)) - \(formattedDate(draftEndDate))"
                            )

                            calendarCard(selection: rangeSelectionBinding)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white.ignoresSafeArea())
    }

    @ViewBuilder
    private var dateModeSelector: some View {
        HStack(spacing: 10) {
            dateModeButton(.single)
            dateModeButton(.range)
        }
    }

    @ViewBuilder
    private func dateModeButton(_ mode: DateSelectionMode) -> some View {
        Button {
            draftDateMode = mode
        } label: {
            VStack(spacing: 5) {
                Text(mode.rawValue)
                    .font(.custom("PingFangTC-Semibold", size: 16))
                    .foregroundColor(draftDateMode == mode ? .brandBlue : .primary)
                Text(mode == .single ? "選一天" : "選起訖日期")
                    .font(.custom("PingFangTC-Regular", size: 13))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(draftDateMode == mode ? Color.brandBlue.opacity(0.14) : Color(.systemGray6))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(draftDateMode == mode ? Color.brandBlue.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var rangeSelectionBinding: Binding<Date> {
        Binding(
            get: { draftRangeEditingTarget == .start ? draftStartDate : draftEndDate },
            set: { newValue in
                if draftRangeEditingTarget == .start {
                    draftStartDate = newValue
                    if draftStartDate > draftEndDate {
                        draftEndDate = draftStartDate
                    }
                } else {
                    draftEndDate = newValue
                    if draftEndDate < draftStartDate {
                        draftStartDate = draftEndDate
                    }
                }
            }
        )
    }

    private var globalMinSelectableDate: Date {
        Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date.distantPast
    }

    private var globalMaxSelectableDate: Date {
        let today = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .day, value: 1, to: today)?.addingTimeInterval(-1) ?? Date()
    }

    private var calendarMinDate: Date {
        if draftDateMode == .range, draftRangeEditingTarget == .end {
            return max(globalMinSelectableDate, Calendar.current.startOfDay(for: draftStartDate))
        }
        return globalMinSelectableDate
    }

    private var calendarMaxDate: Date {
        if draftDateMode == .range, draftRangeEditingTarget == .start {
            return min(globalMaxSelectableDate, endOfDay(draftEndDate))
        }
        return globalMaxSelectableDate
    }

    private func endOfDay(_ date: Date) -> Date {
        let start = Calendar.current.startOfDay(for: date)
        return Calendar.current.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-1) ?? date
    }

    @ViewBuilder
    private func calendarCard(selection: Binding<Date>) -> some View {
        NativeCalendarPicker(
            selectedDate: selection,
            minDate: calendarMinDate,
            maxDate: calendarMaxDate
        )
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .padding(10)
        .background(Color(.systemGray6))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipped()
    }

    @ViewBuilder
    private func rangeEndpointCard(
        title: String,
        value: String,
        isActive: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.custom("PingFangTC-Regular", size: 13))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.custom("PingFangTC-Semibold", size: 16))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isActive ? Color.brandBlue.opacity(0.14) : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isActive ? Color.brandBlue.opacity(0.55) : Color(.systemGray5), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func dateInfoCard(title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("PingFangTC-Regular", size: 12))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.custom("PingFangTC-Semibold", size: 16))
                    .foregroundColor(.primary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

}

// MARK: - Native Calendar Picker (UIKit)

private struct NativeCalendarPicker: UIViewRepresentable {
    typealias UIViewType = CalendarContainerView

    @Binding var selectedDate: Date
    var minDate: Date
    var maxDate: Date
    var calendar: Calendar = .current

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> CalendarContainerView {
        let view = CalendarContainerView()
        let calendarView = view.calendarView
        calendarView.calendar = calendar
        calendarView.locale = Locale.current
        calendarView.timeZone = TimeZone.current
        calendarView.tintColor = UIColor(Color.brandBlue)
        calendarView.backgroundColor = .clear
        calendarView.availableDateRange = DateInterval(start: minDate, end: maxDate)

        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        let components = dayComponents(from: clampedDate(selectedDate))
        selection.setSelected(components, animated: false)
        context.coordinator.lastSelectedKey = dayKey(from: components)
        context.coordinator.parent = self
        context.coordinator.selectionBehavior = selection
        calendarView.selectionBehavior = selection

        return view
    }

    func updateUIView(_ uiView: CalendarContainerView, context: Context) {
        context.coordinator.parent = self
        uiView.calendarView.availableDateRange = DateInterval(start: minDate, end: maxDate)

        let components = dayComponents(from: clampedDate(selectedDate))
        let nextKey = dayKey(from: components)
        guard context.coordinator.lastSelectedKey != nextKey else { return }

        context.coordinator.lastSelectedKey = nextKey
        context.coordinator.selectionBehavior?.setSelected(components, animated: false)
    }

    private func dayComponents(from date: Date) -> DateComponents {
        calendar.dateComponents([.year, .month, .day], from: date)
    }

    private func dayKey(from components: DateComponents) -> String {
        "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private func clampedDate(_ date: Date) -> Date {
        min(max(date, minDate), maxDate)
    }

    private func isSelectable(_ date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        let minDay = calendar.startOfDay(for: minDate)
        let maxDay = calendar.startOfDay(for: maxDate)
        return day >= minDay && day <= maxDay
    }

    final class Coordinator: NSObject, UICalendarSelectionSingleDateDelegate {
        var parent: NativeCalendarPicker
        var selectionBehavior: UICalendarSelectionSingleDate?
        var lastSelectedKey = ""

        init(_ parent: NativeCalendarPicker) {
            self.parent = parent
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents,
                  let date = parent.calendar.date(from: dateComponents) else { return }

            let key = "\(dateComponents.year ?? 0)-\(dateComponents.month ?? 0)-\(dateComponents.day ?? 0)"
            lastSelectedKey = key
            parent.selectedDate = date
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, canSelectDate dateComponents: DateComponents?) -> Bool {
            guard let dateComponents,
                  let date = parent.calendar.date(from: dateComponents) else { return false }
            return parent.isSelectable(date)
        }
    }

    final class CalendarContainerView: UIView {
        let calendarView = UICalendarView()

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            translatesAutoresizingMaskIntoConstraints = false

            calendarView.translatesAutoresizingMaskIntoConstraints = false
            calendarView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            calendarView.setContentHuggingPriority(.defaultLow, for: .horizontal)

            addSubview(calendarView)
            NSLayoutConstraint.activate([
                calendarView.leadingAnchor.constraint(equalTo: leadingAnchor),
                calendarView.trailingAnchor.constraint(equalTo: trailingAnchor),
                calendarView.topAnchor.constraint(equalTo: topAnchor),
                calendarView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

// MARK: - Photo Cell View

struct PhotoCellView: View {
    let photo: SelectablePhoto
    let selectionNumber: Int?
    let isDisabled: Bool
    let onTap: () -> Void
    
    @State private var thumbnail: UIImage?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                // 照片
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: geometry.size.width, height: geometry.size.width)
                }
                
                // 禁用遮罩
                if isDisabled {
                    Color.appOverlay.opacity(0.5)
                }
                
                // 選取編號徽章
                if let number = selectionNumber {
                    selectionBadge(number: number)
                        .padding(6)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
        .aspectRatio(1, contentMode: .fit)
        .task {
            await loadThumbnail()
        }
    }
    
    private func selectionBadge(number: Int) -> some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.45))
                .frame(width: 26, height: 26)
            
            Text("\(number)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private func loadThumbnail() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        
        let size = CGSize(width: 200, height: 200)
        
        await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: photo.asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image = image {
                    Task { @MainActor in
                        self.thumbnail = image
                    }
                }
                continuation.resume()
            }
        }
    }
}

private struct SelectedPhotoPreviewCellView: View {
    let photo: SelectablePhoto
    let onRemove: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    )
            }
        }
        .frame(width: 136, height: 176)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topLeading) {
            Button(action: onRemove) {
                Circle()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: 33, height: 33)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .task(id: photo.id) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true

        let size = CGSize(width: 420, height: 540)

        await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: photo.asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image = image {
                    Task { @MainActor in
                        thumbnail = image
                    }
                }
                continuation.resume()
            }
        }
    }
}

#Preview {
    CustomPhotoPickerView(
        photoPickerService: PhotoPickerService(),
        requireGPS: true,
        maxSelection: 10
    ) { photos in
        print("Selected \(photos.count) photos")
    }
}
