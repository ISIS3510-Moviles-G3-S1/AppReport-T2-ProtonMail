//
//  GenerateQRViewModel.swift
//  UniMarket-Swift
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class GenerateQRViewModel: ObservableObject {

    enum ViewState {
        case idle
        case loading
        case generated(transactionId: String, qrPayload: String)
        case error(String)
    }

    @Published var buyerEmail = ""
    @Published var viewState: ViewState = .idle

    let listingId: String
    let sellerId: String
    let listingStatus: ProductStatus

    init(listingId: String, sellerId: String, listingStatus: ProductStatus) {
        self.listingId = listingId
        self.sellerId = sellerId
        self.listingStatus = listingStatus
    }

    var isListingActive: Bool { listingStatus == .active }

    // MARK: - QR generation

    func generateQR() async {
        let buyer = buyerEmail
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !buyer.isEmpty else {
            viewState = .error("Please enter the buyer's email.")
            return
        }
        guard buyer.contains("@") else {
            viewState = .error("Please enter a valid buyer email address.")
            return
        }
        guard isListingActive else {
            viewState = .error("This listing is not active and cannot generate a QR.")
            return
        }
        guard
            let currentUser = Auth.auth().currentUser,
            let rawSellerEmail = currentUser.email,
            !rawSellerEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            viewState = .error("Your account email is required to generate a meetup QR.")
            return
        }
        let sellerEmail = rawSellerEmail
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard currentUser.uid == sellerId else {
            viewState = .error("Only the listing seller can generate a meetup QR.")
            return
        }
        guard buyer != sellerEmail else {
            viewState = .error("Seller and buyer must use different email accounts.")
            return
        }

        viewState = .loading

        do {
            let db = Firestore.firestore()
            let ref = db.collection("meetup_transactions").document()

            // Schema shared with the Flutter app + firestore.rules: email-based
            // identity, `transactionId` mirrors the doc id. See UniMarket-Dart
            // MeetupTransactionService.createPendingTransaction.
            try await ref.setData([
                "transactionId": ref.documentID,
                "listingId": listingId,
                "sellerId": sellerId,
                "sellerEmail": sellerEmail,
                "buyerEmail": buyer,
                "status": "pending",
                "createdAt": FieldValue.serverTimestamp(),
                "confirmedAt": NSNull()
            ])

            // The QR encodes the same JSON payload the Flutter scanner decodes.
            let payload: [String: String] = [
                "transactionId": ref.documentID,
                "listingId": listingId,
                "sellerEmail": sellerEmail,
                "buyerEmail": buyer
            ]
            let payloadData = try JSONSerialization.data(withJSONObject: payload)
            let payloadString = String(decoding: payloadData, as: UTF8.self)

            viewState = .generated(transactionId: ref.documentID, qrPayload: payloadString)
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }
}
