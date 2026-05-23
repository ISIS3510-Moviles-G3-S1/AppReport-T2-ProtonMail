import Foundation
import Combine

@MainActor
final class DonationsBrowseViewModel: ObservableObject {
    @Published var listings: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastRefreshTime: Date?
    @Published var offlineSnapshot: DonationOfflineSnapshotStore.DonationSnapshot?

    private var refreshTask: Task<Void, Never>?

    func refresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            isLoading = true
            defer { isLoading = false }

            do {
                // Parallel pre-flight: fetch listings and category counts concurrently
                async let listingsTask = DonationService.shared.fetchDonationListings()
                async let countsTask = DonationService.shared.fetchRequestCountsPerListing([])

                let (donationListings, _) = try await (listingsTask, countsTask)

                listings = donationListings
                lastRefreshTime = Date()

                // Cache by category for faster future lookups
                let grouped = Dictionary(grouping: donationListings) { $0.tags.first ?? "uncategorized" }
                for (category, products) in grouped {
                    DonationListingsLRU.shared.set(products, for: category)
                }

                // Persist snapshot for offline access
                DonationOfflineSnapshotStore.shared.persist(donationListings)

                // Track analytics
                AnalyticsService.shared.track(.donationBrowsed(countShown: listings.count))

                offlineSnapshot = nil
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
                loadOfflineSnapshot()
            }
        }
    }

    func loadCategory(_ category: String) {
        refreshTask?.cancel()
        refreshTask = Task {
            isLoading = true
            defer { isLoading = false }

            // Try LRU cache first (O(n) scan on capacity=16 — acceptable)
            if let cached = DonationListingsLRU.shared.get(for: category) {
                listings = cached
                return
            }

            do {
                let categoryListings = try await DonationService.shared.fetchDonationListingsByCategory(category)
                listings = categoryListings
                DonationListingsLRU.shared.set(categoryListings, for: category)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadOfflineSnapshot() {
        guard let snapshot = DonationOfflineSnapshotStore.shared.load() else { return }
        offlineSnapshot = snapshot
        // Reconstruct minimal Product objects from the snapshot for rendering
        listings = snapshot.listings.map { s in
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
    }

    func cancel() {
        refreshTask?.cancel()
    }

    deinit {
        refreshTask?.cancel()
    }
}
