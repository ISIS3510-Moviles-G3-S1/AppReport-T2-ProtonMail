import Foundation
import Combine
import SwiftData

@MainActor
final class MyDonationsViewModel: ObservableObject {
    /// Listings the user has POSTED as donations (Given tab) — sourced from
    /// the `listings` collection where kind=donation AND sellerId=me.
    @Published var givenListings: [Product] = []
    /// Requests the user has SUBMITTED to claim others' donations (Claimed tab) —
    /// sourced from the `donationRequests` SwiftData store, with online merge
    /// from Firestore.
    @Published var claimedRequests: [DonationRequestRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var syncingCount = 0

    private let userID: String
    private let container: ModelContainer
    private var refreshTask: Task<Void, Never>?

    init(userID: String, container: ModelContainer) {
        self.userID = userID
        self.container = container
    }

    func refresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            isLoading = true
            defer { isLoading = false }

            // Fetch both halves in parallel — independent network calls.
            async let givenTask = fetchGiven()
            async let claimedTask = fetchClaimed()
            let (given, claimed) = await (givenTask, claimedTask)

            givenListings = given
            claimedRequests = claimed
            syncingCount = claimed.filter { !$0.isSyncedClaim || !$0.isSyncedDecision }.count
            errorMessage = nil
        }
    }

    // MARK: - Private fetchers

    private func fetchGiven() async -> [Product] {
        guard NetworkMonitor.shared.isConnected else { return [] }
        return (try? await DonationService.shared.fetchMyDonationListings(sellerID: userID)) ?? []
    }

    private func fetchClaimed() async -> [DonationRequestRecord] {
        let ctx = ModelContext(container)
        let uid = userID
        let descriptor = FetchDescriptor<DonationRequestRecord>(
            predicate: #Predicate { $0.requesterID == uid },
            sortBy: [SortDescriptor(\DonationRequestRecord.createdAt, order: .reverse)]
        )

        // Merge in remote requests so a user can see claims they made on another device.
        if NetworkMonitor.shared.isConnected,
           let remote = try? await DonationService.shared.fetchRequestsForRequester(id: userID) {
            let existing = (try? ctx.fetch(descriptor)) ?? []
            for r in remote {
                if let local = existing.first(where: { $0.id == r.id }) {
                    if local.isSyncedDecision {
                        local.status = r.status
                        local.resolvedAt = r.resolvedAt
                    }
                } else {
                    ctx.insert(DonationRequestRecord.from(r, isSyncedClaim: true, isSyncedDecision: true))
                }
            }
            try? ctx.save()
        }

        return (try? ctx.fetch(descriptor)) ?? []
    }

    func cancel() {
        refreshTask?.cancel()
    }

    deinit {
        refreshTask?.cancel()
    }
}
