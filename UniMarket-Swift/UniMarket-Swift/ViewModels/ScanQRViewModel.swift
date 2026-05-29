//
//  ScanQRViewModel.swift
//  UniMarket-Swift
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class ScanQRViewModel: ObservableObject {
    private let analytics = AnalyticsService.shared
    private let productID: String?
    private let source: AnalyticsSurface

    /// Decoded meetup QR payload. Schema shared with the Flutter app
    /// (UniMarket-Dart `MeetupQrPayload`): a JSON object, not a raw id.
    struct MeetupQRPayload {
        let transactionId: String
        let listingId: String
        let sellerEmail: String
        let buyerEmail: String

        init?(rawValue: String) {
            guard
                let data = rawValue.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let transactionId = (json["transactionId"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                let listingId = (json["listingId"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                let sellerEmail = (json["sellerEmail"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                let buyerEmail = (json["buyerEmail"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                !transactionId.isEmpty, !listingId.isEmpty,
                !sellerEmail.isEmpty, !buyerEmail.isEmpty
            else { return nil }

            self.transactionId = transactionId
            self.listingId = listingId
            self.sellerEmail = sellerEmail.lowercased()
            self.buyerEmail = buyerEmail.lowercased()
        }
    }

    enum ScanState {
        case scanning
        case confirming(payload: MeetupQRPayload)
        case loading
        case confirmed
        case error(String)
    }

    @Published var scanState: ScanState = .scanning

    init(productID: String? = nil, source: AnalyticsSurface = .unknown) {
        self.productID = productID
        self.source = source
    }

    // MARK: - Scanner logic

    func handleScannedCode(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let payload = MeetupQRPayload(rawValue: trimmed) else {
            scanState = .error("Invalid QR code. Please scan a valid UniMarket meetup QR.")
            return
        }
        scanState = .confirming(payload: payload)
    }

    func resetScanning() {
        scanState = .scanning
    }

    // MARK: - Firestore confirmation

    func confirmPickup(payload: MeetupQRPayload) async {
        guard let currentUser = Auth.auth().currentUser else {
            scanState = .error("You must be logged in to confirm a pickup.")
            return
        }
        let currentEmail = (currentUser.email ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard currentEmail == payload.buyerEmail else {
            scanState = .error("This QR can only be confirmed by the assigned buyer.")
            return
        }

        scanState = .loading

        do {
            let db = Firestore.firestore()
            let ref = db.collection("meetup_transactions").document(payload.transactionId)
            let doc = try await ref.getDocument()

            guard doc.exists, let data = doc.data() else {
                scanState = .error("Transaction not found. Please scan a valid QR.")
                return
            }
            guard let status = data["status"] as? String, status == "pending" else {
                scanState = .error("This transaction has already been confirmed or is no longer valid.")
                return
            }

            // Only status/confirmedAt change — the firestore.rules update guard
            // requires every other field to stay identical.
            try await ref.updateData([
                "status": "confirmed",
                "confirmedAt": FieldValue.serverTimestamp()
            ])

            analytics.track(.purchaseConfirmed(
                productID: payload.listingId,
                transactionID: payload.transactionId,
                source: source.rawValue
            ))

            // BQ#3 — donation fulfilment marker. When the QR belongs to a
            // donation listing, emit donation_picked_up so the funnel chart
            // can complete the donation_claimed → donation_approved → picked_up
            // pipeline. Done as a best-effort lookup; a missing kind defaults
            // to .sale and emits nothing extra.
            let listingKind = await fetchListingKind(listingID: payload.listingId)
            if listingKind == .donation {
                analytics.track(.donationPickedUp(listingID: payload.listingId))
            }
            scanState = .confirmed
        } catch {
            scanState = .error(error.localizedDescription)
        }
    }

    private func fetchListingKind(listingID: String) async -> ListingKind {
        let db = Firestore.firestore()
        do {
            let doc = try await db.collection("listings").document(listingID).getDocument()
            let raw = doc.data()?["kind"] as? String
            return ListingKind(firestoreValue: raw)
        } catch {
            return .sale
        }
    }
}
