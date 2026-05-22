// Models/WatchlistEntry.swift
// UniMarket-Swift
//
// Data models shared across the Watchlist cache, store, and view-model layers.

import Foundation

// MARK: - WatchlistEntry

/// Lightweight record of a product the user is watching for price changes.
/// Stored as JSON in WatchlistUserDefaultsStore so the list survives app restarts
/// without a network round-trip.
struct WatchlistEntry: Identifiable, Codable, Hashable {
    /// The Firestore document ID for this product.
    let id: String
    let title: String
    let imageURL: String?
    /// Price at the moment the user tapped "Watch Price".
    let originalPrice: Int
    let addedAt: Date
}

// MARK: - WatchlistPriceSnapshot

/// Value-type snapshot returned from cache lookups and stored in the ViewModel.
/// Carries both the current and previous price so the UI can render a delta pill.
struct WatchlistPriceSnapshot {
    let productID: String
    let price: Int
    /// The price recorded in the previous refresh cycle, nil on first fetch.
    let previousPrice: Int?
    let cachedAt: Date
}

// MARK: - WatchlistLookupResult

/// Discriminated result from `WatchlistPriceCache.lookup(productID:)`.
///
/// - `hit`:   Entry is present and within the 30-minute TTL.
/// - `stale`: Entry is present but past the TTL; returned to caller *tagged* as
///            stale so the UI can show "may be out of date" — the entry is NOT
///            evicted at lookup time.
/// - `miss`:  No entry found in the cache.
enum WatchlistLookupResult {
    case hit(WatchlistPriceSnapshot)
    case stale(WatchlistPriceSnapshot)
    case miss
}
