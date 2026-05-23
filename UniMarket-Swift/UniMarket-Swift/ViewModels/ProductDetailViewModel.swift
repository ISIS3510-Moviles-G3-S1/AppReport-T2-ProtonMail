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
    let sellerId: String
    let sellerName: String
    let imageURLs: [String]
    let rating: Double?
    let description: String
    let isOwnListing: Bool
    /// Listing type — drives the "Claim Donation" CTA in ProductDetailView.
    let kind: ListingKind
    /// Source product for handing off to the donation request flow.
    let product: Product

    @Published var title: String
    @Published var price: Int
    @Published var conditionText: String
    @Published var status: ProductStatus
    @Published var isFavorite: Bool
    @Published var tags: [String]

    private var sourceProduct: Product?

    init(product: Product, isOwnListing: Bool = false) {
        self.product = product
        self.kind = product.kind
        self.id = product.id
        self.sellerId = product.sellerId
        self.title = product.title
        self.price = product.price
        let urls = product.imageURLs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !urls.isEmpty {
            self.imageURLs = urls
        } else if let fallback = product.imagePath?.trimmingCharacters(in: .whitespacesAndNewlines), !fallback.isEmpty {
            self.imageURLs = [fallback]
        } else {
            self.imageURLs = []
        }
        self.sellerName = product.sellerName
        self.conditionText = isOwnListing ? product.status.rawValue : product.conditionTag
        self.status = product.status
        self.rating = isOwnListing ? nil : product.rating
        self.isFavorite = product.isFavorite
        self.isOwnListing = isOwnListing
        self.tags = product.tags
        self.description = product.description.isEmpty
            ? "Pre-loved item in \(product.conditionTag.lowercased()) condition. Perfect for campus life and sustainable fashion."
            : product.description
        self.sourceProduct = isOwnListing ? product : nil
    }

    func toggleFavorite() {
        guard !isOwnListing else { return }
        isFavorite.toggle()
    }

    func editableProduct() -> Product? {
        sourceProduct
    }

    func productForSaleState(isSold: Bool) -> Product? {
        sourceProduct?.updatingSaleState(isSold: isSold)
    }

    func applyProductUpdate(_ updated: Product) {
        sourceProduct = updated
        title = updated.title
        price = updated.price
        conditionText = updated.status.rawValue
        status = updated.status
        tags = updated.tags
    }

    func sync(with updated: Product) {
        guard updated.id == id else { return }
        title = updated.title
        price = updated.price
        conditionText = isOwnListing ? updated.status.rawValue : updated.conditionTag
        status = updated.status
        isFavorite = updated.isFavorite
        tags = updated.tags
        if isOwnListing {
            sourceProduct = updated
        }
    }
}
