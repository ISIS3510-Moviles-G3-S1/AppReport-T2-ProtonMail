// Services/WatchlistPriceCache.swift
// UniMarket-Swift
//
// In-memory price cache for the watchlist feature.
// Backed by NSCache so OS memory pressure auto-evicts entries.

import Foundation

// MARK: - WatchlistPriceEntry

/// NSObject reference wrapper required by NSCache.
/// Carries the price data and the timestamp used for TTL checks.
final class WatchlistPriceEntry: NSObject {
    let price: Int
    /// Price from the previous refresh cycle; nil when first stored.
    let previousPrice: Int?
    let cachedAt: Date

    init(price: Int, previousPrice: Int?, cachedAt: Date) {
        self.price = price
        self.previousPrice = previousPrice
        self.cachedAt = cachedAt
    }
}

// MARK: - WatchlistPriceCache

/// Singleton NSCache for watched-product price snapshots.
///
/// **Constraints (spec-exact)**
/// - `countLimit` = 150 entries
/// - `totalCostLimit` = 256 KB
/// - Cost per entry = 100 bytes (set explicitly in every `setObject(_:forKey:cost:)` call)
/// - TTL = 1800 seconds (30 minutes), evaluated lazily at lookup time
/// - Stale entries are *returned* to the caller tagged `.stale` — never silently evicted
/// - A `.userDidSignOut` notification triggers `removeAllObjects()` so no user's
///   price data leaks to the next session
///
/// `@MainActor` isolation guarantees single-threaded access to all NSCache calls.
@MainActor
final class WatchlistPriceCache {
    static let shared = WatchlistPriceCache()

    // MARK: Constants
    private let ttl: TimeInterval = 1800          // 30 minutes
    private let costPerEntry: Int = 100           // bytes, charged to NSCache budget

    // MARK: Storage
    private let cache = NSCache<NSString, WatchlistPriceEntry>()

    private init() {
        cache.countLimit = 150
        cache.totalCostLimit = 256 * 1024         // 256 KB

        // Clear the cache on sign-out so stale user data does not survive
        // into the next session. The observer fires on the main queue so
        // it aligns naturally with this class's @MainActor isolation.
        NotificationCenter.default.addObserver(
            forName: .userDidSignOut,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cache.removeAllObjects()
        }
    }

    // MARK: - Public API

    /// Looks up a cached price snapshot for the given product ID.
    ///
    /// - Returns: `.hit` if fresh (within TTL), `.stale` if expired (entry kept),
    ///   `.miss` if absent.
    func lookup(productID: String) -> WatchlistLookupResult {
        guard let entry = cache.object(forKey: productID as NSString) else {
            return .miss
        }

        let snapshot = WatchlistPriceSnapshot(
            productID: productID,
            price: entry.price,
            previousPrice: entry.previousPrice,
            cachedAt: entry.cachedAt
        )

        // TTL check — stale entries are returned, not evicted
        if Date().timeIntervalSince(entry.cachedAt) >= ttl {
            return .stale(snapshot)
        }
        return .hit(snapshot)
    }

    /// Stores a new price snapshot, charging exactly `costPerEntry` (100 bytes) to
    /// the cache's total cost budget.
    func store(productID: String, price: Int, previousPrice: Int?) {
        let entry = WatchlistPriceEntry(
            price: price,
            previousPrice: previousPrice,
            cachedAt: Date()
        )
        cache.setObject(entry, forKey: productID as NSString, cost: costPerEntry)
    }

    /// Removes all cached entries immediately (called on sign-out).
    func removeAll() {
        cache.removeAllObjects()
    }
}
