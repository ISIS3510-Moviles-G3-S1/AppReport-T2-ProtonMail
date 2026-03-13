//
//  ProfileViewModel.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI
import Combine

final class ProfileViewModel: ObservableObject {
    struct MonthlyProductStats {
        let listingsCreated: Int
        let itemsSold: Int
    }

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

    @Published var listings: [Product] = [
        Product(
            id: "1",
            title: "Vintage Levi’s Denim Jacket",
            price: 25,
            sellerName: "Alex López",
            conditionTag: "Good",
            tags: ["outerwear", "denim"],
            imageName: "jacket",
            description: "Classic denim jacket in great condition.",
            createdAt: Calendar.current.date(byAdding: .day, value: -8, to: .now) ?? .now,
            status: .active
        ),
        Product(
            id: "2",
            title: "Cream Knit Sweater",
            price: 20,
            sellerName: "Alex López",
            conditionTag: "Good",
            tags: ["knitwear"],
            imageName: "tshirt",
            description: "Soft sweater with a relaxed fit.",
            createdAt: Calendar.current.date(byAdding: .day, value: -20, to: .now) ?? .now,
            soldAt: Calendar.current.date(byAdding: .day, value: -4, to: .now),
            status: .sold
        ),
        Product(
            id: "3",
            title: "Canvas Tote Bag",
            price: 12,
            sellerName: "Alex López",
            conditionTag: "Like New",
            tags: ["bags"],
            imageName: "bag",
            description: "Large tote bag with plenty of room.",
            createdAt: Calendar.current.date(byAdding: .day, value: -45, to: .now) ?? .now,
            status: .paused
        )
    ]

    @Published var editingListing: Product? = nil

    var monthlyProductStats: MonthlyProductStats {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .month, value: -1, to: .now) ?? .now

        let listingsCreated = listings.filter { $0.createdAt >= cutoffDate }.count
        let itemsSold = listings.filter { product in
            guard let soldAt = product.soldAt else { return false }
            return soldAt >= cutoffDate
        }.count

        return MonthlyProductStats(
            listingsCreated: listingsCreated,
            itemsSold: itemsSold
        )
    }

    func deleteListing(_ product: Product) {
        listings.removeAll { $0.id == product.id }
    }

    func openEdit(_ product: Product) {
        editingListing = product
    }

    func saveEdits(_ updated: Product) {
        guard let idx = listings.firstIndex(where: { $0.id == updated.id }) else { return }
        listings[idx] = updated
        editingListing = nil
    }
}
