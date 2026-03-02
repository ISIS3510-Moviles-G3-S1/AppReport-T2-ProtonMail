//
//  Listings.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import Foundation

struct Listing: Identifiable, Hashable {
    let id: String
    var title: String
    var price: Int
    var status: ListingStatus
    var imageName: String
}

enum ListingStatus: String, CaseIterable, Identifiable {
    case active = "Active"
    case paused = "Paused"
    case sold = "Sold"

    var id: String { rawValue }
}
