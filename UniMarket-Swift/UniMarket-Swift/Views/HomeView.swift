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
    @State private var showNotifications = false

    let onBrowseItems: () -> Void
    let onStartSelling: () -> Void
    let onStartDonating: () -> Void

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
                        onStartSelling: onStartSelling,
                        onStartDonating: onStartDonating
                    )

                    donationsEntryCard

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
            ToolbarItemGroup(placement: .topBarTrailing) {
                CartToolbarButton()

                // Bell icon — opens the Concurrent Notifications Aggregator sheet.
                Button {
                    showNotifications = true
                } label: {
                    Image(systemName: "bell")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                }

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
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
                .environmentObject(chatStore)
                .environmentObject(productStore)
                .environmentObject(session)
        }
    }

    /// Entry card to the Donations marketplace — opens DonationsBrowseView
    /// in the current NavigationStack.
    private var donationsEntryCard: some View {
        NavigationLink {
            DonationsBrowseView(viewModel: DonationsBrowseViewModel())
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(AppTheme.accent.opacity(0.15))
                    Image(systemName: "gift.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Donations")
                        .font(.poppinsBold(15))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Browse free items from your peers")
                        .font(.poppinsRegular(12))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(14)
            .background(AppTheme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
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
