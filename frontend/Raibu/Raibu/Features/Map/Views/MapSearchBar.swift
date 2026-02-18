//
//  MapSearchBar.swift
//  Raibu
//
//  Created on 2026/01/12.
//

import MapKit
import SwiftUI

/// 地圖搜尋欄元件（含即時搜尋建議下拉選單）
struct MapSearchBar: View {
    @Binding var searchText: String
    @Binding var isSearchActive: Bool
    @Binding var isExpanded: Bool // 新增：控制展開狀態
    let mapRegion: MKCoordinateRegion
    let onSearchResultSelected: (SearchResult) async -> Void
    let onSearchCleared: () -> Void

    @State private var searchCompleter = MapSearchCompleter()
    @FocusState private var isTextFieldFocused: Bool

    private var showSuggestions: Bool {
        isSearchActive && !searchText.isEmpty
            && (searchCompleter.isSearching || searchCompleter.hasSearched)
    }

    var body: some View {
        // 搜尋輸入框
        searchField
            .overlay(alignment: .topLeading) {
                // 建議列表使用 overlay，不影響佈局
                if showSuggestions {
                    suggestionsDropdown
                        .frame(width: UIScreen.main.bounds.width - 32)
                        .offset(y: 52) // 搜尋欄高度 44 + 間距 8
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isExpanded)
            .animation(.easeInOut(duration: 0.2), value: showSuggestions)
            .onChange(of: searchText) { _, newValue in
                searchCompleter.updateQuery(newValue, in: mapRegion)
                if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                    onSearchCleared()
                }
            }
            .onChange(of: isTextFieldFocused) { _, newValue in
                if newValue {
                    isSearchActive = true
                }
            }
            .onChange(of: isSearchActive) { _, newValue in
                if !newValue {
                    isTextFieldFocused = false
                }
            }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 12) {
            // 左側圖示（放大鏡 ↔ 返回箭頭）- 平滑變形
            Button {
                if isExpanded {
                    collapseSearch()
                } else {
                    expandSearch()
                }
            } label: {
                Image(systemName: isExpanded ? "arrow.left" : "magnifyingglass")
                    .font(.system(size: isExpanded ? 18 : 20, weight: .medium))
                    .foregroundStyle(isExpanded ? .primary : .primary)
                    .contentTransition(.symbolEffect(.replace))
            }
            
            // 搜尋框（展開時才顯示）
            if isExpanded {
                HStack(spacing: 10) {
                    TextField("搜尋地點", text: $searchText)
                        .textFieldStyle(.plain)
                        .submitLabel(.search)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            handleSearchSubmit()
                        }

                    // 搜尋中的 loading 動畫
                    if searchCompleter.isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                            .transition(.scale.combined(with: .opacity))
                    }

                    if !searchText.isEmpty {
                        Button {
                            clearSearchText()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 16))
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .padding(.horizontal, isExpanded ? 16 : 12)
        .padding(.vertical, isExpanded ? 10 : 12)
        .frame(maxWidth: isExpanded ? .infinity : 44)
        .frame(height: 44)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(
            color: Color.appOverlay.opacity(0.2),
            radius: 8,
            x: 0,
            y: 2
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isTextFieldFocused)
        .animation(.easeInOut(duration: 0.15), value: searchText.isEmpty)
        .animation(.easeInOut(duration: 0.15), value: searchCompleter.isSearching)
    }

    // MARK: - Suggestions Dropdown

    private var suggestionsDropdown: some View {
        VStack(spacing: 0) {
            if searchCompleter.isSearching {
                // 搜尋中顯示 loading
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
            } else if searchCompleter.suggestions.isEmpty {
                // 搜尋結束後沒有建議地點
                Text("沒有建議地點")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
            } else {
                // 建議列表 - 根據內容數量調整高度
                let itemHeight: CGFloat = 60 // 每個項目的大約高度
                let maxVisibleItems = 5 // 最多顯示 5 個項目
                let contentHeight = CGFloat(searchCompleter.suggestions.count) * itemHeight
                let maxHeight: CGFloat = CGFloat(maxVisibleItems) * itemHeight
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(searchCompleter.suggestions.enumerated()), id: \.offset) {
                            index, completion in
                            suggestionRow(
                                for: completion,
                                isLast: index == searchCompleter.suggestions.count - 1)
                        }
                    }
                }
                .frame(height: min(contentHeight, maxHeight))
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.appOverlay.opacity(0.15), radius: 8, x: 0, y: 2)
    }

    // MARK: - Suggestion Row

    @ViewBuilder
    private func suggestionRow(for completion: MKLocalSearchCompletion, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            Button {
                selectSuggestion(completion)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(SearchSuggestion(completion: completion).highlightedTitle)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if !completion.subtitle.isEmpty {
                            Text(SearchSuggestion(completion: completion).highlightedSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Image(systemName: "arrow.up.left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isLast {
                Divider()
                    .padding(.leading, 48)
            }
        }
    }

    // MARK: - Actions
    
    /// 展開搜尋欄
    private func expandSearch() {
        isExpanded = true
        // 延遲觸發鍵盤，讓展開動畫先完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isTextFieldFocused = true
        }
    }
    
    /// 收合搜尋欄
    private func collapseSearch() {
        isTextFieldFocused = false
        isExpanded = false
        clearSearch()
    }
    
    /// 清除搜尋文字（但不改變展開狀態）
    private func clearSearchText() {
        searchText = ""
        searchCompleter.clearResults()
        onSearchCleared()
    }

    private func selectSuggestion(_ completion: MKLocalSearchCompletion) {
        // 更新搜尋文字
        searchText = completion.title

        // 關閉鍵盤和建議列表
        isTextFieldFocused = false
        searchCompleter.clearResults()

        // 取得搜尋結果並導航
        Task {
            if let result = await searchCompleter.getSearchResult(for: completion) {
                await onSearchResultSelected(result)
            }
        }
    }

    private func handleSearchSubmit() {
        // 如果有建議，選擇第一個
        if let firstSuggestion = searchCompleter.suggestions.first {
            selectSuggestion(firstSuggestion)
        }

        isTextFieldFocused = false
    }

    private func clearSearch() {
        searchText = ""
        searchCompleter.clearResults()
        isSearchActive = false
        onSearchCleared()
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appDisabled.opacity(0.3)
            .ignoresSafeArea()

        VStack {
            MapSearchBar(
                searchText: .constant(""),
                isSearchActive: .constant(false),
                isExpanded: .constant(false),
                mapRegion: MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 25.0330, longitude: 121.5654),
                    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                ),
                onSearchResultSelected: { _ in },
                onSearchCleared: {}
            )
            .padding()
            Spacer()
        }
    }
}
