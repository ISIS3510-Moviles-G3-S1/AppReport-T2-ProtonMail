//
//  PendingReviewsSyncer.swift
//  UniMarket-Swift
//
//  Connectivity-driven coordinator that drains offline reviews to Firestore.
//  Shape mirrors PendingFavoritesSyncer — Combine drain on
//  NetworkMonitor.$isConnected, SwiftData fetch of all ReviewRecord where
//  isSynced == false, Firestore push, then mark synced.
//
//  Lifecycle:
//    UniMarket_SwiftApp calls  bind(to:container:) once at startup.
//    On reconnect, the Combine sink fires drain() automatically.
//    resumeIfNeeded() is also called at launch so records queued in a
//    prior session aren't left pending indefinitely.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth
import SwiftData

@MainActor
final class PendingReviewsSyncer: ObservableObject {
    static let shared = PendingReviewsSyncer()

    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var isDraining: Bool = false

    private let db = Firestore.firestore()
    private var container: ModelContainer?
    private var connectivityCancellable: AnyCancellable?

    private init() {}

    // MARK: - Binding

    /// Call once at app startup. Stores the container and begins listening
    /// for connectivity changes.
    func bind(to monitor: NetworkMonitor, container: ModelContainer) {
        self.container = container

        connectivityCancellable = monitor.$isConnected
            .removeDuplicates()
            .sink { [weak self] connected in
                guard let self, connected else { return }
                Task { await self.drain() }
            }

        Task { await refreshCount() }
    }

    /// Drains any pre-existing pending records if the device is already online.
    func resumeIfNeeded() async {
        await refreshCount()
        if NetworkMonitor.shared.isConnected {
            await drain()
        }
    }

    // MARK: - Drain

    /// Fetches all `ReviewRecord` rows where `isSynced == false`, pushes each
    /// to Firestore, and marks them synced. Stops on the first failure so
    /// retries happen on the next connectivity flip.
    func drain() async {
        guard !isDraining else { return }
        guard let container else { return }
        guard NetworkMonitor.shared.isConnected else { return }

        isDraining = true
        defer {
            isDraining = false
            Task { await refreshCount() }
        }

        // Fetch unsynced records on the main actor using a dedicated context
        // (not the view's @Environment modelContext).
        let ctx = ModelContext(container)
        let descriptor = FetchDescriptor<ReviewRecord>(
            predicate: #Predicate { $0.isSynced == false }
        )
        guard let pending = try? ctx.fetch(descriptor), !pending.isEmpty else { return }

        let db = self.db

        for record in pending {
            // Capture primitive values before any suspension point so the
            // @Model object isn't accessed across actor hops.
            let sellerID          = record.sellerID
            let reviewID          = record.id
            let reviewerID        = record.reviewerID
            let reviewerDisplay   = record.reviewerDisplayName
            let starRating        = record.starRating
            let reviewText        = record.reviewText
            let productID         = record.productID

            let payload: [String: Any] = [
                "reviewerID":          reviewerID,
                "reviewerDisplayName": reviewerDisplay,
                "starRating":          starRating,
                "reviewText":          reviewText,
                "createdAt":           FieldValue.serverTimestamp(),
                "productID":           productID as Any
            ]

            do {
                // Firestore write on a detached background task.
                try await Task.detached(priority: .background) {
                    try await db
                        .collection("users")
                        .document(sellerID)
                        .collection("reviews")
                        .document(reviewID)
                        .setData(payload)
                }.value

                // Mark synced — still on main actor, same context, no crossing.
                record.isSynced = true
                try? ctx.save()

            } catch {
                // Stop on first failure; next connectivity flip retries.
                break
            }
        }
    }

    // MARK: - Count refresh

    private func refreshCount() async {
        guard let container else {
            pendingCount = 0
            return
        }
        let task = Task.detached(priority: .utility) {
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<ReviewRecord>(
                predicate: #Predicate { $0.isSynced == false }
            )
            return (try? ctx.fetch(descriptor))?.count ?? 0
        }
        pendingCount = await task.value
    }
}
