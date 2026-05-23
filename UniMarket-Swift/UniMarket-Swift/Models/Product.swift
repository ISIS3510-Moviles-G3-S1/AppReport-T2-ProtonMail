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
    /// Defaults to `.sale` for legacy docs that predate the donation/barter feature.
    var kind: ListingKind

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
        status: ProductStatus = .active,
        kind: ListingKind = .sale
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
        self.kind = kind
    }

    // Custom Codable so legacy docs missing "kind" decode as .sale without error.
    enum CodingKeys: String, CodingKey {
        case id, sellerId, title, price, sellerName, conditionTag, tags, rating
        case isFavorite, description, createdAt, soldAt, imagePath, imageURLs, status, kind
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(String.self,        forKey: .id)
        sellerId     = try c.decodeIfPresent(String.self, forKey: .sellerId) ?? ""
        title        = try c.decode(String.self,        forKey: .title)
        price        = try c.decode(Int.self,           forKey: .price)
        sellerName   = try c.decodeIfPresent(String.self, forKey: .sellerName) ?? "Unknown seller"
        conditionTag = try c.decodeIfPresent(String.self, forKey: .conditionTag) ?? "Good"
        tags         = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        rating       = try c.decodeIfPresent(Double.self, forKey: .rating) ?? 0
        isFavorite   = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        description  = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        createdAt    = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        soldAt       = try c.decodeIfPresent(Date.self, forKey: .soldAt)
        imagePath    = try c.decodeIfPresent(String.self, forKey: .imagePath)
        imageURLs    = try c.decodeIfPresent([String].self, forKey: .imageURLs) ?? []
        status       = try c.decodeIfPresent(ProductStatus.self, forKey: .status) ?? .active
        // Legacy docs don't have "kind" — default to .sale
        kind         = try c.decodeIfPresent(ListingKind.self, forKey: .kind) ?? .sale
    }
}

enum ProductStatus: String, CaseIterable, Identifiable, Codable {
    case active = "Active"
    case paused = "Paused"
    case sold = "Sold"

    var id: String { rawValue }
}

extension ProductStatus {
    /// Canonical Firestore representation — lowercase, shared with the Flutter
    /// app (UniMarket-Dart `ListingStatus`). The capitalized `rawValue` is kept
    /// for on-screen display only.
    var firestoreValue: String { rawValue.lowercased() }

    /// Case-insensitive decoder. Listing docs may carry the Swift app's
    /// capitalized values or the Flutter app's lowercase ones — accept both.
    init(firestoreValue raw: String?) {
        switch raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "sold": self = .sold
        case "paused": self = .paused
        default: self = .active
        }
    }
}

extension Product {
    var isSold: Bool {
        status == .sold
    }

    func updatingSaleState(isSold: Bool) -> Product {
        var updated = self
        updated.status = isSold ? .sold : .active
        updated.soldAt = isSold ? (soldAt ?? .now) : nil
        return updated
    }
}
