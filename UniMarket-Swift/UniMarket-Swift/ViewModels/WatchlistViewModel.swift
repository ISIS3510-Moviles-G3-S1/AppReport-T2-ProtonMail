// ViewModels/WatchlistViewModel.swift
// UniMarket-Swift
//
// Drives the WatchlistView and WatchlistAddButton.
// Refresh path uses Swift structured concurrency exclusively (no DispatchQueue).

import Foundation
import Combine

@MainActor
final class WatchlistViewModel: ObservableObject {

    // MARK: - Published state

    @Published var watchedItems: [WatchlistEntry] = []
    /// Latest price snapshot per productID, from the in-memory cache.
    @Published var cachedPrices: [String: WatchlistPriceSnapshot] = [:]
    @Published var isRefreshing: Bool = false
    @Published var isConnected: Bool = true

    // MARK: - Private

    /// Stored so callers can cancel in-flight refreshes (e.g., re-trigger on pull-to-refresh).
    private var refreshTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let store = WatchlistUserDefaultsStore.shared

    /// Reads userID lazily from the shared session so the ViewModel doesn't need
    /// the SessionManager injected (which avoids DI complexity at initialisation time).
    private var userID: String? { SessionManager.shared.uid }

    // MARK: - Init / teardown

    init() {
        loadWatchedItems()
        hydrateFromCache()
        bindConnectivity()
    }

    deinit {
        refreshTask?.cancel()
    }

    // MARK: - Watchlist membership

    func isWatched(_ productID: String) -> Bool {
        watchedItems.contains { $0.id == productID }
    }

    /// Adds a product to the watchlist and immediately seeds the cache with
    /// its current price so the row renders without waiting for the first refresh.
    func addToWatchlist(_ product: Product) {
        guard let uid = userID else { return }

        let entry = WatchlistEntry(
            id: product.id,
            title: product.title,
            imageURL: product.primaryImageURL,
            originalPrice: product.price,
            addedAt: Date()
        )

        store.add(entry: entry, for: uid)

        if !watchedItems.contains(where: { $0.id == product.id }) {
            watchedItems.append(entry)
        }

        // Seed the price cache with the price known at add-time
        WatchlistPriceCache.shared.store(
            productID: product.id,
            price: product.price,
            previousPrice: nil
        )
        cachedPrices[product.id] = WatchlistPriceSnapshot(
            productID: product.id,
            price: product.price,
            previousPrice: nil,
            cachedAt: Date()
        )
    }

    /// Removes a product from the watchlist and clears its cached price entry.
    func removeFromWatchlist(productID: String) {
        guard let uid = userID else { return }
        store.remove(id: productID, for: uid)
        watchedItems.removeAll { $0.id == productID }
        cachedPrices.removeValue(forKey: productID)
    }

    // MARK: - Price refresh

    /// Cancels any in-flight refresh, captures a snapshot of the current prices
    /// on MainActor, then fans out one background child-task per watched product.
    /// Results are applied to `cachedPrices` progressively as each child completes.
    func refreshAllPrices() {
        guard isConnected else { return }

        // Cancel the previous run; a new Task replaces it below
        refreshTask?.cancel()

        // ── Both captured on @MainActor before the Task is created ──────────────
        let previousPrices = cachedPrices           // snapshot for delta calculation
        let items = watchedItems                     // stable copy of the list

        isRefreshing = true

        // Task inherits @MainActor from this class, so all property mutations
        // inside (isRefreshing, cachedPrices) are main-actor-safe.
        refreshTask = Task {
            defer { isRefreshing = false }

            await withTaskGroup(of: (String, Int)?.self) { group in
                for item in items {
                    let productID = item.id
                    // Child tasks run at background priority so they don't block
                    // the main actor while waiting on the network.
                    group.addTask(priority: .background) {
                        do {
                            let price = try await ProductService.shared.fetchCurrentPrice(
                                for: productID
                            )
                            return (productID, price)
                        } catch {
                            return nil
                        }
                    }
                }

                // Collect results progressively; exit early on cancellation.
                // When the outer refreshTask is cancelled, Task.isCancelled
                // becomes true and we break — the task group then cancels all
                // pending child tasks automatically.
                for await result in group {
                    if Task.isCancelled { break }
                    guard let (productID, price) = result else { continue }

                    let previous = previousPrices[productID]?.price
                    let snapshot = WatchlistPriceSnapshot(
                        productID: productID,
                        price: price,
                        previousPrice: previous,
                        cachedAt: Date()
                    )
                    // Write through to the shared cache
                    WatchlistPriceCache.shared.store(
                        productID: productID,
                        price: price,
                        previousPrice: previous
                    )
                    // Update the published dictionary on MainActor (Task context)
                    cachedPrices[productID] = snapshot
                }
            }
        }
    }

    /// `async` wrapper used by `WatchlistView.refreshable` so the pull-to-refresh
    /// spinner stays visible until the task group finishes.
    func refreshAndWait() async {
        refreshAllPrices()
        await refreshTask?.value
    }

    // MARK: - Private helpers

    /// Reads persisted entries from UserDefaults on init.
    private func loadWatchedItems() {
        guard let uid = userID else {
            watchedItems = []
            return
        }
        watchedItems = store.loadEntries(for: uid)
    }

    /// Populates `cachedPrices` from the shared in-memory cache on init,
    /// so rows show their last-known price without waiting for a refresh.
    private func hydrateFromCache() {
        for item in watchedItems {
            switch WatchlistPriceCache.shared.lookup(productID: item.id) {
            case .hit(let snapshot), .stale(let snapshot):
                cachedPrices[item.id] = snapshot
            case .miss:
                break
            }
        }
    }

    /// Subscribes to `NetworkMonitor.$isConnected` via Combine so the view
    /// disables the refresh button automatically when the device goes offline.
    private func bindConnectivity() {
        NetworkMonitor.shared.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.isConnected = connected
            }
            .store(in: &cancellables)
    }
}
