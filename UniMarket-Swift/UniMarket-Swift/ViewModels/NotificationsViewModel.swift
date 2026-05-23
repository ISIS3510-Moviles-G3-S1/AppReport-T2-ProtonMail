import Foundation
import Combine
import FirebaseAuth

// MARK: - NotificationsViewModel

/// Aggregates unread-message counts, price drops, pending-queue status, and
/// recent activity into a single `NotificationSections` model.
///
/// **Concurrency design**:
/// 1. `refresh` cancels any in-flight task, then launches a new one.
/// 2. Two pre-flight reads (`uid`, `watchlistIDs`) run concurrently via `async let`.
/// 3. A `withTaskGroup(of: NotificationBatch.self)` fans out to four child tasks —
///    each at a different QoS level matching its I/O cost.
/// 4. Each completed batch is dispatched to `@MainActor` *immediately* inside the
///    `for await` loop (progressive rendering — UI updates as sources complete).
/// 5. `Task.isCancelled` is checked before every `@MainActor` dispatch so a
///    pull-to-refresh mid-flight doesn't overwrite the newer in-progress data.
@MainActor
final class NotificationsViewModel: ObservableObject {

    // MARK: - Published state

    @Published var sections:        NotificationSections = .empty
    @Published var isLoading:       Bool                 = false
    @Published var lastRefreshedAt: Date?
    @Published var isConnected:     Bool                 = true

    // MARK: - Private

    private var refreshTask:              Task<Void, Never>?
    private var connectivityCancellable:  AnyCancellable?

    /// Retained so `bindConnectivity()` can auto-refresh on reconnect.
    private weak var _chatStore:    ChatStore?
    private weak var _productStore: ProductStore?

    // MARK: - Init

    init() {
        isConnected = NetworkMonitor.shared.isConnected
        bindConnectivity()
    }

    // MARK: - Refresh

    /// Cancels any previous refresh, then fans out to all four notification sources
    /// concurrently.  Results are applied progressively as each source completes.
    func refresh(chatStore: ChatStore, productStore: ProductStore) {
        // Cache store references for auto-refresh on reconnect.
        _chatStore    = chatStore
        _productStore = productStore

        // Cancel previous in-flight work.
        refreshTask?.cancel()
        isLoading = true

        refreshTask = Task { [weak self] in
            guard let self else { return }

            // ── Pre-flight: two concurrent reads ─────────────────────────────
            // uid: synchronous Auth call wrapped in a child task.
            // watchlistIDs: UserDefaults read offloaded to a .utility task.
            async let uid:          String?  = self.fetchCurrentUID()
            async let watchlistIDs: [String] = self.fetchWatchlistIDs()
            let (resolvedUID, resolvedWatchlistIDs) = await (uid, watchlistIDs)

            guard let userID = resolvedUID else {
                self.isLoading = false
                return
            }

            // ── Update price snapshot before launching group ──────────────────
            // WatchlistPriceCache compares in-memory products (no network) with
            // stored baselines. Must run on @MainActor to access productStore.products.
            WatchlistPriceCache.shared.update(
                products:     productStore.products,
                watchlistIDs: Set(resolvedWatchlistIDs)
            )

            guard !Task.isCancelled else {
                self.isLoading = false
                return
            }

            // ── Four-way concurrent fan-out ───────────────────────────────────
            await withTaskGroup(of: NotificationBatch.self) { group in

                // Source 1 — Unread messages (.userInitiated — in-memory, cheapest)
                group.addTask(priority: .userInitiated) {
                    await NotificationAggregatorService.unreadMessageItems(chatStore: chatStore)
                }

                // Source 2 — Price drops (.utility — UserDefaults, no network)
                group.addTask(priority: .utility) {
                    await NotificationAggregatorService.priceDropItems(watchlistIDs: resolvedWatchlistIDs)
                }

                // Source 3 — Sync status (.background — file-system index reads)
                group.addTask(priority: .background) {
                    await NotificationAggregatorService.syncStatusItems(userID: userID)
                }

                // Source 4 — Recent activity (.background — Firestore query)
                group.addTask(priority: .background) {
                    await NotificationAggregatorService.recentActivityItems(userID: userID)
                }

                // Progressive rendering: each batch is dispatched to @MainActor
                // the moment its source task completes — no waiting for the others.
                for await batch in group {
                    // Check cancellation BEFORE the dispatch.
                    guard !Task.isCancelled else { break }

                    await MainActor.run { [weak self] in
                        guard let self, !Task.isCancelled else { return }
                        self.apply(batch: batch)
                    }
                }
            }

            guard !Task.isCancelled else { return }

            // ── Finalise ─────────────────────────────────────────────────────
            let snapshot = self.sections
            NotificationsCache.shared.store(snapshot, userID: userID)
            self.lastRefreshedAt = Date()
            self.isLoading       = false

            AnalyticsService.shared.track(.notificationsRefreshed(
                messageCount:  snapshot.unreadMessages.count,
                priceDropCount: snapshot.priceDrops.count,
                syncCount:      snapshot.syncStatus.count,
                activityCount:  snapshot.recentActivity.count
            ))
        }
    }

    // MARK: - Cache hydration

    /// Populates `sections` from the two-tier cache without hitting the network.
    /// Called immediately on view appearance and when going offline.
    func hydrateFromCache() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        if let cached = NotificationsCache.shared.load(userID: uid) {
            sections = cached
        }
    }

    // MARK: - Connectivity binding

    /// Subscribes to `NetworkMonitor.$isConnected`.
    ///
    /// * **Reconnect** → auto-refresh with the last-known stores.
    /// * **Disconnect** → `hydrateFromCache()` immediately so the UI shows
    ///   stale data with the offline banner rather than an empty list.
    private func bindConnectivity() {
        connectivityCancellable = NetworkMonitor.shared.$isConnected
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                guard let self else { return }
                self.isConnected = connected
                if connected {
                    if let chat = self._chatStore, let products = self._productStore {
                        self.refresh(chatStore: chat, productStore: products)
                    }
                } else {
                    self.hydrateFromCache()
                }
            }
    }

    // MARK: - Private helpers

    /// Apply one aggregator result to the matching section field.
    private func apply(batch: NotificationBatch) {
        switch batch {
        case .messages(let items):      sections.unreadMessages = items
        case .priceDrops(let items):    sections.priceDrops     = items
        case .syncStatus(let items):    sections.syncStatus      = items
        case .recentActivity(let items): sections.recentActivity = items
        }
    }

    /// Nonisolated so it can serve as the RHS of an `async let` child task
    /// without forcing the parent onto the main actor.
    private nonisolated func fetchCurrentUID() async -> String? {
        Auth.auth().currentUser?.uid
    }

    /// Reads from UserDefaults (thread-safe) in a detached `.utility` task to
    /// avoid blocking the main actor during the pre-flight phase.
    private nonisolated func fetchWatchlistIDs() async -> [String] {
        await Task.detached(priority: .utility) {
            await FavoritesCacheManager.shared.loadFavorites().map(\.id)
        }.value
    }
}
