import Foundation

// UserDefaults is used here because favorites are small, user-specific key-value data
// that must persist across launches without the overhead of a full database
final class FavoritesCacheManager {
    static let shared = FavoritesCacheManager()

    private let defaults = UserDefaults.standard
    private let favoritesKey = "favorites.cached-items"
    private let lastInteractionKey = "user.last-interaction"

    private init() {}

    // MARK: - Interaction Tracking

    func saveLastInteraction() {
        defaults.set(Date(), forKey: lastInteractionKey)
    }

    func getLastInteraction() -> Date? {
        defaults.object(forKey: lastInteractionKey) as? Date
    }

    // MARK: - Favorites Cache
    // JSONEncoder/JSONDecoder let us store typed Swift structs in UserDefaults
    // by converting them to/from raw Data via Codable conformance

    func saveFavorites(_ items: [FavoriteItem]) {
        guard let encoded = try? JSONEncoder().encode(items) else { return }
        defaults.set(encoded, forKey: favoritesKey)
    }

    func loadFavorites() -> [FavoriteItem] {
        guard
            let data = defaults.data(forKey: favoritesKey),
            let items = try? JSONDecoder().decode([FavoriteItem].self, from: data)
        else { return [] }
        return items
    }

    func addFavorite(_ item: FavoriteItem) {
        var current = loadFavorites()
        guard !current.contains(where: { $0.id == item.id }) else { return }
        current.append(item)
        saveFavorites(current)
    }

    func removeFavorite(itemId: String) {
        saveFavorites(loadFavorites().filter { $0.id != itemId })
    }

    func clearUserData() {
        defaults.removeObject(forKey: favoritesKey)
        defaults.removeObject(forKey: lastInteractionKey)
    }
}
