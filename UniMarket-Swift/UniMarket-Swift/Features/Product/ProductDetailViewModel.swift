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
    let imageURL: String?
    let rating: Double?
    let description: String
    let isOwnListing: Bool

    @Published var title: String
    @Published var price: Int
    @Published var conditionText: String
    @Published var isFavorite: Bool

    private var sourceProduct: Product?

    init(product: Product, isOwnListing: Bool = false) {
        self.id = product.id
        self.title = product.title
        self.price = product.price
        self.imageName = product.imageName
        self.imageURL = product.primaryImageURL
        self.sellerName = product.sellerName
        self.conditionText = isOwnListing ? product.status.rawValue : product.conditionTag
        self.rating = isOwnListing ? nil : product.rating
        self.isFavorite = product.isFavorite
        self.isOwnListing = isOwnListing
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

    func applyProductUpdate(_ updated: Product) {
        sourceProduct = updated
        title = updated.title
        price = updated.price
        conditionText = updated.status.rawValue
    }
}
