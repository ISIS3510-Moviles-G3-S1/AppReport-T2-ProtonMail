import Foundation

struct DonationRequest: Identifiable, Hashable, Codable {
    let id: String
    let donationListingID: String
    let sellerID: String
    let requesterID: String
    let requesterMessage: String?
    var status: DonationRequestStatus
    let createdAt: Date
    var resolvedAt: Date?

    var statusRaw: String {
        get { status.rawValue }
        set { status = DonationRequestStatus(rawValue: newValue) ?? .pending }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case donationListingID
        case sellerID
        case requesterID
        case requesterMessage
        case status
        case createdAt
        case resolvedAt
    }

    init(
        id: String,
        donationListingID: String,
        sellerID: String,
        requesterID: String,
        requesterMessage: String? = nil,
        status: DonationRequestStatus = .pending,
        createdAt: Date = .now,
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.donationListingID = donationListingID
        self.sellerID = sellerID
        self.requesterID = requesterID
        self.requesterMessage = requesterMessage
        self.status = status
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
    }
}

enum DonationRequestStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case approved = "approved"
    case declined = "declined"
    case withdrawn = "withdrawn"

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .declined: return "Declined"
        case .withdrawn: return "Withdrawn"
        }
    }
}
