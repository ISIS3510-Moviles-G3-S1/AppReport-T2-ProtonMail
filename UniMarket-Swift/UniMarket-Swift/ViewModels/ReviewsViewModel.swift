//
//  ReviewsViewModel.swift
//  UniMarket-Swift
//
//  @MainActor ViewModel for seller reviews.
//
//  Fetch lifecycle:
//    fetchReviews  → cancels prior task → Task.detached(background) Firestore read
//                 → background ModelContext write (NOT view's @Environment context)
//                 → MainActor.run publish
//
//  Submit lifecycle:
//    submitReview → local ModelContext write isSynced=false (always)
//                → if connected: Task.detached(background) Firestore push
//                → Task.detached(background) mark isSynced=true
//                → else: PendingReviewsSyncer drains on reconnect
//
//  Connectivity:
//    bindConnectivity → Combine on NetworkMonitor.$isConnected
//                     → calls PendingReviewsSyncer.shared.drain() on reconnect
//

import Foundation
import SwiftData
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Sendable DTO

/// Value-type envelope used to cross `Task.detached` boundaries safely.
/// `@Model` reference types cannot conform to `Sendable`; this can.
struct ReviewDTO: Sendable {
    let id: String
    let sellerID: String
    let reviewerID: String
    let reviewerDisplayName: String
    let starRating: Int
    let reviewText: String
    let createdAt: Date
    let productID: String?
}

// MARK: - ViewModel

@MainActor
final class ReviewsViewModel: ObservableObject {

    // MARK: Published state

    /// Freshly fetched records from Firestore (transient; view uses @Query for persistence).
    @Published var remoteReviews: [ReviewRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isConnected: Bool = NetworkMonitor.shared.isConnected

    // MARK: Internals

    let container: ModelContainer
    private let sellerID: String
    private let db = Firestore.firestore()
    private var fetchTask: Task<Void, Never>?
    private var connectivityCancellable: AnyCancellable?

    // MARK: Init

    init(sellerID: String, container: ModelContainer) {
        self.sellerID = sellerID
        self.container = container
        bindConnectivity()
    }

    // MARK: - Fetch

    /// Cancels any in-flight fetch, then kicks off a new Firestore read.
    /// Results are persisted to a background `ModelContext`; the view's
    /// `@Query` picks up the change automatically when that context saves.
    func fetchReviews(sellerID: String) {
        fetchTask?.cancel()
        isLoading = true
        errorMessage = nil

        let db = self.db
        let container = self.container

        fetchTask = Task {
            do {
                // 1. Firestore read — dispatched on a detached background task
                //    so the main thread is never blocked by network I/O.
                let snapshot = try await Task.detached(priority: .background) {
                    try await db
                        .collection("users")
                        .document(sellerID)
                        .collection("reviews")
                        .order(by: "createdAt", descending: true)
                        .getDocuments()
                }.value

                guard !Task.isCancelled else { return }

                // 2. Map Firestore documents → Sendable DTOs (value types).
                let dtos: [ReviewDTO] = snapshot.documents.compactMap { doc in
                    let d = doc.data()
                    guard
                        let reviewerID            = d["reviewerID"]            as? String,
                        let reviewerDisplayName   = d["reviewerDisplayName"]   as? String,
                        let starRating            = d["starRating"]            as? Int,
                        let reviewText            = d["reviewText"]            as? String
                    else { return nil }

                    return ReviewDTO(
                        id: doc.documentID,
                        sellerID: sellerID,
                        reviewerID: reviewerID,
                        reviewerDisplayName: reviewerDisplayName,
                        starRating: starRating,
                        reviewText: reviewText,
                        createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        productID: d["productID"] as? String
                    )
                }

                // 3. Upsert into a background ModelContext — NOT the view's
                //    @Environment modelContext. SwiftData notifies @Query automatically
                //    when this context saves.
                await Task.detached(priority: .background) {
                    let bgCtx = ModelContext(container)
                    for dto in dtos {
                        let dtoID = dto.id
                        let predicate = #Predicate<ReviewRecord> { $0.id == dtoID }
                        if let existing = try? bgCtx.fetch(
                            FetchDescriptor(predicate: predicate)
                        ).first {
                            // Already cached; ensure it is marked synced.
                            existing.isSynced = true
                        } else {
                            bgCtx.insert(ReviewRecord(
                                id: dto.id,
                                sellerID: dto.sellerID,
                                reviewerID: dto.reviewerID,
                                reviewerDisplayName: dto.reviewerDisplayName,
                                starRating: dto.starRating,
                                reviewText: dto.reviewText,
                                createdAt: dto.createdAt,
                                productID: dto.productID,
                                isSynced: true
                            ))
                        }
                    }
                    try? bgCtx.save()
                }.value

                // 4. Publish fresh records on the main actor.
                let freshRecords = dtos.map { dto in
                    ReviewRecord(
                        id: dto.id,
                        sellerID: dto.sellerID,
                        reviewerID: dto.reviewerID,
                        reviewerDisplayName: dto.reviewerDisplayName,
                        starRating: dto.starRating,
                        reviewText: dto.reviewText,
                        createdAt: dto.createdAt,
                        productID: dto.productID,
                        isSynced: true
                    )
                }
                await MainActor.run {
                    self.remoteReviews = freshRecords
                    self.isLoading = false
                }

            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Submit

    /// Writes the review locally first (isSynced=false), then — if online —
    /// pushes to Firestore and flips isSynced=true. Offline submissions are
    /// drained by PendingReviewsSyncer when connectivity is restored.
    func submitReview(
        reviewerID: String,
        reviewerDisplayName: String,
        starRating: Int,
        reviewText: String,
        productID: String?
    ) async {
        let reviewID = UUID().uuidString

        // Step 1 — persist locally with isSynced=false, always.
        let localCtx = ModelContext(container)
        localCtx.insert(ReviewRecord(
            id: reviewID,
            sellerID: sellerID,
            reviewerID: reviewerID,
            reviewerDisplayName: reviewerDisplayName,
            starRating: starRating,
            reviewText: reviewText,
            createdAt: Date(),
            productID: productID,
            isSynced: false
        ))
        try? localCtx.save()

        guard isConnected else { return }

        // Step 2 — attempt Firestore push on a detached background task.
        let db = self.db
        let sID = sellerID
        let firestorePayload: [String: Any] = [
            "reviewerID":          reviewerID,
            "reviewerDisplayName": reviewerDisplayName,
            "starRating":          starRating,
            "reviewText":          reviewText,
            "createdAt":           FieldValue.serverTimestamp(),
            "productID":           productID as Any
        ]

        do {
            try await Task.detached(priority: .background) {
                try await db
                    .collection("users")
                    .document(sID)
                    .collection("reviews")
                    .document(reviewID)
                    .setData(firestorePayload)
            }.value

            // Step 3 — mark isSynced=true in a background context.
            let rID = reviewID
            await Task.detached(priority: .background) {
                let bgCtx = ModelContext(container)
                let predicate = #Predicate<ReviewRecord> { $0.id == rID }
                if let existing = try? bgCtx.fetch(
                    FetchDescriptor(predicate: predicate)
                ).first {
                    existing.isSynced = true
                    try? bgCtx.save()
                }
            }.value

        } catch {
            // Firestore push failed — record stays isSynced=false.
            // PendingReviewsSyncer will retry when connectivity resumes.
        }
    }

    // MARK: - Connectivity binding

    /// Subscribes to `NetworkMonitor.$isConnected`.
    /// On reconnect, asks `PendingReviewsSyncer` to drain any offline reviews.
    func bindConnectivity() {
        connectivityCancellable = NetworkMonitor.shared.$isConnected
            .removeDuplicates()
            .sink { [weak self] connected in
                guard let self else { return }
                Task { @MainActor in
                    self.isConnected = connected
                    if connected {
                        await PendingReviewsSyncer.shared.drain()
                    }
                }
            }
    }
}
