import Foundation

/// Custom array-based LRU cache for donation listings keyed by category string.
/// capacity=16; insertion moves key to MRU (end); eviction removes LRU (front).
/// Not thread-safe by design — only accessed on the main actor via ViewModels.
final class DonationListingsLRU {
    static let shared = DonationListingsLRU()

    private struct Entry {
        let listings: [Product]
    }

    private var cache: [(key: String, entry: Entry)] = []
    private let capacity = 16

    private init() {}

    func get(for category: String) -> [Product]? {
        guard let index = cache.firstIndex(where: { $0.key == category }) else { return nil }
        let (key, entry) = cache.remove(at: index)
        cache.append((key, entry))
        return entry.listings
    }

    func set(_ listings: [Product], for category: String) {
        if let index = cache.firstIndex(where: { $0.key == category }) {
            cache.remove(at: index)
        }
        cache.append((category, Entry(listings: listings)))
        while cache.count > capacity {
            cache.removeFirst()
        }
    }

    func clear() {
        cache.removeAll()
    }
}
