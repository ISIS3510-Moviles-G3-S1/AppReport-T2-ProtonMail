import Foundation

/// Persists a two-entry price history (baseline + current) for each favorited product.
///
/// **Write path**: Called by `NotificationsViewModel.refresh` immediately before
/// the task group launches (on the main actor, using the in-memory ProductStore
/// products — zero network cost).
///
/// **Read path**: Called by `NotificationAggregatorService.priceDropItems(watchlistIDs:)`
/// from a `.utility` child task. Both paths only hit UserDefaults, never the network.
final class WatchlistPriceCache {
    static let shared = WatchlistPriceCache()

    // MARK: - Model

    struct PriceSnapshot: Codable {
        let productID:     String
        let title:         String
        /// Price recorded the first time the product appeared in the watchlist —
        /// kept frozen until the product leaves the watchlist and re-enters.
        let baselinePrice: Int
        /// Most recent price seen from ProductStore (updated on every refresh).
        let currentPrice:  Int
        /// Wall-clock time when a drop (currentPrice < baselinePrice) was first
        /// detected; refreshed on subsequent calls only if a deeper drop occurs.
        let detectedAt:    Date
    }

    // MARK: - Private state

    private let defaults = UserDefaults.standard
    private let udKey    = "unimarket.watchlist_price_cache"
    private let encoder  = JSONEncoder()
    private let decoder  = JSONDecoder()

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Write

    /// Compare `products` against stored baselines and persist updated snapshots.
    ///
    /// Rules:
    /// - First time a product is seen → baseline = current (no drop yet).
    /// - Subsequent calls → baseline stays locked; only `currentPrice` and
    ///   `detectedAt` are refreshed if a deeper drop is found.
    /// - Products no longer in `watchlistIDs` are pruned.
    func update(products: [Product], watchlistIDs: Set<String>) {
        var snapshots = loadAll().reduce(into: [String: PriceSnapshot]()) {
            $0[$1.productID] = $1
        }
        let now = Date()

        for product in products where watchlistIDs.contains(product.id) {
            if var existing = snapshots[product.id] {
                guard existing.currentPrice != product.price else { continue }
                let newDetectedAt = product.price < existing.baselinePrice
                    ? (product.price < existing.currentPrice ? now : existing.detectedAt)
                    : existing.detectedAt
                snapshots[product.id] = PriceSnapshot(
                    productID:     product.id,
                    title:         product.title,
                    baselinePrice: existing.baselinePrice,
                    currentPrice:  product.price,
                    detectedAt:    newDetectedAt
                )
            } else {
                // First sighting — baseline == current, no drop yet.
                snapshots[product.id] = PriceSnapshot(
                    productID:     product.id,
                    title:         product.title,
                    baselinePrice: product.price,
                    currentPrice:  product.price,
                    detectedAt:    now
                )
            }
        }

        // Prune entries no longer in the watchlist.
        let pruned = snapshots.values.filter { watchlistIDs.contains($0.productID) }
        persist(Array(pruned))
    }

    // MARK: - Read

    /// Returns snapshots where `currentPrice < baselinePrice` (price dropped since
    /// the product was first added to the watchlist).  Pure cache read — no network.
    func detectedDrops(for watchlistIDs: [String]) -> [PriceSnapshot] {
        let set = Set(watchlistIDs)
        return loadAll().filter {
            set.contains($0.productID) && $0.currentPrice < $0.baselinePrice
        }
    }

    // MARK: - Clear (called on sign-out)

    func clear() {
        defaults.removeObject(forKey: udKey)
    }

    // MARK: - Private helpers

    private func loadAll() -> [PriceSnapshot] {
        guard
            let data  = defaults.data(forKey: udKey),
            let items = try? decoder.decode([PriceSnapshot].self, from: data)
        else { return [] }
        return items
    }

    private func persist(_ items: [PriceSnapshot]) {
        guard let data = try? encoder.encode(items) else { return }
        defaults.set(data, forKey: udKey)
    }
}
