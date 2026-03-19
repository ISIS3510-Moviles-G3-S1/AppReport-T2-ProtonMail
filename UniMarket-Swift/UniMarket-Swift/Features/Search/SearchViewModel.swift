//
//  SearchViewModel.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI
import Combine

final class SearchViewModel: ObservableObject {
    enum SortOption: String, CaseIterable, Identifiable {
        case relevance = "Relevance"
        case priceLowHigh = "Price: Low to High"
        case priceHighLow = "Price: High to Low"
        case ratingHighLow = "Rating: High to Low"

        var id: String { rawValue }
    }

    @Published var query: String = ""
    @Published var selectedTag: String? = nil
    @Published var selectedConditions: Set<String> = []
    @Published var onlyFavorites: Bool = false
    @Published var minRating: Double = 0
    @Published var sortOption: SortOption = .relevance

    @Published var minPrice: Int = 0
    @Published var maxPrice: Int = 0

    @Published var products: [Product] = [
        Product(id: "1", title: "Striped Linen Shirt", price: 16, sellerName: "Kai O.", conditionTag: "Good", tags: ["tops", "linen", "casual"], rating: 4.6, isFavorite: false, imageName: "Shirt"),
        Product(id: "2", title: "High-Waist Jeans", price: 28, sellerName: "Nora B.", conditionTag: "Good", tags: ["bottoms", "denim", "street"], rating: 4.4, isFavorite: false, imageName: "Pants"),
        Product(id: "3", title: "Canvas Tote Bag", price: 12, sellerName: "Mila R.", conditionTag: "Like New", tags: ["bags", "campus", "minimal"], rating: 4.8, isFavorite: true, imageName: "ToteBag"),
        Product(id: "4", title: "Black & White Print", price: 9, sellerName: "Sam P.", conditionTag: "Good", tags: ["accessories", "print", "vintage"], rating: 4.2, isFavorite: false, imageName: "Puffer")
    ] {
        didSet {
            if oldValue.map(\ .id) != products.map(\ .id) {
                resetPriceRange()
            }
        }
    }

    init() {
        resetPriceRange()
    }

    var availableTags: [String] {
        Array(Set(products.flatMap { $0.tags })).sorted()
    }

    var availableConditions: [String] {
        Array(Set(products.map { $0.conditionTag })).sorted()
    }

    var priceBounds: ClosedRange<Int> {
        let prices = products.map { $0.price }
        let min = prices.min() ?? 0
        let max = prices.max() ?? 100
        return min...max
    }

    var activeFilterCount: Int {
        var count = 0
        if selectedTag != nil { count += 1 }
        if !selectedConditions.isEmpty { count += 1 }
        if onlyFavorites { count += 1 }
        if minRating > 0 { count += 1 }
        if minPrice != priceBounds.lowerBound || maxPrice != priceBounds.upperBound { count += 1 }
        if sortOption != .relevance { count += 1 }
        return count
    }

    var filteredProducts: [Product] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let filtered = products.filter { product in
            let matchesQuery: Bool
            if q.isEmpty {
                matchesQuery = true
            } else {
                matchesQuery =
                    product.title.localizedCaseInsensitiveContains(q) ||
                    product.tags.contains(where: { $0.localizedCaseInsensitiveContains(q) })
            }

            let matchesTag = selectedTag == nil || product.tags.contains(where: {
                $0.caseInsensitiveCompare(selectedTag ?? "") == .orderedSame
            })

            let matchesCondition = selectedConditions.isEmpty || selectedConditions.contains(product.conditionTag)
            let matchesPrice = product.price >= minPrice && product.price <= maxPrice
            let matchesFavorite = !onlyFavorites || product.isFavorite
            let matchesRating = product.rating >= minRating

            return matchesQuery && matchesTag && matchesCondition && matchesPrice && matchesFavorite && matchesRating
        }

        switch sortOption {
        case .relevance:
            return filtered
        case .priceLowHigh:
            return filtered.sorted { $0.price < $1.price }
        case .priceHighLow:
            return filtered.sorted { $0.price > $1.price }
        case .ratingHighLow:
            return filtered.sorted { $0.rating > $1.rating }
        }
    }

    func toggleFavorite(for product: Product) {
        guard let idx = products.firstIndex(where: { $0.id == product.id }) else { return }
        products[idx].isFavorite.toggle()
    }

    func selectTag(_ tag: String?) {
        selectedTag = tag
    }

    func toggleCondition(_ condition: String) {
        if selectedConditions.contains(condition) {
            selectedConditions.remove(condition)
        } else {
            selectedConditions.insert(condition)
        }
    }

    func resetFilters() {
        selectedTag = nil
        selectedConditions.removeAll()
        onlyFavorites = false
        minRating = 0
        sortOption = .relevance
        resetPriceRange()
    }

    private func resetPriceRange() {
        minPrice = priceBounds.lowerBound
        maxPrice = priceBounds.upperBound
    }
}
