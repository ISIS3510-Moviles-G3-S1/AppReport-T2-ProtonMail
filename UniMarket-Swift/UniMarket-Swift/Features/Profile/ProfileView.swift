//
//  ProfileView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var vm: ProfileViewModel
    @EnvironmentObject var session: SessionManager
    @State private var showLogoutConfirm = false
    @State private var showImagePicker = false
    @State private var showImageSourceSelection = false
    @State private var imageSource: ImagePicker.Source = .photoLibrary
    private let metricColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    init(viewModel: ProfileViewModel = ProfileViewModel()) {
        _vm = StateObject(wrappedValue: viewModel)
    }

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

                    ProfileHeaderCard(
                        displayName: vm.displayName,
                        memberSince: vm.memberSince,
                        rating: vm.rating,
                        transactions: vm.transactions,
                        xp: vm.xp,
                        profilePicURL: vm.profilePicURL
                    ) {
                        showImageSourceSelection = true
                    }
                    .padding(.horizontal)

                    Divider().padding(.horizontal)

                    EcoSaysCard(message: vm.ecoMessage)
                        .padding(.horizontal)

                    SustainabilityProgressCard(xp: vm.xp, xpToNext: vm.xpToNext)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Listing Metrics")
                            .font(.poppinsSemiBold(16))
                            .foregroundStyle(AppTheme.primaryText)

                        Picker("Metrics Range", selection: $vm.selectedMetricsRange) {
                            ForEach(ProfileViewModel.MetricsRange.allCases) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)

                    LazyVGrid(columns: metricColumns, spacing: 12) {
                        ProfileMetricCard(
                            title: "Active Listings",
                            value: vm.profileMetrics.activeListings,
                            subtitle: "Listings currently visible in the marketplace.",
                            systemImage: "hanger",
                            tint: AppTheme.accent,
                            contextLabel: "Live from Firebase"
                        )

                        ProfileMetricCard(
                            title: "Items Sold",
                            value: vm.profileMetrics.itemsSold,
                            subtitle: "Items marked as sold during the selected period.",
                            systemImage: "checkmark.seal.fill",
                            tint: .green,
                            contextLabel: vm.selectedMetricsRangeLabel
                        )

                        ProfileMetricCard(
                            title: "Items Posted",
                            value: vm.profileMetrics.listingsCreated,
                            subtitle: "New listings created during the selected period.",
                            systemImage: "plus.circle.fill",
                            tint: .orange,
                            contextLabel: vm.selectedMetricsRangeLabel
                        )

                        ProfileMetricCard(
                            title: "Transactions",
                            value: vm.transactions,
                            subtitle: "Completed transactions from your user profile.",
                            systemImage: "arrow.left.arrow.right.circle.fill",
                            tint: .blue,
                            contextLabel: "All time"
                        )
                    }
                    .padding(.horizontal)

                    // TODO: Implement Recent Activity DB Integration
                    /*
                     Future Implementation Plan:
                     1. Create 'activities' collection in Firestore
                     2. Create Activity model with:
                        - id: String
                        - type: enum (sale, purchase, xp_gain, listing)
                        - title: String
                        - description: String
                        - date: Date
                        - icon: String
                     3. Add ActivityService to fetch recent activities for user
                     4. Update ProfileViewModel to expose [Activity] instead of [String]
                     */
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent Activity (Mock)")
                            .font(.poppinsSemiBold(16))
                            .foregroundStyle(AppTheme.primaryText)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(vm.activity, id: \.self) { act in
                                Label(act, systemImage: "star.fill") // Placeholder icon
                                    .font(.poppinsRegular(13))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }
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
        .confirmationDialog("Change Profile Picture", isPresented: $showImageSourceSelection) {
            Button("Camera") {
                imageSource = .camera
                showImagePicker = true
            }
            Button("Photo Library") {
                imageSource = .photoLibrary
                showImagePicker = true
            }
            Button("Delete Picture", role: .destructive) {
                Task {
                    await vm.deleteProfileImage()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(source: imageSource) { image in
                Task {
                    await vm.uploadProfileImage(image)
                }
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
