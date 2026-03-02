//
//  SearchViewModel.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI
import Combine

final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var products: [Product] = [
        Product(id: "1", title: "Striped Linen Shirt", price: 16, sellerName: "Kai O.", conditionTag: "Good", rating: 4.6, isFavorite: false, imageName: "tshirt"),
        Product(id: "2", title: "High-Waist Jeans", price: 28, sellerName: "Nora B.", conditionTag: "Good", rating: 4.4, isFavorite: false, imageName: "figure.walk"),
        Product(id: "3", title: "Canvas Tote Bag", price: 12, sellerName: "Mila R.", conditionTag: "Like New", rating: 4.8, isFavorite: true, imageName: "bag"),
        Product(id: "4", title: "Black & White Print", price: 9, sellerName: "Sam P.", conditionTag: "Good", rating: 4.2, isFavorite: false, imageName: "photo")
    ]

    var filteredProducts: [Product] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return products }
        return products.filter { $0.title.localizedCaseInsensitiveContains(q) }
    }

    func toggleFavorite(for product: Product) {
        guard let idx = products.firstIndex(where: { $0.id == product.id }) else { return }
        products[idx].isFavorite.toggle()
    }
}
