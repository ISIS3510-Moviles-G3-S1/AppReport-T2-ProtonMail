import Foundation

// Persists user-configurable app settings to UserDefaults.
// Each preference has a typed @Published property; writes flush to disk immediately on set.
// This separates app preferences from data caches (FavoritesCacheManager, RecentlyViewedCache),
// which store domain objects, not settings.
//
// Sort option is stored as its raw String value so this Services-layer class does not
// import ViewModel types. The ViewModel converts to SearchSortOption on read.
final class UserPreferencesStore: ObservableObject {
    static let shared = UserPreferencesStore()

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let defaultSortOptionRaw  = "prefs.browse.defaultSort"
        static let defaultCategoryFilter = "prefs.browse.defaultCategory"
        static let showOfflineBanner     = "prefs.ui.showOfflineBanner"
    }

    // MARK: - Published preferences

    // Raw value of SearchSortOption (e.g. "Relevance", "Price: Low to High").
    // ViewModel layer converts this to the typed enum via SearchSortOption(rawValue:).
    @Published var defaultSortOptionRaw: String {
        didSet { defaults.set(defaultSortOptionRaw, forKey: Keys.defaultSortOptionRaw) }
    }

    // Pre-selected tag filter applied when Browse tab opens (empty string = none).
    @Published var defaultCategoryFilter: String {
        didSet { defaults.set(defaultCategoryFilter, forKey: Keys.defaultCategoryFilter) }
    }

    // Controls whether the offline connectivity banner appears across the app.
    @Published var showOfflineBanner: Bool {
        didSet { defaults.set(showOfflineBanner, forKey: Keys.showOfflineBanner) }
    }

    // MARK: - Init

    private init() {
        defaultSortOptionRaw = defaults.string(forKey: Keys.defaultSortOptionRaw) ?? ""
        defaultCategoryFilter = defaults.string(forKey: Keys.defaultCategoryFilter) ?? ""

        // showOfflineBanner defaults to true on first launch (key not yet set).
        if defaults.object(forKey: Keys.showOfflineBanner) != nil {
            showOfflineBanner = defaults.bool(forKey: Keys.showOfflineBanner)
        } else {
            showOfflineBanner = true
        }
    }

    // MARK: - Public API

    // Resets all preferences to factory defaults and removes the UserDefaults keys.
    func resetToDefaults() {
        [Keys.defaultSortOptionRaw, Keys.defaultCategoryFilter, Keys.showOfflineBanner].forEach {
            defaults.removeObject(forKey: $0)
        }
        defaultSortOptionRaw = ""
        defaultCategoryFilter = ""
        showOfflineBanner = true
    }
}
