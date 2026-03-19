//
//  Product.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import Foundation

struct Product: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var price: Int
    let sellerName: String
    let conditionTag: String
    let tags: [String]
    let rating: Double
    var isFavorite: Bool
    let imageName: String
    let description: String
    let createdAt: Date
    let soldAt: Date?
    let imagePath: String?
    var status: ProductStatus

    init(
        id: String,
        title: String,
        price: Int,
        sellerName: String = "Unknown seller",
        conditionTag: String = "Good",
        tags: [String] = [],
        rating: Double = 0,
        isFavorite: Bool = false,
        imageName: String = "",
        description: String = "",
        createdAt: Date = .now,
        soldAt: Date? = nil,
        imagePath: String? = nil,
        status: ProductStatus = .active
    ) {
        self.id = id
        self.title = title
        self.price = price
        self.sellerName = sellerName
        self.conditionTag = conditionTag
        self.tags = tags
        self.rating = rating
        self.isFavorite = isFavorite
        self.imageName = imageName
        self.description = description
        self.createdAt = createdAt
        self.soldAt = soldAt
        self.imagePath = imagePath
        self.status = status
    }
}

enum ProductStatus: String, CaseIterable, Identifiable, Codable {
    case active = "Active"
    case paused = "Paused"
    case sold = "Sold"

    var id: String { rawValue }
}
