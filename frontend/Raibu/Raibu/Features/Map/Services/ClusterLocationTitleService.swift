//
//  ClusterLocationTitleService.swift
//  Raibu
//
//  Build location-aware titles for cluster list sheet.
//

import Foundation
import CoreLocation

struct LocationTitleParts: Equatable {
    let primary: String
    let secondary: String?
}

@MainActor
final class ClusterLocationTitleService {
    static let shared = ClusterLocationTitleService()

    private let geocoder = CLGeocoder()
    private var componentsCache: [String: PlaceComponents] = [:]
    private var titleCache: [String: LocationTitleParts] = [:]

    private init() {}

    func buildTitleParts(
        for coordinates: [CLLocationCoordinate2D],
        mapSpanLatitudeDelta: Double
    ) async -> LocationTitleParts {
        let uniqueCoordinates = deduplicateCoordinates(coordinates)
        guard !uniqueCoordinates.isEmpty else {
            return LocationTitleParts(primary: "重疊標點", secondary: nil)
        }

        let rangeKilometers = diagonalDistanceKilometers(of: uniqueCoordinates)
        // 將地圖 span 換算為公里（1° 緯度 ≈ 111 km），取較大值決定精度
        let mapSpanKM = mapSpanLatitudeDelta * 111.0
        let effectiveRangeKM = max(rangeKilometers, mapSpanKM)
        let level = titleLevel(for: effectiveRangeKM)
        let cacheKey = makeTitleCacheKey(level: level, coordinates: uniqueCoordinates)
        if let cachedTitle = titleCache[cacheKey] {
            return cachedTitle
        }

        let sampledCoordinates = sampleCoordinates(uniqueCoordinates, maxCount: 6)
        var componentsList: [PlaceComponents] = []

        for coordinate in sampledCoordinates {
            let key = coordinateKey(coordinate)
            if let cached = componentsCache[key] {
                componentsList.append(cached)
                continue
            }

            if let components = await reverseGeocodeComponents(for: coordinate) {
                componentsCache[key] = components
                componentsList.append(components)
            }
        }

        let titleParts = composeTitleParts(
            from: componentsList,
            level: level,
            fallbackRangeKM: effectiveRangeKM
        )
        titleCache[cacheKey] = titleParts
        return titleParts
    }

    private func reverseGeocodeComponents(for coordinate: CLLocationCoordinate2D) async -> PlaceComponents? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(
                location,
                preferredLocale: Locale(identifier: "zh_Hant_TW")
            )
            guard let placemark = placemarks.first else { return nil }
            return extractPlaceComponents(from: placemark)
        } catch {
            return nil
        }
    }

    private func extractPlaceComponents(from placemark: CLPlacemark) -> PlaceComponents {
        let country = normalizedName(placemark.country)
        let city: String?
        let district: String?
        let subDistrict: String?

        if placemark.isoCountryCode == "TW" {
            city = normalizedName(placemark.administrativeArea ?? placemark.locality ?? placemark.subAdministrativeArea)
            district = normalizedName(placemark.locality)
            subDistrict = normalizedName(placemark.subLocality)
        } else {
            city = normalizedName(placemark.locality ?? placemark.administrativeArea)
            district = normalizedName(placemark.subAdministrativeArea)
            subDistrict = normalizedName(placemark.subLocality)
        }

        return PlaceComponents(country: country, city: city, district: district, subDistrict: subDistrict)
    }

    private func composeTitleParts(
        from componentsList: [PlaceComponents],
        level: TitleLevel,
        fallbackRangeKM: Double
    ) -> LocationTitleParts {
        let cityCounts = countNames(componentsList.compactMap(\.city))

        switch level {
        case .countries:
            // 列出國家為 primary，城市列為 secondary
            let countryCounts = countNames(componentsList.compactMap(\.country))
            let uniqueCountries = topNames(from: countryCounts, limit: 4)
            let totalCountryCount = countryCounts.count

            if uniqueCountries.count == 1 {
                // 只有一個國家，往下列出城市
                let country = uniqueCountries[0]
                let totalCityCount = cityCounts.count
                let uniqueCities = topNames(from: cityCounts, limit: 4)
                if !uniqueCities.isEmpty {
                    return LocationTitleParts(
                        primary: country,
                        secondary: joinedWithEllipsis(uniqueCities, totalCount: totalCityCount)
                    )
                }
                return LocationTitleParts(primary: country, secondary: nil)
            }

            if !uniqueCountries.isEmpty {
                return LocationTitleParts(
                    primary: joinedWithEllipsis(uniqueCountries, totalCount: totalCountryCount),
                    secondary: nil
                )
            }

        case .cities:
            let uniqueCities = topNames(from: cityCounts, limit: 4)
            let totalCityCount = cityCounts.count

            if uniqueCities.count == 1 {
                // 只有一個城市時，往下列出區
                let city = uniqueCities[0]
                let districts = componentsList
                    .filter { $0.city == city }
                    .compactMap(\.district)
                let districtCounts = countNames(districts)
                let uniqueDistricts = topNames(from: districtCounts, limit: 4)
                if !uniqueDistricts.isEmpty {
                    return LocationTitleParts(
                        primary: city,
                        secondary: joinedWithEllipsis(uniqueDistricts, totalCount: districtCounts.count)
                    )
                }
                // 沒有區的話，用國家 + 城市
                if let country = componentsList.first(where: { $0.city == city })?.country {
                    return LocationTitleParts(primary: country, secondary: city)
                }
                return LocationTitleParts(primary: city, secondary: nil)
            }

            if !uniqueCities.isEmpty {
                return LocationTitleParts(
                    primary: joinedWithEllipsis(uniqueCities, totalCount: totalCityCount),
                    secondary: nil
                )
            }

        case .cityDistrict:
            if let dominantCity = topNames(from: cityCounts, limit: 1).first {
                let districts = componentsList
                    .filter { $0.city == dominantCity }
                    .compactMap(\.district)
                let districtCounts = countNames(districts)
                let uniqueDistricts = topNames(from: districtCounts, limit: 4)
                if !uniqueDistricts.isEmpty {
                    return LocationTitleParts(
                        primary: dominantCity,
                        secondary: joinedWithEllipsis(uniqueDistricts, totalCount: districtCounts.count)
                    )
                }
                return LocationTitleParts(primary: dominantCity, secondary: nil)
            }

        case .districtSubDistrict:
            let districtCounts = countNames(componentsList.compactMap(\.district))
            if let dominantDistrict = topNames(from: districtCounts, limit: 1).first {
                let subDistricts = componentsList
                    .filter { $0.district == dominantDistrict }
                    .compactMap(\.subDistrict)
                let subDistrictCounts = countNames(subDistricts)
                let uniqueSubDistricts = topNames(from: subDistrictCounts, limit: 4)
                if !uniqueSubDistricts.isEmpty {
                    return LocationTitleParts(
                        primary: dominantDistrict,
                        secondary: joinedWithEllipsis(uniqueSubDistricts, totalCount: subDistrictCounts.count)
                    )
                }
                // fallback: 用 city + district
                if let city = componentsList.first(where: { $0.district == dominantDistrict })?.city {
                    return LocationTitleParts(primary: city, secondary: dominantDistrict)
                }
                return LocationTitleParts(primary: dominantDistrict, secondary: nil)
            }
        }

        return fallbackParts(forRangeKM: fallbackRangeKM)
    }

    /// 用「、」串接名稱，超過顯示數量時加上「...」
    private func joinedWithEllipsis(_ names: [String], totalCount: Int) -> String {
        let joined = names.joined(separator: "、")
        return totalCount > names.count ? joined + "..." : joined
    }

    private func topPair(from pairs: [Pair]) -> Pair? {
        guard !pairs.isEmpty else { return nil }

        var counts: [String: Int] = [:]
        for pair in pairs {
            counts[pair.cacheKey, default: 0] += 1
        }

        let top = counts.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return lhs.key > rhs.key
        }?.key

        guard let top else { return nil }
        let components = top.split(separator: "|", maxSplits: 1).map(String.init)
        guard components.count == 2 else { return nil }
        return Pair(primary: components[0], secondary: components[1])
    }

    private func countNames(_ names: [String]) -> [String: Int] {
        var result: [String: Int] = [:]
        for name in names {
            result[name, default: 0] += 1
        }
        return result
    }

    private func topNames(from counts: [String: Int], limit: Int) -> [String] {
        counts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .prefix(limit)
            .map(\.key)
    }

    private func fallbackParts(forRangeKM rangeKM: Double) -> LocationTitleParts {
        if rangeKM > 120 {
            return LocationTitleParts(primary: "大範圍", secondary: "重疊標點")
        }
        if rangeKM > 30 {
            return LocationTitleParts(primary: "跨城市", secondary: "重疊標點")
        }
        if rangeKM > 5 {
            return LocationTitleParts(primary: "區域", secondary: "重疊標點")
        }
        return LocationTitleParts(primary: "附近", secondary: "重疊標點")
    }

    private func deduplicateCoordinates(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        var seen = Set<String>()
        var unique: [CLLocationCoordinate2D] = []

        for coordinate in coordinates {
            let key = coordinateKey(coordinate)
            if seen.insert(key).inserted {
                unique.append(coordinate)
            }
        }

        return unique.sorted {
            if $0.latitude != $1.latitude { return $0.latitude < $1.latitude }
            return $0.longitude < $1.longitude
        }
    }

    private func sampleCoordinates(_ coordinates: [CLLocationCoordinate2D], maxCount: Int) -> [CLLocationCoordinate2D] {
        guard coordinates.count > maxCount else { return coordinates }
        guard maxCount > 1 else { return [coordinates[0]] }

        var sampled: [CLLocationCoordinate2D] = []
        let step = Double(coordinates.count - 1) / Double(maxCount - 1)

        for index in 0..<maxCount {
            let coordinateIndex = Int((Double(index) * step).rounded())
            sampled.append(coordinates[min(coordinateIndex, coordinates.count - 1)])
        }
        return sampled
    }

    private func diagonalDistanceKilometers(of coordinates: [CLLocationCoordinate2D]) -> Double {
        guard let first = coordinates.first else { return 0 }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLng = first.longitude
        var maxLng = first.longitude

        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLng = min(minLng, coordinate.longitude)
            maxLng = max(maxLng, coordinate.longitude)
        }

        let topLeft = CLLocation(latitude: maxLat, longitude: minLng)
        let bottomRight = CLLocation(latitude: minLat, longitude: maxLng)
        return topLeft.distance(from: bottomRight) / 1_000
    }

    private func titleLevel(for rangeKM: Double) -> TitleLevel {
        if rangeKM > 120 { return .countries }
        if rangeKM > 30 { return .cities }
        if rangeKM > 5 { return .cityDistrict }
        return .districtSubDistrict
    }

    private func coordinateKey(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }

    private func makeTitleCacheKey(level: TitleLevel, coordinates: [CLLocationCoordinate2D]) -> String {
        let keys = coordinates.map(coordinateKey).joined(separator: "|")
        return "\(level.rawValue)|\(keys)"
    }

    private func normalizedName(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.replacingOccurrences(of: "臺", with: "台")
    }
}

private struct PlaceComponents {
    let country: String?
    let city: String?
    let district: String?
    let subDistrict: String?
}

private struct Pair {
    let primary: String
    let secondary: String

    var cacheKey: String {
        "\(primary)|\(secondary)"
    }
}

private enum TitleLevel: String {
    case countries
    case cities
    case cityDistrict
    case districtSubDistrict
}
