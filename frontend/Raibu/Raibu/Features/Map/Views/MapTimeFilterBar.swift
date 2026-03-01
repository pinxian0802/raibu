//
//  MapTimeFilterBar.swift
//  Raibu
//
//  地圖時間篩選器 — 點擊按鈕展開 Chip 列
//

import SwiftUI

/// 地圖時間篩選觸發按鈕（放在頂部同一行）— 顯示當前篩選狀態
struct MapTimeFilterToggle: View {
    let currentFilter: MapTimeFilter
    let currentMode: MapMode
    @Binding var isExpanded: Bool
    
    private var accentColor: Color {
        currentMode == .record ? Color.brandBlue : Color.brandOrange
    }
    
    private var isSpecificDate: Bool {
        if case .specificDate = currentFilter { return true }
        return false
    }
    
    private func yearString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f.string(from: date)
    }
    
    private func monthDayString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: date)
    }
    
    var body: some View {
        Button {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                isExpanded.toggle()
            }
        } label: {
            ZStack {
                // Icon 固定靠左
                HStack {
                    Image(systemName: isExpanded ? "chevron.up" : "calendar")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                }
                .padding(.leading, 10)
                
                // 文字置中
                if isSpecificDate, case .specificDate(let date) = currentFilter {
                    VStack(spacing: 1) {
                        Text(yearString(from: date))
                            .font(.system(size: 10, weight: .semibold))
                        Text(monthDayString(from: date))
                            .font(.system(size: 12, weight: .bold))
                    }
                    .lineLimit(1)
                    .padding(.leading, 16)
                } else {
                    Text(currentFilter.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .padding(.leading, 16)
                }
            }
            .foregroundColor(isExpanded ? .white : accentColor)
            .frame(width: 90, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isExpanded ? accentColor : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isExpanded ? Color.clear : accentColor.opacity(0.5), lineWidth: 1.5)
            )
            .shadow(color: Color.appOverlay.opacity(0.15), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

/// 地圖時間篩選 Chip 列（展開時顯示在按鈕下方）
struct MapTimeFilterChipBar: View {
    @Binding var selectedFilter: MapTimeFilter
    let currentMode: MapMode
    let onFilterChanged: (MapTimeFilter) -> Void
    
    @State private var showDatePicker = false
    @State private var pickerDate = Date()
    
    private var accentColor: Color {
        currentMode == .record ? Color.brandBlue : Color.brandOrange
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 預設選項
                ForEach(MapTimeFilter.presets, id: \.title) { filter in
                    chipButton(for: filter, isSelected: selectedFilter == filter)
                }
                
                // 選擇日期按鈕
                datePickerChip
            }
            .padding(.horizontal, 16)
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(
                selectedDate: $pickerDate,
                accentColor: accentColor
            ) { date in
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                selectedFilter = .specificDate(date)
                onFilterChanged(.specificDate(date))
            }
            .presentationDetents([.height(420)])
        }
    }
    
    // MARK: - Chip Button
    
    private func chipButton(for filter: MapTimeFilter, isSelected: Bool) -> some View {
        Button {
            guard selectedFilter != filter else { return }
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedFilter = filter
            }
            onFilterChanged(filter)
        } label: {
            Text(filter.title)
                .font(.system(size: 13, weight: .semibold))
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [accentColor, accentColor.opacity(0.85)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
                } else {
                    Capsule()
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.appOverlay.opacity(0.08), radius: 2, x: 0, y: 1)
                }
            }
            .overlay {
                if !isSelected {
                    Capsule()
                        .stroke(Color(.separator).opacity(0.2), lineWidth: 0.5)
                }
            }
        }
        .buttonStyle(ChipButtonStyle())
    }
    
    // MARK: - Date Picker Chip
    
    private var isDateSelected: Bool {
        if case .specificDate = selectedFilter { return true }
        return false
    }
    
    private var datePickerChip: some View {
        Button {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            showDatePicker = true
        } label: {
            Text(isDateSelected ? selectedFilter.title : "選日期")
                .font(.system(size: 13, weight: .semibold))
            .foregroundColor(isDateSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                if isDateSelected {
                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [accentColor, accentColor.opacity(0.85)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
                } else {
                    Capsule()
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.appOverlay.opacity(0.08), radius: 2, x: 0, y: 1)
                }
            }
            .overlay {
                if !isDateSelected {
                    Capsule()
                        .stroke(Color(.separator).opacity(0.2), lineWidth: 0.5)
                }
            }
        }
        .buttonStyle(ChipButtonStyle())
    }
}

// MARK: - Button Style

private struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Date Picker Sheet

private struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    let accentColor: Color
    let onConfirm: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "選擇日期",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(accentColor)
                .padding(.horizontal)
            }
            .navigationTitle("選擇日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("確認") {
                        onConfirm(selectedDate)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(accentColor)
                }
            }
        }
    }
}
