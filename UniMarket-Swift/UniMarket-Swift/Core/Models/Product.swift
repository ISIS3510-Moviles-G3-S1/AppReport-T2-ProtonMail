//
//  Product.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import Foundation

struct Product: Identifiable, Hashable {
    let id: String
    let title: String
    let price: Int
    let sellerName: String
    let conditionTag: String
    let tags: [String]
    let rating: Double
    var isFavorite: Bool
    let imageName: String
}
