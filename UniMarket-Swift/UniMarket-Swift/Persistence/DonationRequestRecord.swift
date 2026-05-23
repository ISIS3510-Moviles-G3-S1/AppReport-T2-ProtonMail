import Foundation
import SwiftData

@Model final class DonationRequestRecord {
    @Attribute(.unique) var id: String
    var donationListingID: String
    var sellerID: String
    var requesterID: String
    var requesterMessage: String?
    var statusRaw: String
    var createdAt: Date
    var resolvedAt: Date?
    var isSyncedClaim: Bool
    var isSyncedDecision: Bool
    var lastSyncAttemptAt: Date?
    var retryCount: Int

    var status: DonationRequestStatus {
        get { .init(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: String,
        donationListingID: String,
        sellerID: String,
        requesterID: String,
        requesterMessage: String? = nil,
        status: DonationRequestStatus = .pending,
        createdAt: Date = .now,
        resolvedAt: Date? = nil,
        isSyncedClaim: Bool = false,
        isSyncedDecision: Bool = false,
        retryCount: Int = 0
    ) {
        self.id = id
        self.donationListingID = donationListingID
        self.sellerID = sellerID
        self.requesterID = requesterID
        self.requesterMessage = requesterMessage
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
        self.isSyncedClaim = isSyncedClaim
        self.isSyncedDecision = isSyncedDecision
        self.retryCount = retryCount
    }

    func toDonationRequest() -> DonationRequest {
        DonationRequest(
            id: id,
            donationListingID: donationListingID,
            sellerID: sellerID,
            requesterID: requesterID,
            requesterMessage: requesterMessage,
            status: status,
            createdAt: createdAt,
            resolvedAt: resolvedAt
        )
    }

    static func from(_ request: DonationRequest, isSyncedClaim: Bool = false, isSyncedDecision: Bool = false) -> DonationRequestRecord {
        DonationRequestRecord(
            id: request.id,
            donationListingID: request.donationListingID,
            sellerID: request.sellerID,
            requesterID: request.requesterID,
            requesterMessage: request.requesterMessage,
            status: request.status,
            createdAt: request.createdAt,
            resolvedAt: request.resolvedAt,
            isSyncedClaim: isSyncedClaim,
            isSyncedDecision: isSyncedDecision
        )
    }
}
