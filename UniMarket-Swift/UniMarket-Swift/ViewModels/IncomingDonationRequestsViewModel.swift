import Foundation
import SwiftData
import FirebaseFirestore
import Combine

@MainActor
final class IncomingDonationRequestsViewModel: ObservableObject {
    @Published var requests: [DonationRequestRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// displayName keyed by requester UID, hydrated from cache + Firestore
    @Published var requesterNames: [String: String] = [:]

    private let sellerID: String
    private let container: ModelContainer
    private var refreshTask: Task<Void, Never>?
    private let db = Firestore.firestore()

    init(sellerID: String, container: ModelContainer) {
        self.sellerID = sellerID
        self.container = container
    }

    func refresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            isLoading = true
            defer { isLoading = false }

            // Fetch from local SwiftData (predicate pushed into SQLite)
            let ctx = ModelContext(container)
            let sellerIDCapture = sellerID
            let descriptor = FetchDescriptor<DonationRequestRecord>(
                predicate: #Predicate { $0.sellerID == sellerIDCapture },
                sortBy: [SortDescriptor(\DonationRequestRecord.createdAt, order: .reverse)]
            )
            requests = (try? ctx.fetch(descriptor)) ?? []

            // Hydrate requester display names using TaskGroup + ConcurrencyLimiter
            let ids = Set(requests.map { $0.requesterID })
            let limiter = ConcurrencyLimiter(max: 8)
            let db = self.db

            await withTaskGroup(of: (String, String?).self) { group in
                for uid in ids {
                    group.addTask {
                        await limiter.wait()
                        defer { Task { await limiter.signal() } }

                        // Try the shared profile cache first
                        if let cached = await DonationRequesterProfileCache.shared.get(uid: uid) {
                            return (uid, cached.displayName)
                        }
                        if let cached = await UserProfileCache.shared.lookup(uid: uid) {
                            return (uid, cached.displayName)
                        }

                        // Firestore fallback
                        let snap = try? await db.collection("users").document(uid).getDocument()
                        let name = snap?.data()?["displayName"] as? String ?? "Unknown"
                        let pic  = snap?.data()?["profilePic"] as? String
                        let entry = await CachedDonationRequester(uid: uid, displayName: name, profilePicURL: pic)
                        await DonationRequesterProfileCache.shared.set(entry, for: uid)
                        return (uid, name)
                    }
                }
                for await (uid, name) in group {
                    requesterNames[uid] = name
                }
            }

            errorMessage = nil
        }
    }

    func approveRequest(_ id: String) async {
        let ctx = ModelContext(container)
        let idCapture = id
        let descriptor = FetchDescriptor<DonationRequestRecord>(
            predicate: #Predicate { $0.id == idCapture }
        )
        guard let record = (try? ctx.fetch(descriptor))?.first else { return }

        let waitTime = Int(Date().timeIntervalSince(record.createdAt))
        let listingID = record.donationListingID
        let requesterID = record.requesterID

        record.status = .approved
        record.resolvedAt = Date()
        record.isSyncedDecision = false
        try? ctx.save()

        PendingDonationsSyncer.shared.addPendingDecision(id)
        AnalyticsService.shared.track(
            .donationApproved(listingID: listingID, requesterID: requesterID, waitTimeSeconds: waitTime)
        )

        if NetworkMonitor.shared.isConnected {
            if (try? await DonationService.shared.updateDonationRequestStatus(id, status: .approved)) != nil {
                record.isSyncedDecision = true
                try? ctx.save()
                PendingDonationsSyncer.shared.removePendingDecision(id)
            }
        }
        refresh()
    }

    func declineRequest(_ id: String) async {
        let ctx = ModelContext(container)
        let idCapture = id
        let descriptor = FetchDescriptor<DonationRequestRecord>(
            predicate: #Predicate { $0.id == idCapture }
        )
        guard let record = (try? ctx.fetch(descriptor))?.first else { return }

        let listingID = record.donationListingID
        let requesterID = record.requesterID

        record.status = .declined
        record.resolvedAt = Date()
        record.isSyncedDecision = false
        try? ctx.save()

        PendingDonationsSyncer.shared.addPendingDecision(id)
        AnalyticsService.shared.track(
            .donationDeclined(listingID: listingID, requesterID: requesterID)
        )

        if NetworkMonitor.shared.isConnected {
            if (try? await DonationService.shared.updateDonationRequestStatus(id, status: .declined)) != nil {
                record.isSyncedDecision = true
                try? ctx.save()
                PendingDonationsSyncer.shared.removePendingDecision(id)
            }
        }
        refresh()
    }

    func cancel() {
        refreshTask?.cancel()
    }
}

// MARK: - ConcurrencyLimiter

/// Actor that gates concurrent task execution to a fixed cap.
/// Mirrors the limiter used in WatchlistViewModel for campus-Wi-Fi safety.
actor ConcurrencyLimiter {
    private let max: Int
    private var running = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []

    init(max: Int) { self.max = max }

    func wait() async {
        if running < max { running += 1; return }
        await withCheckedContinuation { waiting.append($0) }
        running += 1
    }

    func signal() {
        running -= 1
        if let next = waiting.first {
            waiting.removeFirst()
            next.resume()
        }
    }
}
