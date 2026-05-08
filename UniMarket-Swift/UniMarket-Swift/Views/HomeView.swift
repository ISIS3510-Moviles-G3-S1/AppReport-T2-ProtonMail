//
//  HomeView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var chatStore: ChatStore
    @EnvironmentObject private var productStore: ProductStore
    @EnvironmentObject private var session: SessionManager
    @StateObject private var viewModel = HomeViewModel()
    @State private var recentlyViewed: [Product] = []

    let onBrowseItems: () -> Void
    let onStartSelling: () -> Void

    private var browseProducts: [Product] {
        productStore.browseProducts(excludingUserID: session.uid)
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    HomeHeaderView()

                    HomeActionButtonsView(
                        onBrowseItems: onBrowseItems,
                        onStartSelling: onStartSelling
                    )

                    seasonSection

                    RecentlyViewedSection(products: recentlyViewed)

                    FeaturedProductCard(product: browseProducts.first)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            .refreshable {
                await productStore.loadSavedItems()
            }
        }
        .onAppear {
            recentlyViewed = RecentlyViewedCache.shared.products(for: session.uid)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ChatInboxView()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: chatStore.totalUnreadCount > 0 ? "tray.fill" : "tray")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)

                        if chatStore.totalUnreadCount > 0 {
                            Circle()
                                .fill(AppTheme.accent)
                                .frame(width: 9, height: 9)
                                .offset(x: 3, y: -3)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var seasonSection: some View {
#if DEBUG
        SeasonForYouSection(
            season: viewModel.currentSeason(),
            products: viewModel.productsForCurrentSeason(from: browseProducts),
            debugSelection: $viewModel.debugSeasonSelection
        )
#else
        SeasonForYouSection(
            season: viewModel.currentSeason(),
            products: viewModel.productsForCurrentSeason(from: browseProducts)
        )
#endif
    }
}
