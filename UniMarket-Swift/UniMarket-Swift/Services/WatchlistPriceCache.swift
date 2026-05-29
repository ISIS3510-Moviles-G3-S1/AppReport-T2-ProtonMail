import Foundation

/// NSObject reference wrapper required by NSCache.
final class WatchlistPriceEntry: NSObject {
    let price: Int
    let previousPrice: Int?
    let cachedAt: Date

    init(price: Int, previousPrice: Int?, cachedAt: Date) {
        self.price = price
        self.previousPrice = previousPrice
        self.cachedAt = cachedAt
    }
}

/// Shared cache that supports both:
/// - Watchlist screen price snapshots (NSCache)
/// - Notifications price-drop detection (UserDefaults baseline/current snapshots)
@MainActor
final class WatchlistPriceCache {
    static let shared = WatchlistPriceCache()

    struct PriceSnapshot: Codable {
        let productID: String
        let title: String
        let baselinePrice: Int
        let currentPrice: Int
        let detectedAt: Date
    }

    private let ttl: TimeInterval = 1800
    private let costPerEntry = 100
    private let cache = NSCache<NSString, WatchlistPriceEntry>()

    private let defaults = UserDefaults.standard
    private let udKey = "unimarket.watchlist_price_cache"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        cache.countLimit = 150
        cache.totalCostLimit = 256 * 1024
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        NotificationCenter.default.addObserver(
            forName: .userDidSignOut,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clear()
        }
    }

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

        if Date().timeIntervalSince(entry.cachedAt) >= ttl {
            return .stale(snapshot)
        }
        return .hit(snapshot)
    }

    func store(productID: String, price: Int, previousPrice: Int?) {
        let entry = WatchlistPriceEntry(
            price: price,
            previousPrice: previousPrice,
            cachedAt: Date()
        )
        cache.setObject(entry, forKey: productID as NSString, cost: costPerEntry)
    }

    func removeAll() {
        clear()
    }

    func update(products: [Product], watchlistIDs: Set<String>) {
        var snapshots = loadAll().reduce(into: [String: PriceSnapshot]()) {
            $0[$1.productID] = $1
        }
        let now = Date()

        for product in products where watchlistIDs.contains(product.id) {
            if let existing = snapshots[product.id] {
                guard existing.currentPrice != product.price else { continue }
                let newDetectedAt = product.price < existing.baselinePrice
                    ? (product.price < existing.currentPrice ? now : existing.detectedAt)
                    : existing.detectedAt
                snapshots[product.id] = PriceSnapshot(
                    productID: product.id,
                    title: product.title,
                    baselinePrice: existing.baselinePrice,
                    currentPrice: product.price,
                    detectedAt: newDetectedAt
                )
            } else {
                snapshots[product.id] = PriceSnapshot(
                    productID: product.id,
                    title: product.title,
                    baselinePrice: product.price,
                    currentPrice: product.price,
                    detectedAt: now
                )
            }
        }

        let pruned = snapshots.values.filter { watchlistIDs.contains($0.productID) }
        persist(Array(pruned))
    }

    func detectedDrops(for watchlistIDs: [String]) -> [PriceSnapshot] {
        let set = Set(watchlistIDs)
        return loadAll().filter {
            set.contains($0.productID) && $0.currentPrice < $0.baselinePrice
        }
    }

    func clear() {
        cache.removeAllObjects()
        defaults.removeObject(forKey: udKey)
    }

    private func loadAll() -> [PriceSnapshot] {
        guard
            let data = defaults.data(forKey: udKey),
            let items = try? decoder.decode([PriceSnapshot].self, from: data)
        else { return [] }
        return items
    }

    private func persist(_ items: [PriceSnapshot]) {
        guard let data = try? encoder.encode(items) else { return }
        defaults.set(data, forKey: udKey)
    }
}
