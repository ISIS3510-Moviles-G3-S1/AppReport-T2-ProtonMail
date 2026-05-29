//
//  SearchViewModel.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import Foundation

enum SearchSection: String, CaseIterable, Identifiable {
    case browse = "Browse"
    case forYou = "For You"

    var id: String { rawValue }
}

enum SearchSortOption: String, CaseIterable, Identifiable, Sendable {
    case relevance = "Relevance"
    case priceLowHigh = "Price: Low to High"
    case priceHighLow = "Price: High to Low"
    case ratingHighLow = "Rating: High to Low"

    var id: String { rawValue }
}

struct BrowseSearchSnapshot: Sendable {
    let products: [Product]
    let query: String
    let selectedTag: String?
    let selectedConditions: Set<String>
    let onlyFavorites: Bool
    let minRating: Double
    let sortOption: SearchSortOption
    let minPrice: Int
    let maxPrice: Int
    /// When true, only listings with kind == .donation pass the filter.
    let showDonationsOnly: Bool

    init(
        products: [Product],
        query: String,
        selectedTag: String?,
        selectedConditions: Set<String>,
        onlyFavorites: Bool,
        minRating: Double,
        sortOption: SearchSortOption,
        minPrice: Int,
        maxPrice: Int,
        showDonationsOnly: Bool = false
    ) {
        self.products = products
        self.query = query
        self.selectedTag = selectedTag
        self.selectedConditions = selectedConditions
        self.onlyFavorites = onlyFavorites
        self.minRating = minRating
        self.sortOption = sortOption
        self.minPrice = minPrice
        self.maxPrice = maxPrice
        self.showDonationsOnly = showDonationsOnly
    }
}

enum SearchBrowseEngine {
    nonisolated static func filterProducts(using snapshot: BrowseSearchSnapshot) -> [Product] {
        let trimmedQuery = snapshot.query.trimmingCharacters(in: .whitespacesAndNewlines)

        let filtered = snapshot.products.filter { product in
            let matchesQuery: Bool
            if trimmedQuery.isEmpty {
                matchesQuery = true
            } else {
                matchesQuery =
                    product.title.localizedCaseInsensitiveContains(trimmedQuery) ||
                    product.tags.contains(where: { $0.localizedCaseInsensitiveContains(trimmedQuery) })
            }

            let matchesTag = snapshot.selectedTag == nil || product.tags.contains(where: {
                $0.caseInsensitiveCompare(snapshot.selectedTag ?? "") == .orderedSame
            })

            let matchesCondition = snapshot.selectedConditions.isEmpty || snapshot.selectedConditions.contains(product.conditionTag)
            let matchesPrice = product.price >= snapshot.minPrice && product.price <= snapshot.maxPrice
            let matchesFavorite = !snapshot.onlyFavorites || product.isFavorite
            let matchesRating = product.rating >= snapshot.minRating
            let matchesKind = !snapshot.showDonationsOnly || product.kind == .donation

            return matchesQuery && matchesTag && matchesCondition && matchesPrice && matchesFavorite && matchesRating && matchesKind
        }

        switch snapshot.sortOption {
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
}

enum SearchRecommendationEngine {
    struct RecommendationSignals {
        let favoriteTagWeights: [String: Int]
        let recentSearchTerms: [String]
        let preferredConditions: Set<String>
        let averageFavoritePrice: Double?
    }

    nonisolated static func buildRecommendations(from products: [Product], recentSearches: [String]) async -> [Product] {
        guard !products.isEmpty else { return [] }

        async let favoriteTagWeights = computeFavoriteTagWeights(from: products)
        async let recentSearchTerms = computeRecentSearchTerms(from: recentSearches)
        async let preferredConditions = computePreferredConditions(from: products)
        async let averageFavoritePrice = computeAverageFavoritePrice(from: products)

        let signals = await RecommendationSignals(
            favoriteTagWeights: favoriteTagWeights,
            recentSearchTerms: recentSearchTerms,
            preferredConditions: preferredConditions,
            averageFavoritePrice: averageFavoritePrice
        )

        guard !signals.favoriteTagWeights.isEmpty || !signals.recentSearchTerms.isEmpty else {
            return []
        }

        return await withTaskGroup(of: (Product, Int)?.self, returning: [Product].self) { group in
            for product in products where !product.isFavorite {
                group.addTask {
                    let score = await recommendationScore(for: product, signals: signals)
                    guard score > 0 else { return nil }
                    return (product, score)
                }
            }

            var rankedProducts: [(product: Product, score: Int)] = []
            for await candidate in group {
                guard let candidate else { continue }
                rankedProducts.append(candidate)
            }

            return rankedProducts
                .sorted { lhs, rhs in
                    if lhs.score == rhs.score {
                        return lhs.product.createdAt > rhs.product.createdAt
                    }
                    return lhs.score > rhs.score
                }
                .map(\.product)
        }
    }

    nonisolated static func computeFavoriteTagWeights(from products: [Product]) -> [String: Int] {
        let favoriteProducts = products.filter(\.isFavorite)
        var weights: [String: Int] = [:]

        for product in favoriteProducts {
            for tag in product.tags {
                let normalized = normalize(tag)
                guard !normalized.isEmpty else { continue }
                weights[normalized, default: 0] += 3
            }
        }

        return weights
    }

    nonisolated static func computeRecentSearchTerms(from recentSearches: [String]) -> [String] {
        recentSearches
            .flatMap { $0.components(separatedBy: CharacterSet.alphanumerics.inverted) }
            .map(normalize)
            .filter { $0.count >= 2 }
    }

    nonisolated static func computePreferredConditions(from products: [Product]) -> Set<String> {
        Set(
            products
                .filter(\.isFavorite)
                .map { normalize($0.conditionTag) }
                .filter { !$0.isEmpty }
        )
    }

    nonisolated static func computeAverageFavoritePrice(from products: [Product]) -> Double? {
        let favoritePrices = products
            .filter(\.isFavorite)
            .map(\.price)

        guard !favoritePrices.isEmpty else { return nil }
        let total = favoritePrices.reduce(0, +)
        return Double(total) / Double(favoritePrices.count)
    }

    nonisolated static func recommendationScore(for product: Product, signals: RecommendationSignals) async -> Int {
        await withTaskGroup(of: Int.self, returning: Int.self) { group in
            group.addTask {
                scoreFavoriteTags(for: product, weights: signals.favoriteTagWeights)
            }
            group.addTask {
                scoreRecentSearches(for: product, recentTerms: signals.recentSearchTerms)
            }
            group.addTask {
                scoreConditionAndPriceFit(
                    for: product,
                    preferredConditions: signals.preferredConditions,
                    averageFavoritePrice: signals.averageFavoritePrice
                )
            }
            group.addTask {
                scoreFreshnessAndQuality(for: product)
            }

            var total = 0
            for await partialScore in group {
                total += partialScore
            }
            return total
        }
    }

    nonisolated static func scoreFavoriteTags(for product: Product, weights: [String: Int]) -> Int {
        let normalizedTags = product.tags.map(normalize)
        var score = 0

        for tag in normalizedTags {
            score += weights[tag, default: 0]
        }

        return score
    }

    nonisolated static func scoreRecentSearches(for product: Product, recentTerms: [String]) -> Int {
        let normalizedTags = product.tags.map(normalize)
        let title = normalize(product.title)
        let description = normalize(product.description)

        var score = 0

        for term in recentTerms {
            if normalizedTags.contains(where: { $0.contains(term) || term.contains($0) }) {
                score += 2
            }

            if title.contains(term) {
                score += 2
            } else if description.contains(term) {
                score += 1
            }
        }

        return score
    }

    nonisolated static func scoreConditionAndPriceFit(
        for product: Product,
        preferredConditions: Set<String>,
        averageFavoritePrice: Double?
    ) -> Int {
        var score = 0
        let normalizedCondition = normalize(product.conditionTag)

        if preferredConditions.contains(normalizedCondition) {
            score += 2
        }

        if let averageFavoritePrice {
            let distance = abs(Double(product.price) - averageFavoritePrice)
            if distance <= 20000 {
                score += 3
            } else if distance <= 40000 {
                score += 1
            }
        }

        return score
    }

    nonisolated static func scoreFreshnessAndQuality(for product: Product) -> Int {
        var score = min(product.tags.count, 3)

        if product.rating >= 4.5 {
            score += 2
        } else if product.rating >= 4.0 {
            score += 1
        }

        let ageInDays = Calendar.current.dateComponents([.day], from: product.createdAt, to: .now).day ?? 0
        if ageInDays <= 7 {
            score += 2
        } else if ageInDays <= 21 {
            score += 1
        }

        return score
    }

    nonisolated static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
