import Foundation
import SwiftData
import FirebaseFirestore
import Combine

@MainActor
final class IncomingDonationRequestsViewModel: ObservableObject {
    @Published var requests: [DonationRequestRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// Full profile (displayName + email) keyed by requester UID — surfaced by
    /// the incoming requests row so the seller can identify who's claiming.
    @Published var requesterProfiles: [String: CachedDonationRequester] = [:]

    private let sellerID: String
    private let container: ModelContainer
    private var refreshTask: Task<Void, Never>?
    private let db = Firestore.firestore()

    init(sellerID: String, container: ModelContainer) {
        self.sellerID = sellerID
        self.container = container
    }

    /// Convenience read used by the grouped-by-listing UI.
    func displayName(for uid: String) -> String {
        requesterProfiles[uid]?.displayName ?? "Loading name..."
    }

    func email(for uid: String) -> String {
        requesterProfiles[uid]?.email ?? "Loading email..."
    }

    func refresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            isLoading = true
            defer { isLoading = false }

            // 1. Pull from local SwiftData (predicate pushed into SQLite)
            let ctx = ModelContext(container)
            let sellerIDCapture = sellerID
            let descriptor = FetchDescriptor<DonationRequestRecord>(
                predicate: #Predicate { $0.sellerID == sellerIDCapture },
                sortBy: [SortDescriptor(\DonationRequestRecord.createdAt, order: .reverse)]
            )
            let local = (try? ctx.fetch(descriptor)) ?? []

            // 2. If online, also pull from Firestore and merge into local store
            //    so the seller sees requests that were created from another device
            //    (e.g. iOS user views requests created by Flutter users).
            if NetworkMonitor.shared.isConnected {
                if let remote = try? await DonationService.shared.fetchIncomingRequests(for: sellerID) {
                    for r in remote {
                        if let existing = local.first(where: { $0.id == r.id }) {
                            // Don't clobber an unsynced local decision with a stale remote status.
                            if existing.isSyncedDecision {
                                existing.status = r.status
                                existing.resolvedAt = r.resolvedAt
                            }
                        } else {
                            ctx.insert(DonationRequestRecord.from(r, isSyncedClaim: true, isSyncedDecision: true))
                        }
                    }
                    try? ctx.save()
                }
            }

            // 3. Re-fetch after merge so requests reflect what's on disk.
            requests = (try? ctx.fetch(descriptor)) ?? []

            // 4. Hydrate profiles using a bounded TaskGroup (multithreading rubric)
            let ids = Set(requests.map { $0.requesterID })
            let limiter = ConcurrencyLimiter(max: 8)
            let db = self.db

            await withTaskGroup(of: (String, CachedDonationRequester?).self) { group in
                for uid in ids {
                    group.addTask {
                        await limiter.wait()
                        defer { Task { await limiter.signal() } }

                        if let cached = await DonationRequesterProfileCache.shared.get(uid: uid) {
                            return (uid, cached)
                        }
                        let snap = try? await db.collection("users").document(uid).getDocument()
                        let data = snap?.data() ?? [:]
                        let name  = data["displayName"] as? String ?? "Unknown"
                        let email = data["email"] as? String
                        let pic   = data["profilePic"] as? String
                        let entry = await CachedDonationRequester(uid: uid, displayName: name, email: email, profilePicURL: pic)
                        await DonationRequesterProfileCache.shared.set(entry, for: uid)
                        return (uid, entry)
                    }
                }
                for await (uid, entry) in group {
                    if let entry { requesterProfiles[uid] = entry }
                }
            }

            errorMessage = nil
        }
    }

    func approveRequest(_ id: String) async {
        await mutateDecision(id, to: .approved)
    }

    func declineRequest(_ id: String) async {
        await mutateDecision(id, to: .declined)
    }

    private func mutateDecision(_ id: String, to newStatus: DonationRequestStatus) async {
        let ctx = ModelContext(container)
        let idCapture = id
        let descriptor = FetchDescriptor<DonationRequestRecord>(
            predicate: #Predicate { $0.id == idCapture }
        )
        guard let record = (try? ctx.fetch(descriptor))?.first else { return }

        let listingID = record.donationListingID
        let requesterID = record.requesterID
        let waitTime = Int(Date().timeIntervalSince(record.createdAt))

        record.status = newStatus
        record.resolvedAt = Date()
        record.isSyncedDecision = false
        try? ctx.save()

        PendingDonationsSyncer.shared.addPendingDecision(id)
        switch newStatus {
        case .approved:
            AnalyticsService.shared.track(
                .donationApproved(listingID: listingID, requesterID: requesterID, waitTimeSeconds: waitTime)
            )
        case .declined:
            AnalyticsService.shared.track(
                .donationDeclined(listingID: listingID, requesterID: requesterID)
            )
        default:
            break
        }

        if NetworkMonitor.shared.isConnected {
            if (try? await DonationService.shared.updateDonationRequestStatus(id, status: newStatus)) != nil {
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
