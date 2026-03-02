//
//  HomeView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct HomeView: View {
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

                    FeaturedProductCard()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
        }
    }
}
