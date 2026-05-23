import Foundation
import FirebaseFirestore
import FirebaseAuth

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
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            decodeDonationRequest(doc.data(), id: doc.documentID)
        }
    }

    func fetchIncomingRequests(for sellerID: String) async throws -> [DonationRequest] {
        let snapshot = try await db.collection("donationRequests")
            .whereField("sellerID", isEqualTo: sellerID)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            decodeDonationRequest(doc.data(), id: doc.documentID)
        }
    }

    func fetchRequestsForRequester(id: String) async throws -> [DonationRequest] {
        let snapshot = try await db.collection("donationRequests")
            .whereField("requesterID", isEqualTo: id)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            decodeDonationRequest(doc.data(), id: doc.documentID)
        }
    }

    func updateDonationRequestStatus(_ requestID: String, status: DonationRequestStatus) async throws {
        try await db.collection("donationRequests").document(requestID).updateData([
            "status": status.rawValue,
            "resolvedAt": Timestamp(date: .now)
        ])
    }

    func fetchDonationListings() async throws -> [Product] {
        let snapshot = try await db.collection("products")
            .whereField("kind", isEqualTo: "donation")
            .whereField("status", isEqualTo: "active")
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Product.self)
        }
    }

    func fetchDonationListingsByCategory(_ category: String) async throws -> [Product] {
        let snapshot = try await db.collection("products")
            .whereField("kind", isEqualTo: "donation")
            .whereField("status", isEqualTo: "active")
            .whereField("tags", arrayContains: category)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Product.self)
        }
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
