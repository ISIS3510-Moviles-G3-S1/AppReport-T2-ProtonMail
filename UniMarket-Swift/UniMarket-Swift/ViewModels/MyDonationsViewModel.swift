import Foundation
import Combine
import SwiftData

@MainActor
final class MyDonationsViewModel: ObservableObject {
    @Published var givenDonations: [DonationRequestRecord] = []
    @Published var claimedDonations: [DonationRequestRecord] = []
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

            let ctx = ModelContext(container)
            let uid = userID

            let givenDescriptor = FetchDescriptor<DonationRequestRecord>(
                predicate: #Predicate { $0.sellerID == uid },
                sortBy: [SortDescriptor(\DonationRequestRecord.createdAt, order: .reverse)]
            )
            let claimedDescriptor = FetchDescriptor<DonationRequestRecord>(
                predicate: #Predicate { $0.requesterID == uid },
                sortBy: [SortDescriptor(\DonationRequestRecord.createdAt, order: .reverse)]
            )

            givenDonations = (try? ctx.fetch(givenDescriptor)) ?? []
            claimedDonations = (try? ctx.fetch(claimedDescriptor)) ?? []
            updateSyncingCount()
            errorMessage = nil
        }
    }

    private func updateSyncingCount() {
        let unsynced = claimedDonations.filter { !$0.isSyncedClaim }.count +
                       givenDonations.filter { !$0.isSyncedDecision }.count
        syncingCount = unsynced
    }

    func cancel() {
        refreshTask?.cancel()
    }

    deinit {
        refreshTask?.cancel()
    }
}
