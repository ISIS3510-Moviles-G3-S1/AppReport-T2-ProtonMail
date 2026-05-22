import Foundation

// MARK: - NotificationSnapshotBox

/// NSObject wrapper around `NotificationSections` so the struct can be stored in
/// `NSCache<NSString, NotificationSnapshotBox>`.
final class NotificationSnapshotBox: NSObject {
    let sections:  NotificationSections
    let storedAt:  Date

    init(sections: NotificationSections, storedAt: Date) {
        self.sections = sections
        self.storedAt = storedAt
    }
}

// MARK: - NotificationsCache

/// Two-tier read path: NSCache (hot / in-process) → UserDefaults (cold / cross-launch).
///
/// **Tier 1 — NSCache**: `countLimit = 1`, `totalCostLimit = 64 KiB`.
/// Automatically evicted under memory pressure; always tried first.
///
/// **Tier 2 — UserDefaults**: The 50 most-recent `NotificationItem` objects
/// (sorted newest-first) are encoded as JSON under the key
/// `"unimarket.notifications.\(userID)"`.  On a cold launch, `load()` decodes
/// these items, reconstructs `NotificationSections`, and simultaneously warms
/// the NSCache so subsequent calls hit Tier 1.
///
/// `@MainActor` because:
/// * NSCache is not `Sendable`.
/// * All callers (`NotificationsViewModel`) already run on the main actor.
@MainActor
final class NotificationsCache {
    static let shared = NotificationsCache()

    // MARK: - NSCache

    private let memoryCache: NSCache<NSString, NotificationSnapshotBox> = {
        let c                = NSCache<NSString, NotificationSnapshotBox>()
        c.countLimit         = 1
        c.totalCostLimit     = 64 * 1024     // 64 KiB
        return c
    }()

    private let cacheKey = "snapshot" as NSString

    private init() {}

    // MARK: - Store

    /// Persists `sections` in both tiers.
    ///
    /// * NSCache: full `NotificationSections` wrapped in `NotificationSnapshotBox`.
    /// * UserDefaults: the 50 most-recent `NotificationItem` objects as JSON, keyed
    ///   by `"unimarket.notifications.\(userID)"` for cold-launch survival.
    func store(_ sections: NotificationSections, userID: String) {
        // Tier 1
        let box = NotificationSnapshotBox(sections: sections, storedAt: Date())
        memoryCache.setObject(box, forKey: cacheKey, cost: estimatedCost(for: sections))

        // Tier 2 — flatten, sort, cap at 50, encode
        let allItems = (sections.unreadMessages
                        + sections.priceDrops
                        + sections.syncStatus
                        + sections.recentActivity)
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(50)

        if let data = try? JSONEncoder().encode(Array(allItems)) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey(for: userID))
        }
    }

    // MARK: - Load

    /// Returns sections from NSCache if present; otherwise reconstructs them from
    /// the UserDefaults flat list and simultaneously warms the NSCache.
    func load(userID: String) -> NotificationSections? {
        // Tier 1: hot path
        if let box = memoryCache.object(forKey: cacheKey) {
            return box.sections
        }

        // Tier 2: cold path
        guard
            let data  = UserDefaults.standard.data(forKey: userDefaultsKey(for: userID)),
            let items = try? JSONDecoder().decode([NotificationItem].self, from: data)
        else { return nil }

        var sections = NotificationSections()
        for item in items {
            switch item.type {
            case .unreadMessage:  sections.unreadMessages.append(item)
            case .priceDrop:      sections.priceDrops.append(item)
            case .syncStatus:     sections.syncStatus.append(item)
            case .recentActivity: sections.recentActivity.append(item)
            }
        }

        // Warm Tier 1 so next read is free.
        let box = NotificationSnapshotBox(sections: sections, storedAt: Date())
        memoryCache.setObject(box, forKey: cacheKey, cost: estimatedCost(for: sections))

        return sections
    }

    // MARK: - Clear

    /// Called on sign-out to remove all cached notification data for a user.
    func clear(userID: String? = nil) {
        memoryCache.removeAllObjects()
        if let userID {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey(for: userID))
        }
    }

    // MARK: - Private helpers

    private func userDefaultsKey(for userID: String) -> String {
        "unimarket.notifications.\(userID)"
    }

    /// Rough byte-budget estimate for the NSCache cost parameter.
    private func estimatedCost(for sections: NotificationSections) -> Int {
        let total = sections.unreadMessages.count
            + sections.priceDrops.count
            + sections.syncStatus.count
            + sections.recentActivity.count
        return max(total * 512, 1)          // ~512 bytes per serialised item
    }
}
