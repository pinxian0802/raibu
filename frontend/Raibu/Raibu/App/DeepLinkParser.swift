//
//  DeepLinkParser.swift
//  Raibu
//
//  Parse incoming URLs into app destinations.
//

import Foundation

enum DeepLinkParser {
    /// 解析 URL 為詳情路由
    static func parseDetailRoute(from url: URL) -> DetailSheetRoute? {
        // 不攔截 Supabase auth callback（raibu://auth-callback#...）
        if isAuthCallback(url) {
            return nil
        }

        let scheme = (url.scheme ?? "").lowercased()
        let host = (url.host ?? "").lowercased()
        let pathParts = url.pathComponents.filter { $0 != "/" }

        if scheme == "raibu" {
            return parseCustomScheme(host: host, pathParts: pathParts, url: url)
        }

        if scheme == "https" || scheme == "http" {
            return parseUniversalLink(host: host, pathParts: pathParts, url: url)
        }

        return nil
    }

    private static func parseCustomScheme(host: String, pathParts: [String], url: URL) -> DetailSheetRoute? {
        switch host {
        case "record":
            guard let id = pathParts.first, !id.isEmpty else { return nil }
            let imageIndex = queryInt(name: "imageIndex", in: url) ?? 0
            return .record(id: id, imageIndex: max(0, imageIndex))
        case "ask":
            guard let id = pathParts.first, !id.isEmpty else { return nil }
            return .ask(id: id)
        case "user":
            guard let id = pathParts.first, !id.isEmpty else { return nil }
            return .userProfile(id: id)
        default:
            return nil
        }
    }

    private static func parseUniversalLink(host: String, pathParts: [String], url: URL) -> DetailSheetRoute? {
        let supportedHosts = Set(["raibu.app", "www.raibu.app"])
        guard supportedHosts.contains(host) else { return nil }

        guard let entity = pathParts.first?.lowercased(), pathParts.count >= 2 else { return nil }
        let id = pathParts[1]
        guard !id.isEmpty else { return nil }

        switch entity {
        case "record":
            let imageIndex = queryInt(name: "imageIndex", in: url) ?? 0
            return .record(id: id, imageIndex: max(0, imageIndex))
        case "ask":
            return .ask(id: id)
        case "user":
            return .userProfile(id: id)
        default:
            return nil
        }
    }

    private static func queryInt(name: String, in url: URL) -> Int? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
            .flatMap(Int.init)
    }

    private static func isAuthCallback(_ url: URL) -> Bool {
        let scheme = (url.scheme ?? "").lowercased()
        let host = (url.host ?? "").lowercased()
        guard scheme == "raibu", host == "auth-callback" else { return false }
        return url.fragment != nil
    }
}

