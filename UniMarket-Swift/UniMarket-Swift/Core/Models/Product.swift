//
//  Product.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import Foundation

struct Product: Identifiable, Hashable, Codable {
    let id: String
    let sellerId: String
    var title: String
    var price: Int
    let sellerName: String
    let conditionTag: String
    let tags: [String]
    let rating: Double
    var isFavorite: Bool
    let description: String
    let createdAt: Date
    var soldAt: Date?
    let imagePath: String?
    let imageURLs: [String]
    var status: ProductStatus

    var primaryImageURL: String? {
        imageURLs.first ?? imagePath
    }

    init(
        id: String,
        sellerId: String = "",
        title: String,
        price: Int,
        sellerName: String = "Unknown seller",
        conditionTag: String = "Good",
        tags: [String] = [],
        rating: Double = 0,
        isFavorite: Bool = false,
        description: String = "",
        createdAt: Date = .now,
        soldAt: Date? = nil,
        imagePath: String? = nil,
        imageURLs: [String] = [],
        status: ProductStatus = .active
    ) {
        self.id = id
        self.sellerId = sellerId
        self.title = title
        self.price = price
        self.sellerName = sellerName
        self.conditionTag = conditionTag
        self.tags = tags
        self.rating = rating
        self.isFavorite = isFavorite
        self.description = description
        self.createdAt = createdAt
        self.soldAt = soldAt
        self.imagePath = imagePath
        self.imageURLs = imageURLs
        self.status = status
    }
}

enum ProductStatus: String, CaseIterable, Identifiable, Codable {
    case active = "Active"
    case paused = "Paused"
    case sold = "Sold"

    var id: String { rawValue }
}
