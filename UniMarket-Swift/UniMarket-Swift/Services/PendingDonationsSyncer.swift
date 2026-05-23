import Foundation
import Combine
import FirebaseFirestore
import SwiftData

@MainActor
final class PendingDonationsSyncer: ObservableObject {
    static let shared = PendingDonationsSyncer()

    @Published private(set) var pendingClaimIDs: Set<String> = []
    @Published private(set) var pendingDecisionIDs: Set<String> = []
    @Published private(set) var isDraining: Bool = false

    private var container: ModelContainer?
    private var connectivityCancellable: AnyCancellable?

    private init() {}

    func bind(to monitor: NetworkMonitor, container: ModelContainer) {
        self.container = container
        connectivityCancellable = monitor.$isConnected
            .removeDuplicates()
            .sink { [weak self] connected in
                guard let self, connected else { return }
                Task { await self.drain() }
            }
        Task { await refreshPendingCounts() }
    }

    func resumeIfNeeded() async {
        await refreshPendingCounts()
        if NetworkMonitor.shared.isConnected {
            await drain()
        }
    }

    // MARK: - Public mutation helpers (called from ViewModels)

    func addPendingClaim(_ id: String) { pendingClaimIDs.insert(id) }
    func removePendingClaim(_ id: String) { pendingClaimIDs.remove(id) }
    func addPendingDecision(_ id: String) { pendingDecisionIDs.insert(id) }
    func removePendingDecision(_ id: String) { pendingDecisionIDs.remove(id) }

    // MARK: - Drain

    func drain() async {
        guard !isDraining, let container else { return }
        guard NetworkMonitor.shared.isConnected else { return }

        isDraining = true
        defer {
            isDraining = false
            Task { await refreshPendingCounts() }
        }

        let ctx = ModelContext(container)

        // Drain unsynced claims first — seller can't approve a request that isn't in Firestore yet
        let claimDescriptor = FetchDescriptor<DonationRequestRecord>(
            predicate: #Predicate { $0.isSyncedClaim == false }
        )
        if let claims = try? ctx.fetch(claimDescriptor) {
            for record in claims {
                let request = record.toDonationRequest()
                do {
                    try await DonationService.shared.createDonationRequest(request)
                    record.isSyncedClaim = true
                    record.retryCount = 0
                    record.lastSyncAttemptAt = Date()
                    pendingClaimIDs.remove(record.id)
                } catch {
                    record.retryCount += 1
                    record.lastSyncAttemptAt = Date()
                }
            }
            try? ctx.save()
        }

        // Then drain decisions (only for already-synced claims)
        let decisionDescriptor = FetchDescriptor<DonationRequestRecord>(
            predicate: #Predicate { $0.isSyncedDecision == false && $0.isSyncedClaim == true }
        )
        if let decisions = try? ctx.fetch(decisionDescriptor) {
            for record in decisions {
                do {
                    try await DonationService.shared.updateDonationRequestStatus(record.id, status: record.status)
                    record.isSyncedDecision = true
                    record.retryCount = 0
                    record.lastSyncAttemptAt = Date()
                    pendingDecisionIDs.remove(record.id)
                } catch {
                    record.retryCount += 1
                    record.lastSyncAttemptAt = Date()
                }
            }
            try? ctx.save()
        }
    }

    private func refreshPendingCounts() async {
        guard let container else { return }
        let task = Task.detached(priority: .utility) {
            let ctx = ModelContext(container)
            let claimDesc = FetchDescriptor<DonationRequestRecord>(
                predicate: #Predicate { $0.isSyncedClaim == false }
            )
            let decisionDesc = FetchDescriptor<DonationRequestRecord>(
                predicate: #Predicate { $0.isSyncedDecision == false && $0.isSyncedClaim == true }
            )
            let claims = (try? ctx.fetch(claimDesc))?.map { $0.id } ?? []
            let decisions = (try? ctx.fetch(decisionDesc))?.map { $0.id } ?? []
            return (Set(claims), Set(decisions))
        }
        let (claims, decisions) = await task.value
        pendingClaimIDs = claims
        pendingDecisionIDs = decisions
    }
}
