import Foundation
import SwiftData
import Combine

@MainActor
final class DonationRequestViewModel: ObservableObject {
    @Published var message: String = ""
    @Published var isSubmitting = false
    @Published var isQueued = false
    @Published var errorMessage: String?

    let product: Product
    private let requesterID: String
    private let container: ModelContainer

    init(product: Product, requesterID: String, container: ModelContainer) {
        self.product = product
        self.requesterID = requesterID
        self.container = container
    }

    func submitClaim() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        let requestID = UUID().uuidString
        let request = DonationRequest(
            id: requestID,
            donationListingID: product.id,
            sellerID: product.sellerId,
            requesterID: requesterID,
            requesterMessage: message.isEmpty ? nil : message,
            status: .pending,
            createdAt: Date()
        )

        // Always write locally first (offline-first)
        let ctx = ModelContext(container)
        let record = DonationRequestRecord(
            id: request.id,
            donationListingID: request.donationListingID,
            sellerID: request.sellerID,
            requesterID: request.requesterID,
            requesterMessage: request.requesterMessage,
            status: request.status,
            createdAt: request.createdAt,
            isSyncedClaim: false
        )
        ctx.insert(record)
        try? ctx.save()

        PendingDonationsSyncer.shared.addPendingClaim(requestID)

        if NetworkMonitor.shared.isConnected {
            do {
                try await DonationService.shared.createDonationRequest(request)
                record.isSyncedClaim = true
                try? ctx.save()
                PendingDonationsSyncer.shared.removePendingClaim(requestID)

                // Track analytics after successful sync
                let timeSinceListing = Int(Date().timeIntervalSince(product.createdAt))
                AnalyticsService.shared.track(
                    .donationClaimed(
                        listingID: product.id,
                        sellerID: product.sellerId,
                        timeSinceListingSeconds: timeSinceListing
                    )
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            isQueued = true
            // Analytics fired when syncer drains the claim
        }
    }
}
