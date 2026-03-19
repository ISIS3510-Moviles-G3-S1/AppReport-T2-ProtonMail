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

    let onBrowseItems: () -> Void
    let onStartSelling: () -> Void

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

                    FeaturedProductCard(product: productStore.activeProducts.first)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
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
}
