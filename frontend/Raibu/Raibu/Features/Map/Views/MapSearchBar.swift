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
        VStack(spacing: 0) {
            // 搜尋輸入框
            searchField

            // 搜尋建議下拉選單
            if showSuggestions {
                suggestionsDropdown
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .animation(.easeInOut(duration: 0.2), value: showSuggestions)
        .onChange(of: searchText) { _, newValue in
            searchCompleter.updateQuery(newValue, in: mapRegion)
            // 當搜尋文字被清空時，清除地圖上的搜尋標記
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
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 16, weight: .medium))

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
                    clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 16))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.1), radius: 5)
        .animation(.easeInOut(duration: 0.15), value: searchText.isEmpty)
        .animation(.easeInOut(duration: 0.15), value: searchCompleter.isSearching)
    }

    // MARK: - Suggestions Dropdown

    private var suggestionsDropdown: some View {
        VStack(spacing: 0) {
            if searchCompleter.isSearching {
                // 搜尋中顯示 loading
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchCompleter.suggestions.isEmpty {
                // 搜尋結束後沒有建議地點
                Text("沒有建議地點")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 建議列表
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
            }
        }
        .frame(maxHeight: 250)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.1), radius: 5)
        .padding(.top, 4)
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
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        VStack {
            MapSearchBar(
                searchText: .constant("台北"),
                isSearchActive: .constant(false),
                mapRegion: MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 25.0330, longitude: 121.5654),
                    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                ),
                onSearchResultSelected: { _ in },
                onSearchCleared: {}
            )
            Spacer()
        }
    }
}
