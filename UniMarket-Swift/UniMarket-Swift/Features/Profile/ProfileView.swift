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

                    EcoSaysCard(message: vm.ecoMessage, isLoading: vm.isGeneratingEcoMessage)
                        .padding(.horizontal)

                    SustainabilityProgressCard(
                        xp: vm.xp,
                        xpToNext: vm.xpToNext,
                        levelInfo: vm.calculateLevelInfo(xp: vm.xp)
                    )
                        .padding(.horizontal)

                    Picker("Time Range", selection: $vm.selectedTimeRange) {
                        ForEach(ProfileViewModel.TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    HStack(spacing: 12) {
                        ProfileMetricCard(
                            title: "Items Listed",
                            value: vm.monthlyProductStats.listingsCreated,
                            subtitle: "products created",
                            systemImage: "square.and.pencil",
                            tint: AppTheme.accent,
                            contextLabel: vm.selectedTimeRange.rawValue
                        )

                        ProfileMetricCard(
                            title: "Items Sold",
                            value: vm.monthlyProductStats.itemsSold,
                            subtitle: "products sold",
                            systemImage: "checkmark.circle.fill",
                            tint: .green,
                            contextLabel: vm.selectedTimeRange.rawValue
                        )
                    }
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
                    .padding(.bottom, 120)
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
