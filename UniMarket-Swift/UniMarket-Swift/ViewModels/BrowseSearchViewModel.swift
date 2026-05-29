import Foundation
import Combine
import FirebaseAuth

@MainActor
final class BrowseSearchViewModel: ObservableObject {
    @Published var query: String = "" {
        didSet { scheduleBrowseRefresh() }
    }
    @Published var selectedTag: String? = nil {
        didSet { scheduleBrowseRefresh() }
    }
    @Published var selectedConditions: Set<String> = [] {
        didSet { scheduleBrowseRefresh() }
    }
    @Published var onlyFavorites: Bool = false {
        didSet { scheduleBrowseRefresh() }
    }
    @Published var minRating: Double = 0 {
        didSet { scheduleBrowseRefresh() }
    }
    @Published var sortOption: SearchSortOption = .relevance {
        didSet { scheduleBrowseRefresh() }
    }
    @Published var minPrice: Int = 0 {
        didSet { scheduleBrowseRefresh() }
    }
    @Published var maxPrice: Int = 0 {
        didSet { scheduleBrowseRefresh() }
    }
    /// Filter chip — when on, only kind == .donation listings pass through.
    @Published var showDonationsOnly: Bool = false {
        didSet { scheduleBrowseRefresh() }
    }
    @Published private(set) var products: [Product] = [] {
        didSet {
            if oldValue.map(\.id) != products.map(\.id) {
                resetPriceRange()
            }
        }
    }
    @Published private(set) var filteredProducts: [Product] = []
    @Published private(set) var isSearching = false

    private let searchQueue = DispatchQueue(label: "search.browse.queue", qos: .userInitiated)
    private var pendingSearchWorkItem: DispatchWorkItem?

    var availableTags: [String] {
        Array(Set(products.flatMap { $0.tags })).sorted()
    }

    var availableConditions: [String] {
        Array(Set(products.map { $0.conditionTag })).sorted()
    }

    var priceBounds: ClosedRange<Int> {
        let prices = products.map { $0.price }
        let min = prices.min() ?? 0
        let max = prices.max() ?? 100
        return min...max
    }

    var activeFilterCount: Int {
        var count = 0
        if selectedTag != nil { count += 1 }
        if !selectedConditions.isEmpty { count += 1 }
        if onlyFavorites { count += 1 }
        if minRating > 0 { count += 1 }
        if minPrice != priceBounds.lowerBound || maxPrice != priceBounds.upperBound { count += 1 }
        if sortOption != .relevance { count += 1 }
        if showDonationsOnly { count += 1 }
        return count
    }

    init() {
        resetPriceRange()
        // Restore user's saved preferences from UserDefaults via UserPreferencesStore.
        let prefs = UserPreferencesStore.shared
        sortOption = SearchSortOption(rawValue: prefs.defaultSortOptionRaw) ?? .relevance
        let savedCategory = prefs.defaultCategoryFilter
        if !savedCategory.isEmpty {
            selectedTag = savedCategory
        }
    }

    func updateProducts(_ products: [Product]) {
        let uid = Auth.auth().currentUser?.uid
        self.products = products.filter { $0.sellerId != uid }
        scheduleBrowseRefresh()
    }

    func toggleFavorite(for product: Product) {
        guard let idx = products.firstIndex(where: { $0.id == product.id }) else { return }
        products[idx].isFavorite.toggle()
        scheduleBrowseRefresh()
    }

    func selectTag(_ tag: String?) {
        selectedTag = tag
    }

    func toggleCondition(_ condition: String) {
        if selectedConditions.contains(condition) {
            selectedConditions.remove(condition)
        } else {
            selectedConditions.insert(condition)
        }
    }

    func resetFilters() {
        selectedTag = nil
        selectedConditions.removeAll()
        onlyFavorites = false
        minRating = 0
        sortOption = .relevance
        showDonationsOnly = false
        resetPriceRange()
    }

    func applyRecentSearch(_ search: String) {
        query = search
    }

    deinit {
        pendingSearchWorkItem?.cancel()
    }

    func refreshBrowseResults() {
        let snapshot = BrowseSearchSnapshot(
            products: products,
            query: query,
            selectedTag: selectedTag,
            selectedConditions: selectedConditions,
            onlyFavorites: onlyFavorites,
            minRating: minRating,
            sortOption: sortOption,
            minPrice: minPrice,
            maxPrice: maxPrice,
            showDonationsOnly: showDonationsOnly
        )

        isSearching = true

        pendingSearchWorkItem?.cancel()

        var workItem: DispatchWorkItem?
        workItem = DispatchWorkItem { [snapshot] in
            let filteredProducts = SearchBrowseEngine.filterProducts(using: snapshot)

            DispatchQueue.main.async { [weak self] in
                guard
                    let self,
                    let workItem,
                    self.pendingSearchWorkItem === workItem,
                    !workItem.isCancelled
                else {
                    return
                }
                self.filteredProducts = filteredProducts
                self.isSearching = false
                self.pendingSearchWorkItem = nil
            }
        }

        guard let workItem else { return }
        pendingSearchWorkItem = workItem
        searchQueue.async(execute: workItem)
    }

    private func resetPriceRange() {
        minPrice = priceBounds.lowerBound
        maxPrice = priceBounds.upperBound
    }

    private func scheduleBrowseRefresh() {
        refreshBrowseResults()
    }
}
