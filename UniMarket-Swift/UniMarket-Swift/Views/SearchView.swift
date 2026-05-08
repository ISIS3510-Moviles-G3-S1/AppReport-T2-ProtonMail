//
//  SearchView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct SearchView: View {
    private let analytics = AnalyticsService.shared
    @EnvironmentObject private var productStore: ProductStore
    @StateObject private var browseViewModel = BrowseSearchViewModel()
    @StateObject private var recommendationsViewModel = SearchRecommendationsViewModel()
    @StateObject private var networkMonitor = NetworkMonitor()
    @State private var selectedSection: SearchSection = .browse
    @State private var selectedProductRoute: ProductRoute?
    @State private var hasTrackedSearchView = false
    @State private var showFilters = false

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Text("Browse")
                        .font(.poppinsBold(30))
                        .foregroundStyle(AppTheme.accent)
                    Spacer()
                    Text("UniMarket")
                        .font(.poppinsRegular(12))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.horizontal)

                if !networkMonitor.isConnected {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .foregroundStyle(.orange)
                        Text("You're offline — showing cached products")
                            .font(.poppinsRegular(13))
                            .foregroundStyle(.orange)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal)
                }

                Picker("", selection: $selectedSection) {
                    ForEach(SearchSection.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if selectedSection == .browse {
                    BrowseSearchView(
                        isStoreLoading: productStore.isLoading,
                        viewModel: browseViewModel,
                        onSubmitSearch: {
                            recommendationsViewModel.saveSearch(browseViewModel.query)
                        },
                        onToggleFavorite: { product in
                            toggleFavorite(for: product, source: .browseSearch)
                        },
                        onSelectProduct: { product in
                            if !browseViewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                recommendationsViewModel.saveSearch(browseViewModel.query)
                            }
                            selectProduct(product, source: .browseSearch)
                        },
                        onResetFilters: {
                            browseViewModel.resetFilters()
                            analytics.track(.searchReset())
                        },
                        onApplyFilters: {
                            analytics.track(.searchFiltersApplied(
                                activeFilterCount: browseViewModel.activeFilterCount,
                                selectedTag: browseViewModel.selectedTag,
                                selectedConditionCount: browseViewModel.selectedConditions.count,
                                onlyFavorites: browseViewModel.onlyFavorites,
                                minRating: browseViewModel.minRating,
                                sortOption: browseViewModel.sortOption.rawValue
                            ))
                            withAnimation(.easeInOut(duration: 0.22)) {
                                showFilters = false
                            }
                        },
                        onRefresh: {
                            await productStore.loadSavedItems()
                        },
                        showFilters: $showFilters
                    )
                } else {
                    SearchRecommendationsView(
                        viewModel: recommendationsViewModel,
                        onSelectRecentSearch: { search in
                            browseViewModel.applyRecentSearch(search)
                            recommendationsViewModel.saveSearch(search)
                            selectedSection = .browse
                        },
                        onToggleFavorite: { product in
                            toggleFavorite(for: product, source: .searchRecommendations)
                        },
                        onSelectProduct: { product in
                            selectProduct(product, source: .searchRecommendations)
                        }
                    )
                }
            }
        }
        .task {
            browseViewModel.updateProducts(productStore.activeProducts)
            recommendationsViewModel.updateProducts(productStore.activeProducts)
            guard !hasTrackedSearchView else { return }
            analytics.track(.searchViewed())
            analytics.track(.productListViewed(source: AnalyticsSurface.browseSearch.rawValue, resultCount: browseViewModel.filteredProducts.count))
            hasTrackedSearchView = true
        }
        .onReceive(productStore.$products) { products in
            let activeProducts = products.filter { $0.status == .active }.sorted { $0.createdAt > $1.createdAt }
            browseViewModel.updateProducts(activeProducts)
            recommendationsViewModel.updateProducts(activeProducts)
        }
        .onChange(of: browseViewModel.query) { _, newValue in
            let trimmedQuery = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            analytics.track(.searchQueryChanged(length: trimmedQuery.count, hasQuery: !trimmedQuery.isEmpty))
        }
        .onChange(of: browseViewModel.filteredProducts.map(\.id)) { _, _ in
            trackSearchResultsListView()
        }
        .onChange(of: selectedSection) { _, newSection in
            guard newSection == .forYou else { return }
            trackSearchRecommendationsListView()
        }
        .onChange(of: recommendationsViewModel.recommendedProducts.map(\.id)) { _, _ in
            trackSearchRecommendationsListView()
        }
        .navigationDestination(item: $selectedProductRoute) { route in
            ProductDetailView(product: route.product, source: route.source)
        }
    }

    private func toggleFavorite(for product: Product, source: AnalyticsSurface) {
        productStore.toggleFavorite(for: product)
        browseViewModel.toggleFavorite(for: product)
        recommendationsViewModel.toggleFavorite(for: product)
        let event = AnalyticsEvent.favoriteToggled(
            productID: product.id,
            isFavorite: !product.isFavorite,
            source: source.rawValue
        )
        analytics.track(event)

        if let surfaceEvent = AnalyticsEvent.surfaceFavoriteToggled(
            productID: product.id,
            isFavorite: !product.isFavorite,
            source: source.rawValue
        ) {
            analytics.track(surfaceEvent)
        }
        FavoritesCacheManager.shared.saveLastInteraction()
    }

    private func selectProduct(_ product: Product, source: AnalyticsSurface) {
        analytics.track(.productSelected(productID: product.id, source: source.rawValue))
        selectedProductRoute = ProductRoute(product: product, source: source)
    }

    private func trackSearchResultsListView() {
        analytics.track(.productListViewed(source: AnalyticsSurface.browseSearch.rawValue, resultCount: browseViewModel.filteredProducts.count))
    }

    private func trackSearchRecommendationsListView() {
        analytics.track(.productListViewed(
            source: AnalyticsSurface.searchRecommendations.rawValue,
            resultCount: recommendationsViewModel.recommendedProducts.count
        ))
    }
}

private struct ProductRoute: Identifiable, Hashable {
    let product: Product
    let source: AnalyticsSurface

    var id: String {
        "\(source.rawValue)-\(product.id)"
    }

    static func == (lhs: ProductRoute, rhs: ProductRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
