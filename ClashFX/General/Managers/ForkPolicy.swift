//
//  ForkPolicy.swift
//  ClashFX
//

import Foundation

/// Product-level differences from the upstream ClashFX distribution.
///
/// Keep fork policy here so upstream integrations do not have to rediscover
/// scattered feature switches or accidentally reactivate upstream services.
enum ForkPolicy {
    /// This fork is not signed by upstream and must never install artifacts
    /// from upstream's Sparkle feed.
    static let officialUpdatesEnabled = false
}
