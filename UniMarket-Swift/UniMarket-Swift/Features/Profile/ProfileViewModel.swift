//
//  ProfileViewModel.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI
import Combine

final class ProfileViewModel: ObservableObject {
    enum Tab: String, CaseIterable {
        case activity = "Activity Feed"
        case listings = "My Listings"
    }

    @Published var selectedTab: Tab = .activity

    @Published var profile = UserProfile(
        name: "Alex López",
        university: "UCM Madrid",
        memberSince: "Sept 2024",
        rating: 4.8,
        transactions: 15,
        xp: 680,
        levelTitle: "Level 4 – Eco Explorer",
        nextLevelTitle: "Level 5 – Sustainability Star",
        xpToNext: 220,
        levelMinXP: 500,
        levelMaxXP: 900
    )

    @Published var ecoMessage =
    "You've sold 3 items this month. You're just 220 XP away from Level 5 - Sustainability Star. Keep it up to unlock new badges and rewards!"

    @Published var activity: [String] = [
        "Nora liked your item “Cream Knit Sweater”.",
        "You posted “Vintage Levi’s Denim Jacket”.",
        "Kai sent you a message about “Canvas Tote Bag”."
    ]

    @Published var listings: [Listing] = [
        Listing(id: "1", title: "Vintage Levi’s Denim Jacket", price: 25, status: .active, imageName: "jacket"),
        Listing(id: "2", title: "Cream Knit Sweater", price: 20, status: .active, imageName: "tshirt"),
        Listing(id: "3", title: "Canvas Tote Bag", price: 12, status: .paused, imageName: "bag")
    ]

    @Published var editingListing: Listing? = nil

    func deleteListing(_ listing: Listing) {
        listings.removeAll { $0.id == listing.id }
    }

    func openEdit(_ listing: Listing) {
        editingListing = listing
    }

    func saveEdits(_ updated: Listing) {
        guard let idx = listings.firstIndex(where: { $0.id == updated.id }) else { return }
        listings[idx] = updated
        editingListing = nil
    }
}
