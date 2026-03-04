//
//  ProfileView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var vm = ProfileViewModel()

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
                }
                .padding(.top, 10)
            }
        }
    }
}
