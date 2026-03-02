//
//  ProductDetailViewModel.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import Foundation
import Combine

final class ProductDetailViewModel: ObservableObject {
    let id: String
    let sellerName: String
    let imageName: String
    let rating: Double?
    let description: String
    let isOwnListing: Bool

    @Published var title: String
    @Published var price: Int
    @Published var conditionText: String
    @Published var isFavorite: Bool

    private var sourceListing: Listing?

    private init(
        summary: ItemSummary,
        sellerName: String,
        conditionText: String,
        rating: Double?,
        isFavorite: Bool,
        isOwnListing: Bool,
        description: String,
        sourceListing: Listing?
    ) {
        self.id = summary.id
        self.title = summary.title
        self.price = summary.price
        self.imageName = summary.imageName
        self.sellerName = sellerName
        self.conditionText = conditionText
        self.rating = rating
        self.isFavorite = isFavorite
        self.isOwnListing = isOwnListing
        self.description = description
        self.sourceListing = sourceListing
    }

    convenience init(product: Product) {
        self.init(
            summary: product.itemSummary,
            sellerName: product.sellerName,
            conditionText: product.conditionTag,
            rating: product.rating,
            isFavorite: product.isFavorite,
            isOwnListing: false,
            description: "Pre-loved item in \(product.conditionTag.lowercased()) condition. Perfect for campus life and sustainable fashion.",
            sourceListing: nil
        )
    }

    convenience init(listing: Listing) {
        self.init(
            summary: listing.itemSummary,
            sellerName: "Your listing",
            conditionText: listing.status.rawValue,
            rating: nil,
            isFavorite: false,
            isOwnListing: true,
            description: "Manage your listing details, update price, and keep your item information up to date.",
            sourceListing: listing
        )
    }

    func toggleFavorite() {
        guard !isOwnListing else { return }
        isFavorite.toggle()
    }

    func editableListing() -> Listing? {
        sourceListing
    }

    func applyListingUpdate(_ updated: Listing) {
        sourceListing = updated
        title = updated.title
        price = updated.price
        conditionText = updated.status.rawValue
    }
}
