import Foundation
import Combine

@MainActor
final class DonationsBrowseViewModel: ObservableObject {
    /// Filtered listings for display. The raw set is kept in `allListings` so
    /// changing category doesn't require a network round-trip.
    @Published private(set) var listings: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastRefreshTime: Date?
    @Published var offlineSnapshot: DonationSnapshot?
    /// Currently selected category chip — "all" by default. Filter is applied
    /// client-side so chip taps are instant.
    @Published private(set) var selectedCategory: String = "all"

    private var allListings: [Product] = []
    private var refreshTask: Task<Void, Never>?

    /// Same category set the Flutter app exposes, in the same order.
    static let categories: [(key: String, label: String)] = [
        ("all", "All Items"),
        ("clothing", "Clothing"),
        ("shoes", "Shoes"),
        ("accessories", "Accessories"),
        ("eco", "Eco")
    ]

    func refresh(forceNetwork: Bool = false) {
        refreshTask?.cancel()
        refreshTask = Task {
            isLoading = true
            defer { isLoading = false }

            // Try the all-category LRU first unless force-refresh
            if !forceNetwork, let cached = DonationListingsLRU.shared.get(for: "all") {
                allListings = cached
                applyFilter()
                return
            }

            do {
                // Parallel pre-flight: listings + (future) per-listing counts
                async let listingsTask = DonationService.shared.fetchDonationListings()
                async let countsTask  = DonationService.shared.fetchRequestCountsPerListing([])
                let (donationListings, _) = try await (listingsTask, countsTask)

                allListings = donationListings
                lastRefreshTime = Date()
                offlineSnapshot = nil
                errorMessage = nil

                // Refresh LRU keyed by "all" so the next visit hits cache.
                DonationListingsLRU.shared.set(donationListings, for: "all")
                // Per-tag warm cache too — useful when the user picks a chip first.
                for (tag, products) in Dictionary(grouping: donationListings, by: { $0.tags.first ?? "uncategorized" }) {
                    DonationListingsLRU.shared.set(products, for: tag)
                }

                DonationOfflineSnapshotStore.persist(donationListings)
                AnalyticsService.shared.track(.donationBrowsed(countShown: donationListings.count))

                applyFilter()
            } catch {
                errorMessage = error.localizedDescription
                loadOfflineSnapshot()
            }
        }
    }

    func selectCategory(_ category: String) {
        selectedCategory = category
        applyFilter()
    }

    func loadOfflineSnapshot() {
        guard let snapshot = DonationOfflineSnapshotStore.load() else {
            allListings = []
            applyFilter()
            return
        }
        offlineSnapshot = snapshot
        // Reconstruct minimal Product objects from the snapshot for rendering.
        allListings = snapshot.listings.map { s in
            Product(
                id: s.id,
                title: s.title,
                price: 0,
                sellerName: s.sellerName,
                tags: [s.categoryTag],
                imageURLs: s.imageURL.map { [$0] } ?? [],
                kind: .donation
            )
        }
        applyFilter()
    }

    func cancel() {
        refreshTask?.cancel()
    }

    deinit {
        refreshTask?.cancel()
    }

    // MARK: - Private

    /// Match Flutter: "all" shows everything; otherwise match against tags OR conditionTag.
    private func applyFilter() {
        if selectedCategory == "all" {
            listings = allListings
            return
        }
        let key = selectedCategory.lowercased()
        listings = allListings.filter { product in
            product.tags.contains(where: { $0.lowercased() == key })
                || product.conditionTag.lowercased() == key
        }
    }
}
