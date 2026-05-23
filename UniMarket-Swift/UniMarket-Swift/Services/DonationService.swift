import Foundation
import FirebaseFirestore
import FirebaseAuth

/// All queries here intentionally avoid `.order(by:)` on a different field than
/// the equality filters — combining the two requires a composite Firestore
/// index, which adds friction for every new project clone. Lists are sorted
/// client-side (datasets here are small: tens to low hundreds of items).
/// This matches the Flutter app's pattern.
final class DonationService {
    static let shared = DonationService()

    private let db = Firestore.firestore()

    // MARK: - Donation Request CRUD

    func createDonationRequest(_ request: DonationRequest) async throws {
        let data: [String: Any] = [
            "donationListingID": request.donationListingID,
            "sellerID": request.sellerID,
            "requesterID": request.requesterID,
            "requesterMessage": request.requesterMessage ?? "",
            "status": request.status.rawValue,
            "createdAt": Timestamp(date: request.createdAt),
            "resolvedAt": request.resolvedAt.map { Timestamp(date: $0) } as Any? ?? NSNull()
        ]
        try await db.collection("donationRequests").document(request.id).setData(data)
    }

    func fetchDonationRequest(id: String) async throws -> DonationRequest? {
        let snapshot = try await db.collection("donationRequests").document(id).getDocument()
        guard snapshot.exists, let data = snapshot.data() else { return nil }
        return decodeDonationRequest(data, id: snapshot.documentID)
    }

    func fetchDonationRequests(for sellerID: String) async throws -> [DonationRequest] {
        let snapshot = try await db.collection("donationRequests")
            .whereField("sellerID", isEqualTo: sellerID)
            .getDocuments()
        return snapshot.documents
            .compactMap { decodeDonationRequest($0.data(), id: $0.documentID) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchIncomingRequests(for sellerID: String) async throws -> [DonationRequest] {
        let snapshot = try await db.collection("donationRequests")
            .whereField("sellerID", isEqualTo: sellerID)
            .getDocuments()
        return snapshot.documents
            .compactMap { decodeDonationRequest($0.data(), id: $0.documentID) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchRequestsForRequester(id: String) async throws -> [DonationRequest] {
        let snapshot = try await db.collection("donationRequests")
            .whereField("requesterID", isEqualTo: id)
            .getDocuments()
        return snapshot.documents
            .compactMap { decodeDonationRequest($0.data(), id: $0.documentID) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func updateDonationRequestStatus(_ requestID: String, status: DonationRequestStatus) async throws {
        try await db.collection("donationRequests").document(requestID).updateData([
            "status": status.rawValue,
            "resolvedAt": Timestamp(date: .now)
        ])
    }

    // MARK: - Listings (live in the `listings` collection, shared with the marketplace)

    func fetchDonationListings() async throws -> [Product] {
        let snapshot = try await db.collection("listings")
            .whereField("kind", isEqualTo: "donation")
            .whereField("status", isEqualTo: "active")
            .getDocuments()
        return snapshot.documents
            .compactMap { try? $0.data(as: Product.self) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Donation listings owned by the current user — drives the "Given" tab in MyDonationsView.
    func fetchMyDonationListings(sellerID: String) async throws -> [Product] {
        let snapshot = try await db.collection("listings")
            .whereField("kind", isEqualTo: "donation")
            .whereField("sellerId", isEqualTo: sellerID)
            .getDocuments()
        return snapshot.documents
            .compactMap { try? $0.data(as: Product.self) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchDonationListingsByCategory(_ category: String) async throws -> [Product] {
        // `arrayContains` already adds a constraint; client-side sort keeps us
        // off the composite-index requirement.
        let snapshot = try await db.collection("listings")
            .whereField("kind", isEqualTo: "donation")
            .whereField("status", isEqualTo: "active")
            .whereField("tags", arrayContains: category)
            .getDocuments()
        return snapshot.documents
            .compactMap { try? $0.data(as: Product.self) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchRequestCountsPerListing(_ listingIDs: [String]) async throws -> [String: Int] {
        var counts: [String: Int] = [:]
        for id in listingIDs {
            let snapshot = try await db.collection("donationRequests")
                .whereField("donationListingID", isEqualTo: id)
                .whereField("status", isEqualTo: "pending")
                .getDocuments()
            counts[id] = snapshot.documents.count
        }
        return counts
    }

    // MARK: - Private Helpers

    private func decodeDonationRequest(_ data: [String: Any], id: String) -> DonationRequest? {
        guard
            let donationListingID = data["donationListingID"] as? String,
            let sellerID = data["sellerID"] as? String,
            let requesterID = data["requesterID"] as? String,
            let statusStr = data["status"] as? String,
            let createdAtTimestamp = data["createdAt"] as? Timestamp
        else {
            return nil
        }

        let status = DonationRequestStatus(rawValue: statusStr) ?? .pending
        let requesterMessage = data["requesterMessage"] as? String
        let resolvedAtTimestamp = data["resolvedAt"] as? Timestamp
        let resolvedAt = resolvedAtTimestamp?.dateValue()

        return DonationRequest(
            id: id,
            donationListingID: donationListingID,
            sellerID: sellerID,
            requesterID: requesterID,
            requesterMessage: requesterMessage,
            status: status,
            createdAt: createdAtTimestamp.dateValue(),
            resolvedAt: resolvedAt
        )
    }
}
