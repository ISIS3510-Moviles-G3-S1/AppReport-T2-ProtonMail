//
//  ActivityViewModel.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI
import Combine

// Type 2 BQ: "How long since the user's last meaningful interaction?"
// Type 2 because the answer is computed from a locally stored timestamp — no server
// call needed. UserDefaults persists the value across launches so the metric is
// available instantly, even offline.
final class ActivityViewModel: ObservableObject {
    enum Tab: String, CaseIterable {
        case likes = "Saved Items"
        case listings = "My Listings"
    }

    enum UserActivityState {
        case active    // < 1 day
        case idle      // 1–3 days
        case inactive  // 3–7 days
        case dormant   // > 7 days
    }

    @Published var selectedTab: Tab = .likes
    @Published var likedProducts: [Product] = []
    @Published var listings: [Product] = []

    // MARK: - BQ: Last Interaction

    @Published var lastInteractionDate: Date?
    @Published var timeSinceLastInteraction: TimeInterval?
    @Published var userActivityState: UserActivityState = .active
    @Published var feedbackMessage: String = ""

    func refreshInteractionState() {
        lastInteractionDate = FavoritesCacheManager.shared.getLastInteraction()
        guard let date = lastInteractionDate else {
            feedbackMessage = "Start exploring items!"
            return
        }
        let elapsed = Date().timeIntervalSince(date)
        timeSinceLastInteraction = elapsed
        let days = elapsed / 86_400
        switch days {
        case ..<1:
            userActivityState = .active
            feedbackMessage = "You're very active! Keep exploring items."
        case 1..<3:
            userActivityState = .idle
            feedbackMessage = "It's been a couple of days — check out new listings."
        case 3..<7:
            userActivityState = .inactive
            feedbackMessage = "We miss you! It's been \(Int(days)) days since your last visit."
        default:
            userActivityState = .dormant
            feedbackMessage = "It's been over a week! Come back and see what's new."
        }
    }

    func removeSavedProduct(_ product: Product) {
        likedProducts.removeAll { $0.id == product.id }
    }

    func sync(products: [Product], currentUserID: String?) {
        likedProducts = products.filter(\.isFavorite)

        guard let currentUserID else {
            listings = []
            return
        }

        let updated = products
            .filter { $0.sellerId == currentUserID }
            .sorted { $0.createdAt > $1.createdAt }
        listings = updated
    }

    func deleteListing(_ product: Product) {
        listings.removeAll { $0.id == product.id }
    }

    func updateListing(_ updated: Product) {
        guard let idx = listings.firstIndex(where: { $0.id == updated.id }) else { return }
        listings[idx] = updated
    }
}
