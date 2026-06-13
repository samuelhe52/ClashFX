//
//  RemoteConfigManager.swift
//  ClashX
//
//  Created by yicheng on 2018/11/6.
//  Copyright © 2018 west2online. All rights reserved.
//

import Alamofire
import Cocoa

class RemoteConfigManager {
    private static let generatedShareLinkTemplateVersion = 8
    private static let generatedShareLinkMarker = "clashfx-generated: share-links"
    private static let shareLinkSchemes = [
        "ss://", "vmess://", "trojan://", "vless://",
        "hysteria://", "hysteria2://", "hy2://",
        "tuic://", "ssr://", "socks://", "socks5://", "socks5h://",
        "http://", "https://", "anytls://", "mierus://"
    ]

    var configs: [RemoteConfigModel] = []
    var refreshActivity: NSBackgroundActivityScheduler?

    static let shared = RemoteConfigManager()

    private init() {
        if let savedConfigs = UserDefaults.standard.object(forKey: "kRemoteConfigs") as? Data {
            let decoder = JSONDecoder()
            if let loadedConfig = try? decoder.decode([RemoteConfigModel].self, from: savedConfigs) {
                configs = loadedConfig
            } else {
                assertionFailure()
            }
        }
        migrateOldRemoteConfig()
        setupAutoUpdateTimer()
    }

    func saveConfigs() {
        Logger.log("Saving Remote Config Setting")
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(configs) {
            UserDefaults.standard.set(encoded, forKey: "kRemoteConfigs")
        }
    }

    func migrateOldRemoteConfig() {
        if let url = UserDefaults.standard.string(forKey: "kRemoteConfigUrl"),
           let name = URL(string: url)?.host {
            configs.append(RemoteConfigModel(url: url, name: name))
            UserDefaults.standard.removeObject(forKey: "kRemoteConfigUrl")
            saveConfigs()
        }
    }

    func setupAutoUpdateTimer() {
        refreshActivity?.invalidate()
        refreshActivity = nil
        guard RemoteConfigManager.autoUpdateEnable else {
            Logger.log("autoUpdateEnable did not enable,autoUpateTimer invalidated.")
            return
        }
        Logger.log("set up autoUpateTimer")

        refreshActivity = NSBackgroundActivityScheduler(identifier: "com.clashfx.configupdate")
        refreshActivity?.repeats = true
        refreshActivity?.interval = 60 * 60 * 2 // Two hour
        refreshActivity?.tolerance = 60 * 60

        refreshActivity?.schedule { [weak self] completionHandler in
            self?.autoUpdateCheck()
            completionHandler(NSBackgroundActivityScheduler.Result.finished)
        }
    }

    static var autoUpdateEnable: Bool {
        get {
            return UserDefaults.standard.object(forKey: "kAutoUpdateEnable") as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "kAutoUpdateEnable")
            RemoteConfigManager.shared.setupAutoUpdateTimer()
        }
    }

    @objc func autoUpdateCheck() {
        guard RemoteConfigManager.autoUpdateEnable else { return }
        Logger.log("Tigger config auto update check")
        updateCheck()
    }

    func updateCheck(ignoreTimeLimit: Bool = false, showNotification: Bool = false) {
        let currentConfigName = ConfigManager.selectConfigName

        let group = DispatchGroup()

        for config in configs {
            if config.updating { continue }
            let timeLimitNoMantians = Date().timeIntervalSince(config.updateTime ?? Date(timeIntervalSince1970: 0)) < Settings.configAutoUpdateInterval

            if timeLimitNoMantians && !ignoreTimeLimit {
                Logger.log("[Auto Upgrade] Bypassing \(config.name) due to time check")
                continue
            }
            Logger.log("[Auto Upgrade] Requesting \(config.name)")
            let isCurrentConfig = config.name == currentConfigName
            config.updating = true
            group.enter()
            RemoteConfigManager.updateConfig(config: config) {
                [weak config] error in
                guard let config = config else { return }

                config.updating = false
                group.leave()
                if error == nil {
                    config.updateTime = Date()
                }

                if isCurrentConfig {
                    if let error = error {
                        // Fail
                        if showNotification {
                            NSUserNotificationCenter.default
                                .post(title: NSLocalizedString("Remote Config Update Fail", comment: ""),
                                      info: "\(config.name): \(error)")
                        }

                    } else {
                        // Success
                        if showNotification {
                            let info = "\(config.name): \(NSLocalizedString("Succeed!", comment: ""))"
                            NSUserNotificationCenter.default
                                .post(title: NSLocalizedString("Remote Config Update", comment: ""), info: info)
                        }
                        AppDelegate.shared.updateConfig(showNotification: false)
                    }
                }
                Logger.log("[Auto Upgrade] Finish \(config.name) result: \(error ?? "succeed")")
            }
        }

        group.notify(queue: .main) {
            [weak self] in
            self?.saveConfigs()
        }
    }

    /// User-Agent used for remote subscription downloads.
    ///
    /// Some providers return legacy-only configs for ClashX-like clients.
    /// ClashFX ships a mihomo-based core, so advertise Clash Meta by default.
    private static let subscriptionUserAgent = "clash.meta/v1.19.24"

    static func getRemoteConfigData(config: RemoteConfigModel, complete: @escaping ((String?, String?, [AnyHashable: Any]?) -> Void)) {
        guard var urlRequest = try? URLRequest(url: config.url, method: .get) else {
            assertionFailure()
            Logger.log("[getRemoteConfigData] url incorrect,\(config.name) \(config.url)")
            return
        }
        urlRequest.cachePolicy = .reloadIgnoringCacheData
        let userAgent = config.userAgent?.trimmingCharacters(in: .whitespacesAndNewlines)
        urlRequest.setValue(userAgent?.isEmpty == false ? userAgent : subscriptionUserAgent,
                            forHTTPHeaderField: "User-Agent")

        AF.request(urlRequest)
            .validate()
            .responseString(encoding: .utf8) { res in
                complete(try? res.result.get(), res.response?.suggestedFilename, res.response?.allHeaderFields)
            }
    }

    static func parseSubscriptionUserinfoHeader(_ headers: [AnyHashable: Any]?) -> SubscriptionInfo? {
        guard let headers else { return nil }
        let raw = headers.first { key, _ in
            (key as? String)?.lowercased() == "subscription-userinfo"
        }?.value as? String
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        var info = SubscriptionInfo()
        for pair in value.split(separator: ";") {
            let trimmed = pair.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            let val = parts[1].trimmingCharacters(in: .whitespaces)
            switch key {
            case "upload": info.upload = Int64(val)
            case "download": info.download = Int64(val)
            case "total": info.total = Int64(val)
            case "expire":
                if let seconds = TimeInterval(val), seconds > 0 {
                    info.expire = seconds
                }
            default: break
            }
        }
        return info.hasAnyData ? info : nil
    }

    static func parseSubscriptionInfoFromBody(_ body: String) -> SubscriptionInfo? {
        var info = SubscriptionInfo()

        for line in body.split(whereSeparator: \.isNewline).map(String.init) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if let total = matchByteValue(in: trimmed, after: ["总流量", "Total Traffic", "Total"]) {
                info.total = total
            }
            if let used = matchByteValue(in: trimmed, after: ["已用流量", "Used", "已使用"]),
               info.upload == nil, info.download == nil {
                info.download = used
            }
            if let remaining = matchByteValue(in: trimmed, after: ["剩余流量", "Remaining Traffic", "Remaining"]),
               let total = info.total ?? matchByteValue(in: trimmed, after: ["总流量", "Total"]) {
                info.total = total
                if info.upload == nil, info.download == nil {
                    info.download = max(0, total - remaining)
                }
            }
            if let text = matchExpireText(in: trimmed) {
                info.expireText = text
            }
        }

        return info.hasAnyData ? info : nil
    }

    private static let byteUnitMultipliers: [(suffix: String, multiplier: Double)] = [
        ("PB", 1_125_899_906_842_624),
        ("TB", 1_099_511_627_776),
        ("GB", 1_073_741_824),
        ("MB", 1_048_576),
        ("KB", 1024),
        ("B", 1)
    ]

    private static func matchByteValue(in line: String, after labels: [String]) -> Int64? {
        for label in labels {
            guard let labelRange = line.range(of: label, options: .caseInsensitive) else { continue }
            let tail = line[labelRange.upperBound...]
            let scanner = Scanner(string: String(tail))
            scanner.charactersToBeSkipped = CharacterSet(charactersIn: " ：:=|/-\t")
            var number: Double = 0
            guard scanner.scanDouble(&number) else { continue }
            let remaining = scanner.string[scanner.string.index(scanner.string.startIndex, offsetBy: scanner.scanLocation)...]
            let upper = remaining.trimmingCharacters(in: .whitespaces).uppercased()
            for (suffix, multiplier) in byteUnitMultipliers where upper.hasPrefix(suffix) {
                return Int64(number * multiplier)
            }
            return Int64(number)
        }
        return nil
    }

    private static func matchExpireText(in line: String) -> String? {
        let labels = ["套餐到期", "到期时间", "Expire", "Expires", "Expiry"]
        for label in labels {
            guard let labelRange = line.range(of: label, options: .caseInsensitive) else { continue }
            let tail = line[labelRange.upperBound...]
                .trimmingCharacters(in: CharacterSet(charactersIn: " ：:=|/-\t"))
            guard !tail.isEmpty else { continue }
            return String(tail).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    static func tryDecodeBase64(_ string: String) -> String? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains("<html"),
              !trimmed.contains("<!DOCTYPE"),
              !trimmed.hasPrefix("{"),
              !trimmed.hasPrefix("port:"),
              !trimmed.hasPrefix("mixed-port:"),
              !trimmed.contains("proxies:"),
              !trimmed.contains("proxy-groups:"),
              !shareLinkSchemes.contains(where: { trimmed.hasPrefix($0) }) else {
            return nil
        }
        let base64Cleaned = trimmed
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padded = base64Cleaned.padding(toLength: ((base64Cleaned.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
        guard let data = Data(base64Encoded: padded, options: .ignoreUnknownCharacters),
              let decoded = String(data: data, encoding: .utf8) else {
            return nil
        }

        if decoded.contains("proxies:") || decoded.contains("proxy-groups:") || decoded.contains("port:") || decoded.contains("mixed-port:") {
            return decoded
        }

        if let generated = buildConfigFromShareLinks(decoded) {
            return generated
        }

        return decoded
    }

    // MARK: - Share link parsing

    private static func buildConfigFromShareLinks(_ decoded: String) -> String? {
        if let converted = buildConfigFromShareLinksUsingMihomo(decoded) {
            return converted
        }

        let lines = decoded
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }

        var proxies: [String] = []
        var names: [String] = []

        for line in lines {
            let candidate: String
            if shareLinkSchemes.contains(where: { line.hasPrefix($0) }) {
                candidate = line
            } else if let innerDecoded = decodeBase64ToString(line),
                      shareLinkSchemes.contains(where: { innerDecoded.hasPrefix($0) }) {
                candidate = innerDecoded
            } else {
                continue
            }

            guard let proxy = parseShareLink(candidate) else {
                continue
            }
            proxies.append(proxy.yaml)
            names.append("\"\(escapeYAML(proxy.name))\"")
        }

        guard !proxies.isEmpty else { return nil }

        let proxyList = names.joined(separator: ", ")
        let nameserverPolicy = nameserverPolicyYAML(from: proxies)
        return """
        # \(generatedShareLinkMarker)
        # clashfx-template-version: \(generatedShareLinkTemplateVersion)
        # This file was auto-generated by ClashFX from share-link subscriptions.
        # It is a compatibility config, not a user-authored rule file.
        mixed-port: 7890
        allow-lan: false
        bind-address: "*"
        mode: rule
        log-level: info
        ipv6: true
        udp: true
        unified-delay: true
        cfw-latency-timeout: 8000
        cfw-latency-url: "http://YouTube.com/generate_204"
        cfw-conn-break-strategy: true
        dns:
          enable: true
          listen: "127.0.0.1:1053"
          ipv6: true
          enhanced-mode: redir-host
          default-nameserver:
            - 114.114.114.114
            - 223.5.5.5
            - 119.29.29.29
          nameserver:
            - https://223.5.5.5/dns-query
            - https://doh.pub/dns-query
            - 119.29.29.29
            - 223.5.5.5
            - tls://223.5.5.5:853
            - tls://223.6.6.6:853
          fallback:
            - https://223.5.5.5/dns-query
            - https://doh.pub/dns-query
            - tls://1.1.1.1:853
            - tls://8.8.8.8:853
          fallback-filter:
            geoip: false
        \(nameserverPolicy)

        proxies:
        \(proxies.joined(separator: "\n"))

        proxy-groups:
          - name: "Proxy"
            type: select
            proxies: ["Auto", "DIRECT", \(proxyList)]
          - name: "Auto"
            type: url-test
            proxies: [\(proxyList)]
            url: "http://YouTube.com/generate_204"
            interval: 300
            tolerance: 200

        rules:
          - DOMAIN,localhost,DIRECT
          - DOMAIN-SUFFIX,local,DIRECT
          - DOMAIN-SUFFIX,cn,DIRECT
          - DOMAIN,www.baidu.com,DIRECT
          - DOMAIN,baidu.com,DIRECT
          - DOMAIN-KEYWORD,baidu,DIRECT
          - DOMAIN-SUFFIX,baidu.com,DIRECT
          - DOMAIN-SUFFIX,bdimg.com,DIRECT
          - DOMAIN-SUFFIX,bdstatic.com,DIRECT
          - IP-CIDR,127.0.0.0/8,DIRECT,no-resolve
          - IP-CIDR,10.0.0.0/8,DIRECT,no-resolve
          - IP-CIDR,172.16.0.0/12,DIRECT,no-resolve
          - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve
          - IP-CIDR,100.64.0.0/10,DIRECT,no-resolve
          - IP-CIDR,169.254.0.0/16,DIRECT,no-resolve
          - IP-CIDR,224.0.0.0/4,DIRECT,no-resolve
          - IP-CIDR6,::1/128,DIRECT,no-resolve
          - IP-CIDR6,fc00::/7,DIRECT,no-resolve
          - IP-CIDR6,fe80::/10,DIRECT,no-resolve
          - MATCH,Proxy
        """
    }

    private static func nameserverPolicyYAML(from proxyYAMLBlocks: [String]) -> String {
        let servers = proxyYAMLBlocks.compactMap { block -> String? in
            guard let line = block
                .split(whereSeparator: \.isNewline)
                .map(String.init)
                .first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("server:") }) else {
                return nil
            }
            let value = line
                .split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                .dropFirst()
                .joined(separator: ":")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard !value.isEmpty, !value.contains(":") else { return nil }
            let isIPv4 = value.split(separator: ".").count == 4 && value.allSatisfy { $0.isNumber || $0 == "." }
            return isIPv4 ? nil : value
        }
        let uniqueServers = Array(Set(servers)).sorted()
        guard !uniqueServers.isEmpty else { return "" }
        let policies = uniqueServers
            .map { "          \($0): \"https://223.5.5.5/dns-query\"" }
            .joined(separator: "\n")
        return """
          nameserver-policy:
        \(policies)
        """
    }

    private static func buildConfigFromShareLinksUsingMihomo(_ decoded: String) -> String? {
        guard let converted = clashConvertShareLinks(decoded.goStringBuffer())?.toString() else {
            Logger.log("[Remote Config] Mihomo converter returned empty result", level: .warning)
            return nil
        }
        if converted.hasPrefix("error:") {
            Logger.log("[Remote Config] Mihomo converter failed: \(converted)", level: .warning)
            return nil
        }
        if let verifyError = verifyConfig(string: converted) {
            Logger.log("[Remote Config] Mihomo converted config verification failed: \(verifyError)", level: .warning)
            return nil
        }
        return converted
    }

    private struct ParsedSSProxy {
        let name: String
        let server: String
        let port: Int
        let cipher: String
        let password: String

        var yaml: String {
            """
              - name: \"\(RemoteConfigManager.escapeYAML(name))\"
                type: ss
                server: \"\(RemoteConfigManager.escapeYAML(server))\"
                port: \(port)
                cipher: \"\(RemoteConfigManager.escapeYAML(cipher))\"
                password: \"\(RemoteConfigManager.escapeYAML(password))\"
                udp: true
            """
        }
    }

    private static func parseSSShareLink(_ line: String) -> ParsedSSProxy? {
        guard line.hasPrefix("ss://") else { return nil }

        let raw = String(line.dropFirst(5))
        let fragmentSplit = raw.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let body = String(fragmentSplit[0])
        let name = fragmentSplit.count > 1 ? (fragmentSplit[1].removingPercentEncoding ?? String(fragmentSplit[1])) : "Proxy"

        let queryless = body.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let main = String(queryless[0])

        let userAndHost: String
        if main.contains("@") {
            userAndHost = main
        } else if let decoded = decodeBase64ToString(main), decoded.contains("@") {
            userAndHost = decoded
        } else {
            return nil
        }

        let parts = userAndHost.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }

        let userInfo = String(parts[0])
        let hostPort = String(parts[1])

        let methodAndPassword: String
        if userInfo.contains(":") {
            methodAndPassword = userInfo
        } else if let decoded = decodeBase64ToString(userInfo), decoded.contains(":") {
            methodAndPassword = decoded
        } else {
            return nil
        }

        let mp = methodAndPassword.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard mp.count == 2 else { return nil }
        let cipher = String(mp[0])
        let password = String(mp[1])

        let hp = hostPort.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard hp.count == 2, let port = Int(hp[1]) else { return nil }

        return ParsedSSProxy(name: name, server: String(hp[0]), port: port, cipher: cipher, password: password)
    }

    private static func decodeBase64ToString(_ string: String) -> String? {
        let base64Cleaned = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padded = base64Cleaned.padding(toLength: ((base64Cleaned.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
        guard let data = Data(base64Encoded: padded, options: .ignoreUnknownCharacters),
              let decoded = String(data: data, encoding: .utf8) else {
            return nil
        }
        return decoded
    }

    private static func escapeYAML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func isSubscriptionInfoProxyName(_ name: String) -> Bool {
        let containsMarkers = ["剩余流量", "套餐到期", "过滤掉", "官网", "订阅", "用户群"]
        if containsMarkers.contains(where: { name.contains($0) }) {
            return true
        }

        let lowerName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let prefixMarkers = ["traffic", "expire", "expired", "remaining traffic", "subscription"]
        return prefixMarkers.contains(where: { lowerName.hasPrefix($0) })
    }

    private struct ParsedProxyResult {
        let name: String
        let yaml: String
    }

    private static func parseShareLink(_ line: String) -> ParsedProxyResult? {
        let result: ParsedProxyResult?
        if line.hasPrefix("ss://") {
            guard let ss = parseSSShareLink(line) else { return nil }
            result = ParsedProxyResult(name: ss.name, yaml: ss.yaml)
        } else if line.hasPrefix("vmess://") {
            result = parseVmessShareLink(line)
        } else if line.hasPrefix("trojan://") {
            result = parseTrojanShareLink(line)
        } else if line.hasPrefix("vless://") {
            result = parseVlessShareLink(line)
        } else if line.hasPrefix("hysteria2://") || line.hasPrefix("hy2://") {
            result = parseHysteria2ShareLink(line)
        } else if line.hasPrefix("hysteria://") {
            result = parseHysteriaShareLink(line)
        } else if line.hasPrefix("anytls://") {
            result = parseAnyTLSShareLink(line)
        } else if line.hasPrefix("socks://") || line.hasPrefix("socks5://") || line.hasPrefix("socks5h://") {
            result = parseSocksShareLink(line)
        } else if line.hasPrefix("http://") || line.hasPrefix("https://") {
            result = parseHTTPProxyShareLink(line)
        } else {
            result = nil
        }

        guard let result, !isSubscriptionInfoProxyName(result.name) else {
            return nil
        }
        return result
    }

    private static func parseVmessShareLink(_ line: String) -> ParsedProxyResult? {
        guard line.hasPrefix("vmess://") else { return nil }
        let raw = String(line.dropFirst(8))
        guard let decoded = decodeBase64ToString(raw),
              let data = decoded.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let name = (json["ps"] as? String)?.trimmingCharacters(in: .whitespaces) ?? "VMess Proxy"
        let server = json["add"] as? String ?? ""
        guard let port = intValue(json["port"]), !server.isEmpty else { return nil }
        let uuid = json["id"] as? String ?? ""
        guard !uuid.isEmpty else { return nil }

        let alterId = intValue(json["aid"]) ?? 0
        let cipher = json["scy"] as? String ?? "auto"
        let network = json["net"] as? String ?? "tcp"
        let headerType = json["type"] as? String ?? "none"
        let isTLS = (json["tls"] as? String ?? "") == "tls"
        let sni = json["sni"] as? String ?? ""
        let host = json["host"] as? String ?? ""
        let path = json["path"] as? String ?? ""
        let alpn = json["alpn"] as? String ?? ""
        let fp = json["fp"] as? String ?? ""

        var lines: [String] = []
        lines.append("  - name: \"\(escapeYAML(name))\"")
        lines.append("    type: vmess")
        lines.append("    server: \"\(escapeYAML(server))\"")
        lines.append("    port: \(port)")
        lines.append("    uuid: \"\(escapeYAML(uuid))\"")
        lines.append("    alterId: \(alterId)")
        lines.append("    cipher: \"\(escapeYAML(cipher))\"")
        lines.append("    udp: true")

        if isTLS {
            lines.append("    tls: true")
            if !sni.isEmpty { lines.append("    servername: \"\(escapeYAML(sni))\"") }
            if !fp.isEmpty { lines.append("    client-fingerprint: \"\(escapeYAML(fp))\"") }
            appendALPN(to: &lines, alpn: alpn)
        }

        appendTransportOpts(to: &lines, network: network, headerType: headerType,
                            host: host, path: path, serviceName: "")

        return ParsedProxyResult(name: name, yaml: lines.joined(separator: "\n"))
    }

    private static func parseTrojanShareLink(_ line: String) -> ParsedProxyResult? {
        guard line.hasPrefix("trojan://"),
              let components = URLComponents(string: line) else { return nil }

        let password = components.user?.removingPercentEncoding ?? components.user ?? ""
        let server = components.host ?? ""
        let port = components.port ?? 443
        let name = (components.fragment?.removingPercentEncoding ?? "Trojan Proxy")
            .trimmingCharacters(in: .whitespaces)
        guard !password.isEmpty, !server.isEmpty else { return nil }

        let q = queryDict(from: components)
        let sni = q["sni"] ?? q["peer"] ?? ""
        let transport = q["type"] ?? "tcp"
        let host = q["host"] ?? ""
        let path = q["path"] ?? ""
        let serviceName = q["serviceName"] ?? ""
        let allowInsecure = q["allowInsecure"] == "1" || q["insecure"] == "1"
        let alpn = q["alpn"] ?? ""
        let fp = q["fp"] ?? ""

        var lines: [String] = []
        lines.append("  - name: \"\(escapeYAML(name))\"")
        lines.append("    type: trojan")
        lines.append("    server: \"\(escapeYAML(server))\"")
        lines.append("    port: \(port)")
        lines.append("    password: \"\(escapeYAML(password))\"")
        lines.append("    udp: true")

        if !sni.isEmpty { lines.append("    sni: \"\(escapeYAML(sni))\"") }
        if allowInsecure { lines.append("    skip-cert-verify: true") }
        if !fp.isEmpty { lines.append("    client-fingerprint: \"\(escapeYAML(fp))\"") }
        appendALPN(to: &lines, alpn: alpn)
        appendTransportOpts(to: &lines, network: transport, headerType: "none",
                            host: host, path: path, serviceName: serviceName)

        return ParsedProxyResult(name: name, yaml: lines.joined(separator: "\n"))
    }

    private static func parseVlessShareLink(_ line: String) -> ParsedProxyResult? {
        guard line.hasPrefix("vless://"),
              let components = URLComponents(string: line) else { return nil }

        let uuid = components.user?.removingPercentEncoding ?? components.user ?? ""
        let server = components.host ?? ""
        let port = components.port ?? 443
        let name = (components.fragment?.removingPercentEncoding ?? "VLESS Proxy")
            .trimmingCharacters(in: .whitespaces)
        guard !uuid.isEmpty, !server.isEmpty else { return nil }

        let q = queryDict(from: components)
        let security = q["security"] ?? "none"
        let sni = q["sni"] ?? ""
        let transport = q["type"] ?? "tcp"
        let host = q["host"] ?? ""
        let path = q["path"] ?? ""
        let serviceName = q["serviceName"] ?? ""
        let flow = q["flow"] ?? ""
        let fp = q["fp"] ?? ""
        let alpn = q["alpn"] ?? ""
        let allowInsecure = q["allowInsecure"] == "1" || q["insecure"] == "1"
        let pbk = q["pbk"] ?? ""
        let sid = q["sid"] ?? ""

        var lines: [String] = []
        lines.append("  - name: \"\(escapeYAML(name))\"")
        lines.append("    type: vless")
        lines.append("    server: \"\(escapeYAML(server))\"")
        lines.append("    port: \(port)")
        lines.append("    uuid: \"\(escapeYAML(uuid))\"")
        lines.append("    udp: true")

        if !flow.isEmpty { lines.append("    flow: \"\(escapeYAML(flow))\"") }

        if security == "tls" || security == "reality" {
            lines.append("    tls: true")
            if !sni.isEmpty { lines.append("    servername: \"\(escapeYAML(sni))\"") }
            if allowInsecure { lines.append("    skip-cert-verify: true") }
            if !fp.isEmpty { lines.append("    client-fingerprint: \"\(escapeYAML(fp))\"") }
            appendALPN(to: &lines, alpn: alpn)

            if security == "reality" {
                lines.append("    reality-opts:")
                lines.append("      public-key: \"\(escapeYAML(pbk))\"")
                if !sid.isEmpty { lines.append("      short-id: \"\(escapeYAML(sid))\"") }
            }
        }

        appendTransportOpts(to: &lines, network: transport, headerType: "none",
                            host: host, path: path, serviceName: serviceName)

        return ParsedProxyResult(name: name, yaml: lines.joined(separator: "\n"))
    }

    private static func parseHysteria2ShareLink(_ line: String) -> ParsedProxyResult? {
        guard line.hasPrefix("hysteria2://") || line.hasPrefix("hy2://"),
              let components = URLComponents(string: line) else { return nil }

        let password = components.user?.removingPercentEncoding ?? components.user ?? ""
        let server = components.host ?? ""
        let port = components.port ?? 443
        let name = (components.fragment?.removingPercentEncoding ?? "Hysteria2 Proxy")
            .trimmingCharacters(in: .whitespaces)
        guard !server.isEmpty else { return nil }

        let q = queryDict(from: components)
        let sni = q["sni"] ?? ""
        let allowInsecure = q["insecure"] == "1" || q["allowInsecure"] == "1"
        let obfs = q["obfs"] ?? ""
        let obfsPassword = q["obfs-password"] ?? ""

        var lines: [String] = []
        lines.append("  - name: \"\(escapeYAML(name))\"")
        lines.append("    type: hysteria2")
        lines.append("    server: \"\(escapeYAML(server))\"")
        lines.append("    port: \(port)")
        if !password.isEmpty { lines.append("    password: \"\(escapeYAML(password))\"") }
        lines.append("    udp: true")

        if !sni.isEmpty { lines.append("    sni: \"\(escapeYAML(sni))\"") }
        if allowInsecure { lines.append("    skip-cert-verify: true") }
        if !obfs.isEmpty { lines.append("    obfs: \"\(escapeYAML(obfs))\"") }
        if !obfsPassword.isEmpty { lines.append("    obfs-password: \"\(escapeYAML(obfsPassword))\"") }

        return ParsedProxyResult(name: name, yaml: lines.joined(separator: "\n"))
    }

    private static func parseHysteriaShareLink(_ line: String) -> ParsedProxyResult? {
        guard line.hasPrefix("hysteria://"),
              let components = URLComponents(string: line) else { return nil }

        let server = components.host ?? ""
        let port = components.port ?? 443
        let name = (components.fragment?.removingPercentEncoding ?? "Hysteria Proxy")
            .trimmingCharacters(in: .whitespaces)
        guard !server.isEmpty else { return nil }

        let q = queryDict(from: components)
        let authBase64 = q["auth"] ?? ""
        let authStr: String
        if !authBase64.isEmpty, let decoded = decodeBase64ToString(authBase64) {
            authStr = decoded
        } else {
            authStr = authBase64
        }
        let sni = q["peer"] ?? q["sni"] ?? ""
        let allowInsecure = q["insecure"] == "1"
        let upMbps = q["upmbps"] ?? "100"
        let downMbps = q["downmbps"] ?? "100"
        let obfs = q["obfs"] ?? ""
        let obfsParam = q["obfsParam"] ?? ""
        let alpn = q["alpn"] ?? ""

        var lines: [String] = []
        lines.append("  - name: \"\(escapeYAML(name))\"")
        lines.append("    type: hysteria")
        lines.append("    server: \"\(escapeYAML(server))\"")
        lines.append("    port: \(port)")
        lines.append("    udp: true")

        if !authStr.isEmpty { lines.append("    auth-str: \"\(escapeYAML(authStr))\"") }
        lines.append("    up: \"\(escapeYAML(upMbps)) Mbps\"")
        lines.append("    down: \"\(escapeYAML(downMbps)) Mbps\"")

        if !sni.isEmpty { lines.append("    sni: \"\(escapeYAML(sni))\"") }
        if allowInsecure { lines.append("    skip-cert-verify: true") }
        if obfs == "xplus", !obfsParam.isEmpty {
            lines.append("    obfs: \"\(escapeYAML(obfsParam))\"")
        }
        appendALPN(to: &lines, alpn: alpn)

        return ParsedProxyResult(name: name, yaml: lines.joined(separator: "\n"))
    }

    private static func parseAnyTLSShareLink(_ line: String) -> ParsedProxyResult? {
        guard line.hasPrefix("anytls://"),
              let components = URLComponents(string: line) else { return nil }

        let password = components.user?.removingPercentEncoding ?? components.user ?? ""
        let server = components.host ?? ""
        let port = components.port ?? 443
        let name = (components.fragment?.removingPercentEncoding ?? "AnyTLS Proxy")
            .trimmingCharacters(in: .whitespaces)
        guard !password.isEmpty, !server.isEmpty else { return nil }

        let q = queryDict(from: components)
        let sni = q["sni"] ?? q["peer"] ?? ""
        let alpn = q["alpn"] ?? ""
        let fp = q["fp"] ?? q["fingerprint"] ?? ""
        let allowInsecure = q["allowInsecure"] == "1" || q["insecure"] == "1"

        var lines: [String] = []
        lines.append("  - name: \"\(escapeYAML(name))\"")
        lines.append("    type: anytls")
        lines.append("    server: \"\(escapeYAML(server))\"")
        lines.append("    port: \(port)")
        lines.append("    password: \"\(escapeYAML(password))\"")
        lines.append("    udp: true")
        if !sni.isEmpty { lines.append("    sni: \"\(escapeYAML(sni))\"") }
        if allowInsecure { lines.append("    skip-cert-verify: true") }
        if !fp.isEmpty { lines.append("    client-fingerprint: \"\(escapeYAML(fp))\"") }
        appendALPN(to: &lines, alpn: alpn)

        return ParsedProxyResult(name: name, yaml: lines.joined(separator: "\n"))
    }

    private static func parseSocksShareLink(_ line: String) -> ParsedProxyResult? {
        guard let components = URLComponents(string: line) else { return nil }
        let server = components.host ?? ""
        let port = components.port ?? 1080
        let name = (components.fragment?.removingPercentEncoding ?? "SOCKS Proxy")
            .trimmingCharacters(in: .whitespaces)
        guard !server.isEmpty else { return nil }

        var lines: [String] = []
        lines.append("  - name: \"\(escapeYAML(name))\"")
        lines.append("    type: socks5")
        lines.append("    server: \"\(escapeYAML(server))\"")
        lines.append("    port: \(port)")
        if let username = components.user?.removingPercentEncoding, !username.isEmpty {
            lines.append("    username: \"\(escapeYAML(username))\"")
        }
        if let password = components.password?.removingPercentEncoding, !password.isEmpty {
            lines.append("    password: \"\(escapeYAML(password))\"")
        }
        lines.append("    udp: true")

        return ParsedProxyResult(name: name, yaml: lines.joined(separator: "\n"))
    }

    private static func parseHTTPProxyShareLink(_ line: String) -> ParsedProxyResult? {
        guard let components = URLComponents(string: line) else { return nil }
        let server = components.host ?? ""
        let port = components.port ?? (components.scheme == "https" ? 443 : 80)
        let name = (components.fragment?.removingPercentEncoding ?? "HTTP Proxy")
            .trimmingCharacters(in: .whitespaces)
        guard !server.isEmpty, components.user != nil || components.password != nil else { return nil }

        var lines: [String] = []
        lines.append("  - name: \"\(escapeYAML(name))\"")
        lines.append("    type: http")
        lines.append("    server: \"\(escapeYAML(server))\"")
        lines.append("    port: \(port)")
        if components.scheme == "https" { lines.append("    tls: true") }
        if let username = components.user?.removingPercentEncoding, !username.isEmpty {
            lines.append("    username: \"\(escapeYAML(username))\"")
        }
        if let password = components.password?.removingPercentEncoding, !password.isEmpty {
            lines.append("    password: \"\(escapeYAML(password))\"")
        }

        return ParsedProxyResult(name: name, yaml: lines.joined(separator: "\n"))
    }

    private static func queryDict(from components: URLComponents) -> [String: String] {
        var dict: [String: String] = [:]
        for item in components.queryItems ?? [] {
            if let value = item.value {
                dict[item.name] = value
            }
        }
        return dict
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let s = value as? String { return Int(s) }
        if let d = value as? Double { return Int(d) }
        return nil
    }

    // swiftlint:disable:next function_parameter_count
    private static func appendTransportOpts(to lines: inout [String],
                                            network: String,
                                            headerType: String,
                                            host: String,
                                            path: String,
                                            serviceName: String) {
        switch network {
        case "ws":
            lines.append("    network: ws")
            if !path.isEmpty || !host.isEmpty {
                lines.append("    ws-opts:")
                if !path.isEmpty { lines.append("      path: \"\(escapeYAML(path))\"") }
                if !host.isEmpty {
                    lines.append("      headers:")
                    lines.append("        Host: \"\(escapeYAML(host))\"")
                }
            }
        case "grpc":
            lines.append("    network: grpc")
            let svcName = !serviceName.isEmpty ? serviceName : path
            if !svcName.isEmpty {
                lines.append("    grpc-opts:")
                lines.append("      grpc-service-name: \"\(escapeYAML(svcName))\"")
            }
        case "h2":
            lines.append("    network: h2")
            if !path.isEmpty || !host.isEmpty {
                lines.append("    h2-opts:")
                if !host.isEmpty {
                    lines.append("      host:")
                    lines.append("        - \"\(escapeYAML(host))\"")
                }
                if !path.isEmpty { lines.append("      path: \"\(escapeYAML(path))\"") }
            }
        case "tcp" where headerType == "http":
            lines.append("    network: http")
            if !path.isEmpty || !host.isEmpty {
                lines.append("    http-opts:")
                if !path.isEmpty {
                    lines.append("      path:")
                    lines.append("        - \"\(escapeYAML(path))\"")
                }
                if !host.isEmpty {
                    lines.append("      headers:")
                    lines.append("        Host:")
                    lines.append("          - \"\(escapeYAML(host))\"")
                }
            }
        default:
            break
        }
    }

    private static func appendALPN(to lines: inout [String], alpn: String) {
        guard !alpn.isEmpty else { return }
        lines.append("    alpn:")
        for value in alpn.split(separator: ",") {
            lines.append("      - \"\(value.trimmingCharacters(in: .whitespaces))\"")
        }
    }

    private static func looksLikeShareLinks(_ string: String) -> Bool {
        guard let firstLine = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) else { return false }
        return shareLinkSchemes.contains(where: { firstLine.hasPrefix($0) })
    }

    static func updateConfig(config: RemoteConfigModel, complete: ((String?) -> Void)? = nil) {
        getRemoteConfigData(config: config) { configString, suggestedFilename, responseHeaders in
            guard let rawConfig = configString else {
                complete?(NSLocalizedString("Download fail", comment: ""))
                return
            }

            let newConfig: String
            if looksLikeShareLinks(rawConfig), let converted = buildConfigFromShareLinks(rawConfig) {
                Logger.log("[Remote Config] Content was raw share links, converted successfully")
                newConfig = converted
            } else if let decoded = tryDecodeBase64(rawConfig) {
                Logger.log("[Remote Config] Content was base64 encoded, decoded successfully")
                newConfig = decoded
            } else {
                newConfig = rawConfig
            }

            let headerInfo = parseSubscriptionUserinfoHeader(responseHeaders)
            let bodyInfo = parseSubscriptionInfoFromBody(rawConfig)
            config.subscriptionInfo = SubscriptionInfo.merging(primary: headerInfo, fallback: bodyInfo)
            if let info = config.subscriptionInfo {
                Logger.log("[Remote Config] Captured subscription info for \(config.name): upload=\(info.upload ?? -1) download=\(info.download ?? -1) total=\(info.total ?? -1) expire=\(info.expire ?? 0) expireText=\(info.expireText ?? "-")")
            }

            let verifyRes = verifyConfig(string: newConfig)
            if let error = verifyRes {
                complete?(NSLocalizedString("Remote Config Format Error", comment: "") + ": " + error)
                return
            }

            if let suggestName = suggestedFilename, config.isPlaceHolderName {
                let name = URL(fileURLWithPath: suggestName).deletingPathExtension().lastPathComponent
                if !shared.configs.contains(where: { $0.name == name }) {
                    config.name = name
                }
            }
            config.isPlaceHolderName = false

            if ICloudManager.shared.useiCloud.value {
                ConfigFileManager.shared.stopWatchConfigFile()
            }
            if config.name == ConfigManager.selectConfigName {
                ConfigFileManager.shared.pauseForNextChange()
            }

            let saveAction: ((String) -> Void) = {
                savePath in
                do {
                    if FileManager.default.fileExists(atPath: savePath) {
                        try FileManager.default.removeItem(atPath: savePath)
                    }
                    try newConfig.write(to: URL(fileURLWithPath: savePath), atomically: true, encoding: .utf8)
                    complete?(nil)
                } catch let err {
                    complete?(err.localizedDescription)
                }
            }

            if ICloudManager.shared.useiCloud.value {
                ICloudManager.shared.getUrl { url in
                    guard let url = url else { return }
                    let saveUrl = url.appendingPathComponent(Paths.configFileName(for: config.name))
                    saveAction(saveUrl.path)
                }
            } else {
                let savePath = Paths.localConfigPath(for: config.name)
                saveAction(savePath)
            }
        }
    }

    static func verifyConfig(string: String) -> ErrorString? {
        let res = verifyClashConfig(string.goStringBuffer())?.toString() ?? "unknown error"
        if res == "success" {
            return nil
        } else {
            Logger.log(res, level: .error)
            return res
        }
    }

    static func showAdd() {
        let alertView = NSAlert()
        alertView.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alertView.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        alertView.messageText = NSLocalizedString("Update remote config update interval", comment: "")
        let setupView = RemoteConfigUpdateIntervalSettingView()
        setupView.frame = NSRect(x: 0, y: 0, width: 100, height: 22)
        alertView.accessoryView = setupView
        let response = alertView.runModal()

        guard response == .alertFirstButtonReturn else { return }
        let stringValue = setupView.textfield.stringValue
        guard let intValue = Int(stringValue), intValue > 0 else {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.informativeText = NSLocalizedString("Should be a least 1 hour", comment: "")
            alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
            alert.runModal()
            return
        }
        Settings.configAutoUpdateInterval = TimeInterval(intValue * 60 * 60)
        RemoteConfigManager.shared.autoUpdateCheck()
    }
}
