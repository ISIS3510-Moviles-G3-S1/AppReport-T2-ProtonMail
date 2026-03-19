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
        case likes = "Saved Items"
        case listings = "My Listings"
    }

    @Published var selectedTab: Tab = .likes

    @Published var likedProducts: [Product] = []

    @Published var listings: [Product] = []

    func removeSavedProduct(_ product: Product) {
        likedProducts.removeAll { $0.id == product.id }
    }

    func sync(products: [Product], currentUserID: String?) {
        likedProducts = products.filter(\.isFavorite)

        guard let currentUserID else {
            listings = []
            return
        }

        listings = products
            .filter { $0.sellerId == currentUserID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func deleteListing(_ product: Product) {
        listings.removeAll { $0.id == product.id }
    }

    func updateListing(_ updated: Product) {
        guard let idx = listings.firstIndex(where: { $0.id == updated.id }) else { return }
        listings[idx] = updated
    }
}
