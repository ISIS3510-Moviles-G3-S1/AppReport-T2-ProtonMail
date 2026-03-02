//
//  ActivityViewModel.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI
import Combine

final class ActivityViewModel: ObservableObject {
    enum Tab: String, CaseIterable {
        case activity = "Activity Feed"
        case listings = "My Listings"
    }

    @Published var selectedTab: Tab = .activity

    @Published var listings: [Listing] = [
        Listing(id: "1", title: "Vintage Levi’s Denim Jacket", price: 25, status: .active, imageName: "jacket"),
        Listing(id: "2", title: "Cream Knit Sweater", price: 20, status: .active, imageName: "tshirt"),
        Listing(id: "3", title: "Canvas Tote Bag", price: 12, status: .paused, imageName: "bag")
    ]

    @Published var activity: [String] = [
        "Nora liked your item “Cream Knit Sweater”.",
        "You posted “Vintage Levi’s Denim Jacket”.",
        "Kai sent you a message about “Canvas Tote Bag”."
    ]

    // Sheet de edición
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
