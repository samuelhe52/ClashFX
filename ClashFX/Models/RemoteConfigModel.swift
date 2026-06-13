//
//  RemoteConfigModel.swift
//  ClashX
//
//  Created by yicheng on 2019/7/28.
//  Copyright © 2019 west2online. All rights reserved.
//

import Cocoa

class RemoteConfigModel: Codable {
    var url: String
    var name: String
    var userAgent: String?
    var updateTime: Date?
    var updating = false
    var isPlaceHolderName = false
    var subscriptionInfo: SubscriptionInfo?

    init(url: String, name: String, userAgent: String? = nil, updateTime: Date? = nil) {
        self.url = url
        self.name = name
        self.userAgent = userAgent
        self.updateTime = updateTime
    }

    private enum CodingKeys: String, CodingKey {
        case url, name, userAgent, updateTime, subscriptionInfo
    }

    func displayingTimeString() -> String {
        if updating { return NSLocalizedString("Updating", comment: "") }
        let dateFormater = DateFormatter()
        dateFormater.dateFormat = "MM-dd HH:mm"
        if let date = updateTime {
            return dateFormater.string(from: date)
        }
        return NSLocalizedString("Never", comment: "")
    }
}

extension RemoteConfigModel: Equatable {
    static func == (lhs: RemoteConfigModel, rhs: RemoteConfigModel) -> Bool {
        return lhs.name == rhs.name && lhs.url == rhs.url
    }
}

struct SubscriptionInfo: Codable, Equatable {
    var upload: Int64?
    var download: Int64?
    var total: Int64?
    var expire: TimeInterval?
    var expireText: String?

    var used: Int64? {
        switch (upload, download) {
        case let (u?, d?): return u + d
        case let (u?, nil): return u
        case let (nil, d?): return d
        case (nil, nil): return nil
        }
    }

    var hasAnyData: Bool {
        return upload != nil || download != nil || total != nil || expire != nil || expireText != nil
    }

    static func merging(primary: SubscriptionInfo?, fallback: SubscriptionInfo?) -> SubscriptionInfo? {
        guard primary != nil || fallback != nil else { return nil }
        var merged = SubscriptionInfo()
        merged.upload = primary?.upload ?? fallback?.upload
        merged.download = primary?.download ?? fallback?.download
        merged.total = primary?.total ?? fallback?.total
        merged.expire = primary?.expire ?? fallback?.expire
        merged.expireText = primary?.expireText ?? fallback?.expireText
        return merged.hasAnyData ? merged : nil
    }
}
