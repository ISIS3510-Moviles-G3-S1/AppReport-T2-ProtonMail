import Foundation

/// Two-layer LRU cache for recently viewed products.
///
/// Layer 1 — in-memory array per user, evicts the least-recently-used entry
///            when capacity (15) is exceeded.
/// Layer 2 — UserDefaults JSON snapshot, so the list survives app restarts.
///
/// Eviction policy: the front of each user's array is the MRU position;
/// the tail is the LRU position and is dropped first.
@MainActor
final class RecentlyViewedCache {
    static let shared = RecentlyViewedCache(capacity: 15)

    /// Maximum number of products retained per user.
    let capacity: Int

    private var entriesByUser: [String: [Product]] = [:]

    init(capacity: Int) {
        self.capacity = max(capacity, 1)
    }

    // MARK: - Public API

    /// Records a product view, promoting it to the MRU position.
    /// Own listings are excluded — pass `isOwnListing: true` to skip recording.
    func record(_ product: Product, for userID: String?, isOwnListing: Bool = false) {
        guard !isOwnListing else { return }
        let key = namespace(for: userID)
        var entries = loaded(for: key)

        // Remove any existing entry so the product moves to front (MRU).
        entries.removeAll { $0.id == product.id }
        entries.insert(product, at: 0)

        // Evict LRU tail when over capacity.
        if entries.count > capacity {
            entries = Array(entries.prefix(capacity))
        }

        entriesByUser[key] = entries
        persist(entries, for: key)
    }

    /// Returns up to `capacity` products in MRU-first order for the given user.
    func products(for userID: String?) -> [Product] {
        let key = namespace(for: userID)
        return loaded(for: key)
    }

    /// Removes all cached entries for the given user (e.g., on sign-out).
    func clear(for userID: String?) {
        let key = namespace(for: userID)
        entriesByUser[key] = []
        UserDefaults.standard.removeObject(forKey: defaultsKey(for: key))
    }

    // MARK: - Private helpers

    private func namespace(for userID: String?) -> String {
        guard let userID, !userID.isEmpty else { return "guest" }
        return userID
    }

    private func defaultsKey(for namespace: String) -> String {
        "unimarket.recently-viewed.\(namespace)"
    }

    /// Returns the in-memory entries if already loaded, otherwise hydrates
    /// from UserDefaults (cold-start path).
    private func loaded(for key: String) -> [Product] {
        if let cached = entriesByUser[key] {
            return cached
        }
        let fromDisk = loadFromDisk(for: key)
        entriesByUser[key] = fromDisk
        return fromDisk
    }

    private func persist(_ products: [Product], for key: String) {
        guard let data = try? JSONEncoder().encode(products) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey(for: key))
    }

    private func loadFromDisk(for key: String) -> [Product] {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey(for: key)),
            let products = try? JSONDecoder().decode([Product].self, from: data)
        else { return [] }
        return Array(products.prefix(capacity))
    }
}
