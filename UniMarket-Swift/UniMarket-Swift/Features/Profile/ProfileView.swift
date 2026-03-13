//
//  ProfileView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var vm = ProfileViewModel()
    @EnvironmentObject var session: SessionManager
    @State private var showLogoutConfirm = false

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Profile")
                        .font(.poppinsBold(30))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal)

                    ProfileHeaderCard(profile: vm.profile)
                        .padding(.horizontal)

                    Divider().padding(.horizontal)

                    EcoSaysCard(message: vm.ecoMessage)
                        .padding(.horizontal)

                    SustainabilityProgressCard(profile: vm.profile)
                        .padding(.horizontal)

                    HStack(spacing: 12) {
                        ProfileMetricCard(
                            title: "Listings made",
                            value: vm.monthlyProductStats.listingsCreated,
                            subtitle: "Products posted from your current listings data.",
                            systemImage: "plus.square.fill",
                            tint: AppTheme.accent
                        )

                        ProfileMetricCard(
                            title: "Clothes sold",
                            value: vm.monthlyProductStats.itemsSold,
                            subtitle: "Items marked as sold in the last month.",
                            systemImage: "checkmark.seal.fill",
                            tint: AppTheme.accentAlt
                        )
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent Activity")
                            .font(.poppinsSemiBold(16))
                            .foregroundStyle(AppTheme.primaryText)

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Sold shirt and won 5 XP", systemImage: "tshirt.fill")
                            Label("Posted a new tote bag listing", systemImage: "bag.fill")
                        }
                        .font(.poppinsRegular(13))
                        .foregroundStyle(AppTheme.secondaryText)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white)
                            .shadow(color: .black.opacity(0.05), radius: 4)
                    )
                    .padding(.horizontal)

                    Button {
                        showLogoutConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Log Out")
                                .font(.poppinsSemiBold(16))
                        }
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white)
                                .shadow(color: .black.opacity(0.05), radius: 4)
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .padding(.top, 10)
            }
        }
        .confirmationDialog("Are you sure you want to log out?",
                            isPresented: $showLogoutConfirm,
                            titleVisibility: .visible) {
            Button("Log Out", role: .destructive) {
                try? session.signOut()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
