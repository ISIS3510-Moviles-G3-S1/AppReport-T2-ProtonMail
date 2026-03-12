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

    @Published var likedProducts: [Product] = [
        Product(id: "1", title: "Striped Linen Shirt", price: 16, sellerName: "Kai O.", conditionTag: "Good", tags: ["tops", "linen", "casual"], rating: 4.6, isFavorite: true, imageName: "Shirt"),
        Product(id: "3", title: "Canvas Tote Bag", price: 12, sellerName: "Mila R.", conditionTag: "Like New", tags: ["bags", "campus", "minimal"], rating: 4.8, isFavorite: true, imageName: "ToteBag"),
        Product(id: "4", title: "Black & White Print", price: 9, sellerName: "Sam P.", conditionTag: "Good", tags: ["accessories", "print", "vintage"], rating: 4.2, isFavorite: true, imageName: "Puffer")
    ]

    @Published var listings: [Product] = [
        Product(id: "1", title: "Vintage Levi’s Denim Jacket", price: 25, sellerName: "Your listing", conditionTag: "Good", tags: ["outerwear", "denim"], imageName: "Puffer", description: "Classic denim jacket in great condition.", status: .active),
        Product(id: "2", title: "Cream Knit Sweater", price: 20, sellerName: "Your listing", conditionTag: "Good", tags: ["knitwear"], imageName: "Shirt", description: "Soft knit sweater for everyday campus wear.", status: .active),
        Product(id: "3", title: "Canvas Tote Bag", price: 12, sellerName: "Your listing", conditionTag: "Like New", tags: ["bags"], imageName: "ToteBag", description: "Spacious tote bag with minimal wear.", status: .paused)
    ]

    func removeSavedProduct(_ product: Product) {
        likedProducts.removeAll { $0.id == product.id }
    }

    func deleteListing(_ product: Product) {
        listings.removeAll { $0.id == product.id }
    }

    func updateListing(_ updated: Product) {
        guard let idx = listings.firstIndex(where: { $0.id == updated.id }) else { return }
        listings[idx] = updated
    }
}
