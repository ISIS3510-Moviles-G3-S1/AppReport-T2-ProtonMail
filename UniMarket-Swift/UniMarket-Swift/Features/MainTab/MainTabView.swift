//
//  MainTabView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

enum MainTab {
    case home
    case search
    case activity
    case profile
}

struct MainTabView: View {
    @State private var selectedTab: MainTab = .home
    @State private var showUpload = false

    var body: some View {
        TabHost(selectedTab: $selectedTab, showUpload: $showUpload)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CustomTabBar(
                    selectedTab: $selectedTab,
                    onTapUpload: { showUpload = true }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8) // si la quieres MÁS abajo, pon 0
            }
            .sheet(isPresented: $showUpload) {
                NavigationStack { UploadProductView() }
            }
    }
}

private struct TabHost: View {
    @Binding var selectedTab: MainTab
    @Binding var showUpload: Bool

    var body: some View {
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
            NavigationStack { ProfileView() }
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: MainTab
    let onTapUpload: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(.background)
                .shadow(radius: 10)
                .frame(height: 64)

            HStack {
                tabButton(.home, icon: "house")
                Spacer()
                tabButton(.search, icon: "magnifyingglass")
                Spacer()
                Color.clear.frame(width: 56)
                Spacer()
                tabButton(.activity, icon: "heart")
                Spacer()
                tabButton(.profile, icon: "person")
            }
            .padding(.horizontal, 20)

            Button {
                onTapUpload()
            } label: {
                ZStack {
                    Circle()
                        .fill(.background)
                        .shadow(radius: 10)
                        .frame(width: 64, height: 64)
                    Circle()
                        .fill(Color.green.opacity(0.30))
                        .frame(width: 56, height: 56)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                }
            }
            .offset(y: -18) // prueba -10 si lo quieres menos “alto”
        }
    }

    private func tabButton(_ tab: MainTab, icon: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
}
