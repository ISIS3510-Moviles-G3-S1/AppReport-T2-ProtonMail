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
    private let analytics = AnalyticsService.shared
    @State private var selectedTab: MainTab = .home
    @State private var showUpload = false
    /// Pre-selected listing kind for the upload sheet — flipped to .donation
    /// when the Home "Donate" button presents it.
    @State private var uploadKind: ListingKind = .sale
    @State private var tabBarHidden = false
    @StateObject private var profileViewModel = ProfileViewModel()
    /// Owned here so the watchlist survives tab switches and is available to
    /// both ActivityView (WatchlistView) and ProductDetailView (WatchlistAddButton)
    /// through the environment regardless of which NavigationStack is active.
    @StateObject private var watchlistVM = WatchlistViewModel()
    @ObservedObject private var pendingListings = PendingListingsSyncer.shared
    @ObservedObject private var pendingMessages = PendingChatMessagesSyncer.shared
    @ObservedObject private var pendingFavorites = PendingFavoritesSyncer.shared
    @ObservedObject private var pendingMutations = PendingListingMutationsSyncer.shared

    private let barHeight: CGFloat = 64
    private let sidePadding: CGFloat = 16
    private let bottomSpacing: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                tabContent
                    .environmentObject(watchlistVM)
                    .frame(width: proxy.size.width, height: proxy.size.height)

                if totalPendingCount > 0 {
                    pendingListingsBanner
                        .frame(width: proxy.size.width - (sidePadding * 2))
                        .position(x: proxy.size.width / 2, y: 44)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if !tabBarHidden {
                    CustomTabBar(
                        selectedTab: $selectedTab,
                        onTapUpload: { showUpload = true }
                    )
                    .frame(width: proxy.size.width - (sidePadding * 2), height: barHeight)
                    .position(
                        x: proxy.size.width / 2,
                        y: proxy.size.height - (barHeight / 2) - bottomSpacing
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $showUpload) {
            NavigationStack {
                UploadProductView(initialKind: uploadKind)
            }
        }
        .onChange(of: showUpload) { _, isShowing in
            // Reset to .sale once dismissed so the next plain "Start Selling"
            // tap doesn't accidentally inherit the previous donation flag.
            if !isShowing { uploadKind = .sale }
        }
        .onAppear {
            analytics.track(.tabSelected(selectedTab.analyticsName))
        }
        .onChange(of: selectedTab) { _, newTab in
            analytics.track(.tabSelected(newTab.analyticsName))
            guard newTab == .profile else { return }
            Task {
                await profileViewModel.onProfileTabSelected()
            }
        }
        .environment(\.hideTabBar, $tabBarHidden)
    }

    private var totalPendingCount: Int {
        pendingListings.pendingCount
            + pendingMessages.pendingCount
            + pendingFavorites.pendingCount
            + pendingMutations.pendingCount
    }

    private var anyDraining: Bool {
        pendingListings.isDraining
            || pendingMessages.isDraining
            || pendingFavorites.isDraining
            || pendingMutations.isDraining
    }

    private var pendingListingsBanner: some View {
        let label = bannerLabel
        return HStack(spacing: 10) {
            if anyDraining {
                ProgressView()
                    .tint(AppTheme.primaryText)
            } else {
                Image(systemName: "wifi.exclamationmark")
                    .foregroundStyle(AppTheme.primaryText)
            }
            Text(label)
                .font(.poppinsRegular(13))
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.accentAlt.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Single-queue: name the type. Multi-queue: generic "X changes" copy.
    private var bannerLabel: String {
        let parts: [(Int, String)] = [
            (pendingListings.pendingCount, "listing"),
            (pendingMessages.pendingCount, "message"),
            (pendingFavorites.pendingCount, "favorite"),
            (pendingMutations.pendingCount, "edit")
        ].filter { $0.0 > 0 }

        let total = totalPendingCount
        if parts.count == 1, let only = parts.first {
            let noun = only.1 + (only.0 == 1 ? "" : "s")
            if anyDraining {
                return "Syncing \(only.0) \(noun)…"
            }
            return "\(only.0) \(noun) waiting for connectivity"
        }
        if anyDraining {
            return "Syncing \(total) change\(total == 1 ? "" : "s")…"
        }
        return "\(total) change\(total == 1 ? "" : "s") waiting for connectivity"
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .home:
            NavigationStack {
                HomeView(
                    onBrowseItems: { selectedTab = .search },
                    onStartSelling: {
                        uploadKind = .sale
                        showUpload = true
                    },
                    onStartDonating: {
                        uploadKind = .donation
                        showUpload = true
                    }
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

private extension MainTab {
    var analyticsName: String {
        switch self {
        case .home: return "home"
        case .search: return "search"
        case .activity: return "activity"
        case .profile: return "profile"
        }
    }
}
