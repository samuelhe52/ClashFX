//
//  Settings.swift
//  ClashX
//
//  Created by yicheng on 2020/12/18.
//  Copyright © 2020 west2online. All rights reserved.
//

import Foundation

enum Settings {
    static let defaultMmdbDownloadUrl = "https://github.com/MetaCubeX/meta-rules-dat/releases/latest/download/geoip.metadb"
    @UserDefault("mmdbDownloadUrl", defaultValue: defaultMmdbDownloadUrl)
    static var mmdbDownloadUrl: String

    @UserDefault("filterInterface", defaultValue: true)
    static var filterInterface: Bool

    @UserDefault("disableNoti", defaultValue: false)
    static var disableNoti: Bool

    @UserDefault("configAutoUpdateInterval", defaultValue: 48 * 60 * 60)
    static var configAutoUpdateInterval: TimeInterval

    static let proxyIgnoreListDefaultValue = ["192.168.0.0/16",
                                              "10.0.0.0/8",
                                              "172.16.0.0/12",
                                              "127.0.0.1",
                                              "localhost",
                                              "*.local",
                                              "timestamp.apple.com",
                                              "sequoia.apple.com",
                                              "seed-sequoia.siri.apple.com"]
    @UserDefault("proxyIgnoreList", defaultValue: proxyIgnoreListDefaultValue)
    static var proxyIgnoreList: [String]

    @UserDefault("tunRouteExcludeList", defaultValue: [])
    static var tunRouteExcludeList: [String]

    @UserDefault("tunRouteExcludeRawText", defaultValue: "")
    static var tunRouteExcludeRawText: String

    static func normalizeTunRouteExcludeEntries(_ entries: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for entry in entries {
            let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let normalized = legacyWildcardTunRouteExcludeEntry(trimmed) ?? trimmed
            guard seen.insert(normalized).inserted else { continue }
            result.append(normalized)
        }
        return result
    }

    static func normalizeAndPersistTunRouteExcludeList() -> [String] {
        let rawEntries = tunRouteExcludeRawText
            .components(separatedBy: CharacterSet(charactersIn: ",\n\r"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let source = rawEntries.isEmpty ? tunRouteExcludeList : rawEntries
        let normalized = normalizeTunRouteExcludeEntries(source)
        if normalized != tunRouteExcludeList {
            tunRouteExcludeList = normalized
        }
        if !rawEntries.isEmpty && normalized != rawEntries {
            tunRouteExcludeRawText = normalized.joined(separator: ",\n")
        }
        return normalized
    }

    private static func legacyWildcardTunRouteExcludeEntry(_ entry: String) -> String? {
        if entry == "10.*" {
            return "10.0.0.0/8"
        }
        if entry == "192.168.*" {
            return "192.168.0.0/16"
        }
        guard entry.hasPrefix("172."), entry.hasSuffix(".*") else {
            return nil
        }
        let components = entry.split(separator: ".")
        guard components.count == 3,
              let secondOctet = Int(components[1]),
              (16 ... 31).contains(secondOctet) else {
            return nil
        }
        return "172.\(secondOctet).0.0/16"
    }

    static let defaultTunMTU = 1500
    static let minTunMTU = 1280
    static let maxTunMTU = 9000
    @UserDefault("tunMTU", defaultValue: defaultTunMTU)
    static var tunMTU: Int {
        didSet {
            if tunMTU < minTunMTU || tunMTU > maxTunMTU {
                tunMTU = defaultTunMTU
            }
        }
    }

    @UserDefault("tunInterfaceName", defaultValue: "")
    static var tunInterfaceName: String

    @UserDefault("disableMenubarNotice", defaultValue: false)
    static var disableMenubarNotice: Bool

    @UserDefault("proxyPort", defaultValue: 0)
    static var proxyPort: Int

    @UserDefault("apiPort", defaultValue: 0)
    static var apiPort: Int

    @UserDefault("apiPortAllowLan", defaultValue: false)
    static var apiPortAllowLan: Bool

    @UserDefault("disableSSIDList", defaultValue: [])
    static var disableSSIDList: [String]

    @UserDefault("enableIPV6", defaultValue: false)
    static var enableIPV6: Bool

    static let apiSecretKey = "api-secret"

    static var isApiSecretSet: Bool {
        return UserDefaults.standard.object(forKey: apiSecretKey) != nil
    }

    @UserDefault(apiSecretKey, defaultValue: "")
    static var apiSecret: String

    @UserDefault("overrideConfigSecret", defaultValue: false)
    static var overrideConfigSecret: Bool

    @UserDefault("kBuiltInApiMode", defaultValue: true)
    static var builtInApiMode: Bool

    static let disableShowCurrentProxyInMenu = !AppDelegate.isAboveMacOS14

    static let defaultBenchmarkUrl = "http://cp.cloudflare.com/generate_204"
    @UserDefault("benchMarkUrl", defaultValue: defaultBenchmarkUrl)
    static var benchMarkUrl: String {
        didSet {
            if benchMarkUrl.isEmpty {
                benchMarkUrl = defaultBenchmarkUrl
            }
        }
    }

    @UserDefault("kDisableRestoreProxy", defaultValue: false)
    static var disableRestoreProxy: Bool

    @UserDefault("enhancedMode", defaultValue: false)
    static var enhancedMode: Bool

    @UserDefault("appLanguage", defaultValue: "")
    static var appLanguage: String
}
