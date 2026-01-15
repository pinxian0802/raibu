//
//  MapSearchCompleter.swift
//  Raibu
//
//  地圖搜尋服務，負責地點搜尋與自動完成
//

import Foundation
import MapKit
import SwiftUI

// MARK: - Search Result

/// 搜尋結果
struct SearchResult {
    let coordinate: CLLocationCoordinate2D
    let mapItem: MKMapItem
    let adjustedRegion: MKCoordinateRegion
}

// MARK: - Search Suggestion

/// 搜尋建議（用於高亮顯示）
struct SearchSuggestion {
    let completion: MKLocalSearchCompletion

    var highlightedTitle: AttributedString {
        var attributedString = AttributedString(completion.title)
        for range in completion.titleHighlightRanges {
            if let swiftRange = Range(range.rangeValue, in: attributedString) {
                attributedString[swiftRange].font = .body.bold()
            }
        }
        return attributedString
    }

    var highlightedSubtitle: AttributedString {
        var attributedString = AttributedString(completion.subtitle)
        for range in completion.subtitleHighlightRanges {
            if let swiftRange = Range(range.rangeValue, in: attributedString) {
                attributedString[swiftRange].font = .caption.bold()
            }
        }
        return attributedString
    }
}

// MARK: - Map Search Completer

/// 地圖搜尋自動完成服務
@Observable
class MapSearchCompleter: NSObject {
    var suggestions: [MKLocalSearchCompletion] = []
    var isSearching = false
    var hasSearched = false  // 是否已執行過搜尋（用於顯示空狀態）

    private let completer = MKLocalSearchCompleter()
    private var currentQuery = ""
    private var debounceTask: Task<Void, Never>?

    /// Debounce 延遲時間（奈秒）
    private let debounceDelay: UInt64 = 500_000_000  // 500ms

    override init() {
        super.init()
        completer.delegate = self
    }

    /// 更新搜尋查詢（帶 Debounce）
    func updateQuery(_ query: String, in region: MKCoordinateRegion) {
        // 取消之前的 debounce 任務
        debounceTask?.cancel()

        // 如果輸入為空，立即清除結果
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            suggestions = []
            isSearching = false
            hasSearched = false
            currentQuery = ""
            completer.queryFragment = ""
            print("📝 輸入已清空，清除建議列表")
            return
        }

        // 新輸入開始時：重置狀態，準備新的搜尋
        hasSearched = false
        isSearching = true  // 顯示「搜尋中...」

        // 儲存當前的 region（避免在 Task 中使用外部變數問題）
        let searchRegion = region
        let searchQuery = query

        // 使用 debounce：等待使用者停止輸入後才執行搜尋
        debounceTask = Task { @MainActor in
            do {
                // 等待指定的延遲時間（500ms）
                try await Task.sleep(nanoseconds: debounceDelay)

                // 如果任務沒有被取消，執行搜尋
                currentQuery = searchQuery
                completer.region = searchRegion
                completer.queryFragment = searchQuery
                print("🔎 Debounce 完成，開始搜尋: \(searchQuery)")
            } catch {
                // 任務被取消（使用者繼續輸入）
                print("⏸️ 搜尋被取消（使用者仍在輸入）: \(searchQuery)")
            }
        }
    }

    /// 清除搜尋結果
    func clearResults() {
        suggestions = []
        currentQuery = ""
        isSearching = false
        hasSearched = false
    }

    /// 取得搜尋結果的詳細資訊
    func getSearchResult(for completion: MKLocalSearchCompletion) async -> SearchResult? {
        print("\n🔍 ====== 開始解析搜尋結果 ======")
        print("選擇的建議: \(completion.title)")
        print("副標題: \(completion.subtitle)")

        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()

            print("\n📍 MKLocalSearch 回傳結果:")
            print("總共 \(response.mapItems.count) 個結果")

            for (index, item) in response.mapItems.enumerated() {
                print("  [\(index)] 名稱: \(item.name ?? "nil")")
                print(
                    "       座標: (\(item.placemark.coordinate.latitude), \(item.placemark.coordinate.longitude))"
                )
                print("       地址: \(item.placemark.title ?? "nil")")
                if let category = item.pointOfInterestCategory {
                    print("       POI類別: \(category.rawValue)")
                }
            }

            guard let mapItem = response.mapItems.first else {
                print("⚠️ 沒有找到結果")
                return nil
            }

            let coordinate = mapItem.placemark.coordinate

            // 根據地點類型調整縮放等級
            let span = calculateSpan(for: mapItem)
            let adjustedRegion = MKCoordinateRegion(center: coordinate, span: span)

            print("\n✅ 使用第一個結果: \(mapItem.name ?? "nil")")
            print("縮放等級: \(span.latitudeDelta)")
            print("====== 解析完成 ======\n")

            return SearchResult(
                coordinate: coordinate,
                mapItem: mapItem,
                adjustedRegion: adjustedRegion
            )
        } catch {
            print("❌ Search error: \(error)")
            return nil
        }
    }

    /// 根據地點類型計算適當的縮放等級
    private func calculateSpan(for mapItem: MKMapItem) -> MKCoordinateSpan {
        // 預設縮放等級（適合一般地點）
        var delta = 0.01

        // 根據地點類型調整
        if let category = mapItem.pointOfInterestCategory {
            switch category {
            case .airport:
                delta = 0.05
            case .nationalPark, .park:
                delta = 0.02
            case .university:
                delta = 0.015
            default:
                delta = 0.008
            }
        }

        // 如果是城市級別的地點（沒有具體名稱）
        if mapItem.name == nil || mapItem.name == mapItem.placemark.locality {
            delta = 0.1
        }

        return MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension MapSearchCompleter: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // 過濾掉查詢型建議（Query Suggestions），只保留具體地點（POI）
        // 查詢型建議的特徵是副標題包含「搜尋附近」這類提示文字
        let filteredResults = completer.results.filter { result in
            !result.subtitle.contains("搜尋附近")
        }

        suggestions = filteredResults
        isSearching = false
        hasSearched = true  // 標記已執行過搜尋

        // 詳細 Log 輸出
        print("\n📝 ====== 搜尋建議更新 ======")
        print("查詢文字: \(currentQuery)")
        print("原始結果: \(completer.results.count) 個，過濾後: \(filteredResults.count) 個")

        for (index, result) in filteredResults.enumerated() {
            print("  [\(index)] \(result.title)")
            print("       副標題: \(result.subtitle)")
        }
        print("==============================\n")
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error)")
        isSearching = false
    }
}
