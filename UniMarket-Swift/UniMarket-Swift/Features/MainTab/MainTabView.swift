//
//  MainTabView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

enum MainTab: Hashable {
    case home
    case search
    case activity
    case profile
}

struct MainTabView: View {
    @State private var selectedTab: MainTab = .home
    @State private var showUpload = false
    @StateObject private var profileViewModel = ProfileViewModel()

    private let barHeight: CGFloat = 64
    private let sidePadding: CGFloat = 16
    private let bottomSpacing: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                tabContent
                    .frame(width: proxy.size.width, height: proxy.size.height)

                CustomTabBar(
                    selectedTab: $selectedTab,
                    onTapUpload: { showUpload = true }
                )
                .frame(width: proxy.size.width - (sidePadding * 2), height: barHeight)
                .position(
                    x: proxy.size.width / 2,
                    y: proxy.size.height - (barHeight / 2) - bottomSpacing
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $showUpload) {
            NavigationStack { 
                UploadProductView()
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            guard newTab == .profile else { return }
            Task {
                await profileViewModel.onProfileTabSelected()
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .home:
            NavigationStack {
                HomeView(
                    onBrowseItems: { selectedTab = .search },
                    onStartSelling: { showUpload = true }
                )
            }
        case .search:
            NavigationStack { SearchView() }
        case .activity:
            NavigationStack { ActivityView() }
        case .profile:
            NavigationStack { ProfileView(viewModel: profileViewModel) }
        }
    }
}
