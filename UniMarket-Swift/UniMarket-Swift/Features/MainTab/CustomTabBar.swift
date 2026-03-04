//
//  CustomTabBar.swift
//  UniMarket-Swift
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: MainTab
    let onTapUpload: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(.white)
                .shadow(color: .black.opacity(0.12), radius: 10)
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
                        .fill(.white)
                        .shadow(color: .black.opacity(0.12), radius: 10)
                        .frame(width: 64, height: 64)
                    Circle()
                        .fill(AppTheme.accent.opacity(0.40))
                        .frame(width: 56, height: 56)
                    Image(systemName: "plus")
                        .font(.poppinsBold(22))
                        .foregroundStyle(AppTheme.primaryText)
                }
            }
            .offset(y: -18)
        }
    }

    private func tabButton(_ tab: MainTab, icon: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Image(systemName: icon)
                .font(.poppinsSemiBold(20))
                .foregroundStyle(selectedTab == tab ? AppTheme.primaryText : AppTheme.secondaryText)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
}
