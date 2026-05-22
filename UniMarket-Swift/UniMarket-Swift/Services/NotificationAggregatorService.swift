import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Namespace (non-instantiable enum) housing the four static aggregator functions.
///
/// Each function maps to one source in the `withTaskGroup` inside
/// `NotificationsViewModel.refresh(chatStore:productStore:)`:
///
/// | Function               | Priority          | I/O                                  |
/// |------------------------|-------------------|--------------------------------------|
/// | unreadMessageItems     | .userInitiated    | In-memory ChatStore scan             |
/// | priceDropItems         | .utility          | WatchlistPriceCache (UserDefaults)   |
/// | syncStatusItems        | .background       | File-system index.json reads (Task.detached) |
/// | recentActivityItems    | .background       | Firestore `activity_feed` query      |
enum NotificationAggregatorService {

    // MARK: - Source 1 — Unread Messages

    /// Scans the in-memory ChatStore for conversations with unread messages.
    /// Runs at `.userInitiated` priority — cheapest of the four (no I/O).
    static func unreadMessageItems(chatStore: ChatStore) async -> NotificationBatch {
        let items = chatStore.conversations
            .filter { $0.unreadCount > 0 }
            .sorted { ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast) }
            .map { conv in
                NotificationItem(
                    id:             "msg_\(conv.id)",
                    type:           .unreadMessage,
                    title:          conv.otherParticipantName,
                    subtitle:       conv.lastMessageText,
                    timestamp:      conv.lastMessageAt ?? Date(),
                    deepLinkTarget: .chatThread(conversationID: conv.id)
                )
            }
        return .messages(items)
    }

    // MARK: - Source 2 — Price Drops

    /// Reads `WatchlistPriceCache` (UserDefaults only) to detect price drops.
    /// The cache was updated by the ViewModel's pre-flight before this task runs.
    /// Runs at `.utility` priority — UserDefaults read, no network.
    static func priceDropItems(watchlistIDs: [String]) async -> NotificationBatch {
        let drops = WatchlistPriceCache.shared.detectedDrops(for: watchlistIDs)
        let items = drops.map { snapshot -> NotificationItem in
            let dropped  = snapshot.baselinePrice - snapshot.currentPrice
            let pct      = snapshot.baselinePrice > 0
                ? Int(Double(dropped) / Double(snapshot.baselinePrice) * 100)
                : 0
            let subtitle = "Price dropped \(pct)% — now $\(snapshot.currentPrice.formattedCOP)"
            return NotificationItem(
                id:             "price_\(snapshot.productID)",
                type:           .priceDrop,
                title:          snapshot.title,
                subtitle:       subtitle,
                timestamp:      snapshot.detectedAt,
                deepLinkTarget: .productDetail(productID: snapshot.productID)
            )
        }
        return .priceDrops(items)
    }

    // MARK: - Source 3 — Sync Status

    /// Reads the three pending-queue `index.json` files on disk.
    ///
    /// **Must use `Task.detached(priority: .background)`** for the file-system
    /// reads — synchronous I/O must never block the main actor.
    static func syncStatusItems(userID: String) async -> NotificationBatch {
        return await Task.detached(priority: .background) {
            var items: [NotificationItem] = []
            let now = Date()

            let pendingListings = PendingListingsStore.shared.count(for: userID)
            if pendingListings > 0 {
                items.append(NotificationItem(
                    id:             "sync_listings",
                    type:           .syncStatus,
                    title:          "Pending Listings",
                    subtitle:       "\(pendingListings) listing\(pendingListings == 1 ? "" : "s") waiting to sync",
                    timestamp:      now,
                    deepLinkTarget: .syncQueue
                ))
            }

            let pendingMessages = PendingChatMessagesStore.shared.count(for: userID)
            if pendingMessages > 0 {
                items.append(NotificationItem(
                    id:             "sync_messages",
                    type:           .syncStatus,
                    title:          "Pending Messages",
                    subtitle:       "\(pendingMessages) message\(pendingMessages == 1 ? "" : "s") waiting to sync",
                    timestamp:      now,
                    deepLinkTarget: .syncQueue
                ))
            }

            let pendingFavorites = PendingFavoritesStore.shared.count(for: userID)
            if pendingFavorites > 0 {
                items.append(NotificationItem(
                    id:             "sync_favorites",
                    type:           .syncStatus,
                    title:          "Pending Favorites",
                    subtitle:       "\(pendingFavorites) favorite\(pendingFavorites == 1 ? "" : "s") waiting to sync",
                    timestamp:      now,
                    deepLinkTarget: .syncQueue
                ))
            }

            let pendingMutations = PendingListingMutationsStore.shared.count(for: userID)
            if pendingMutations > 0 {
                items.append(NotificationItem(
                    id:             "sync_mutations",
                    type:           .syncStatus,
                    title:          "Pending Edits",
                    subtitle:       "\(pendingMutations) listing edit\(pendingMutations == 1 ? "" : "s") waiting to sync",
                    timestamp:      now,
                    deepLinkTarget: .syncQueue
                ))
            }

            return NotificationBatch.syncStatus(items)
        }.value
    }

    // MARK: - Source 4 — Recent Activity

    /// Queries `users/{uid}/activity_feed` ordered by timestamp descending, limit 10.
    /// Runs at `.background` priority — Firestore network call.
    static func recentActivityItems(userID: String) async -> NotificationBatch {
        let db = Firestore.firestore()
        do {
            let snapshot = try await db
                .collection("users")
                .document(userID)
                .collection("activity_feed")
                .order(by: "timestamp", descending: true)
                .limit(to: 10)
                .getDocuments()

            let items = snapshot.documents.compactMap { doc -> NotificationItem? in
                let data      = doc.data()
                guard
                    let title     = data["title"]     as? String,
                    let timestamp = (data["timestamp"] as? Timestamp)?.dateValue()
                else { return nil }

                let subtitle  = data["subtitle"]  as? String ?? ""
                let productID = data["productID"] as? String

                let target: DeepLinkTarget = productID.map { .productDetail(productID: $0) } ?? .activity

                return NotificationItem(
                    id:             "activity_\(doc.documentID)",
                    type:           .recentActivity,
                    title:          title,
                    subtitle:       subtitle,
                    timestamp:      timestamp,
                    deepLinkTarget: target
                )
            }
            return .recentActivity(items)
        } catch {
            return .recentActivity([])
        }
    }
}

// MARK: - Private formatting helper

private extension Int {
    /// Formats Colombian peso amounts with thousands separators (no decimals).
    var formattedCOP: String {
        let formatter = NumberFormatter()
        formatter.numberStyle          = .decimal
        formatter.groupingSeparator    = "."
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
