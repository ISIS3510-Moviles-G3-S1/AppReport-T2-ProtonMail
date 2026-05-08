//
//  ActivityView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI
import FirebaseAuth

struct ActivityView: View {
    @EnvironmentObject private var productStore: ProductStore
    @EnvironmentObject private var session: SessionManager
    @StateObject private var vm = ActivityViewModel()
    @ObservedObject private var pendingFavorites = PendingFavoritesSyncer.shared
    @State private var selectedListing: Product?
    @State private var selectedLikedProduct: Product?
    @State private var listingPendingDelete: Product?
    @State private var deleteErrorMessage: String?

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Activity")
                            .font(.poppinsBold(30))
                            .foregroundStyle(AppTheme.primaryText)
                        Spacer()
                    }
                    .padding(.horizontal)

                    // BQ: last-interaction banner — message changes by inactivity bracket
                    if !vm.feedbackMessage.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: vm.lastInteractionDate == nil ? "sparkles"
                                             : vm.userActivityState == .active ? "checkmark.circle.fill"
                                             : vm.userActivityState == .idle ? "clock.fill"
                                             : vm.userActivityState == .inactive ? "exclamationmark.circle.fill"
                                             : "zzz")
                                .foregroundStyle(vm.lastInteractionDate == nil ? AppTheme.accent
                                                 : vm.userActivityState == .active ? Color.green
                                                 : vm.userActivityState == .idle ? AppTheme.accent
                                                 : vm.userActivityState == .inactive ? Color.orange
                                                 : Color.red)
                            Text(vm.feedbackMessage)
                                .font(.poppinsRegular(13))
                                .foregroundStyle(AppTheme.primaryText)
                            Spacer()
                        }
                        .padding(12)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }

                    Picker("", selection: $vm.selectedTab) {
                        ForEach(ActivityViewModel.Tab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    Group {
                        switch vm.selectedTab {
                        case .likes:
                            likesSection
                        case .listings:
                            listingsSection
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 90)
                }
                .padding(.top, 10)
            }
            .refreshable {
                vm.sync(products: productStore.products, currentUserID: session.user?.uid)
                vm.refreshInteractionState()
            }
        }
        .task {
            vm.sync(products: productStore.products, currentUserID: session.user?.uid)
            vm.refreshInteractionState()
        }
        .onReceive(productStore.$products) { products in
            vm.sync(products: products, currentUserID: session.user?.uid)
        }
        .onReceive(session.$user) { user in
            vm.sync(products: productStore.products, currentUserID: user?.uid)
        }
        .navigationDestination(item: $selectedListing) { product in
            ProductDetailView(product: product, isOwnListing: true, onProductUpdated: { updated in
                vm.updateListing(updated)
                selectedListing = updated
            })
        }
        .navigationDestination(item: $selectedLikedProduct) { product in
            ProductDetailView(product: product)
        }
        .confirmationDialog(
            "Delete this listing?",
            isPresented: deleteConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                // Capture product synchronously RIGHT HERE before dialog dismisses
                let productToDelete = listingPendingDelete
                listingPendingDelete = nil
                Task {
                    await deleteListing(product: productToDelete)
                }
            }
            Button("Cancel", role: .cancel) {
                listingPendingDelete = nil
            }
        } message: {
            Text("This will remove the listing from your profile.")
        }
        .alert("Couldn't Delete Listing", isPresented: deleteErrorBinding) {
            Button("OK", role: .cancel) {
                deleteErrorMessage = nil
            }
        } message: {
            Text(deleteErrorMessage ?? "Unknown error")
        }
    }

    private var likesSection: some View {
        VStack(spacing: 12) {
            if pendingFavorites.pendingCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(pendingFavorites.pendingCount) favorite\(pendingFavorites.pendingCount == 1 ? "" : "s") syncing")
                        .font(.poppinsRegular(11))
                }
                .foregroundStyle(AppTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if vm.likedProducts.isEmpty {
                Text("No saved items yet.")
                    .font(.poppinsRegular(14))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            } else {
                ForEach(vm.likedProducts) { product in
                    Button {
                        selectedLikedProduct = product
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(AppTheme.background)
                                    .frame(width: 72, height: 72)

                                if let imageURL = product.primaryImageURL, !imageURL.isEmpty {
                                    CachedRemoteImageView(urlString: imageURL, cacheKey: imageURL)
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 18))
                                } else {
                                    Image(systemName: "photo")
                                        .font(.poppinsSemiBold(22))
                                        .foregroundStyle(AppTheme.secondaryText)
                                        .frame(width: 72, height: 72)
                                        .background(AppTheme.background)
                                        .clipShape(RoundedRectangle(cornerRadius: 18))
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.title)
                                    .font(.poppinsSemiBold(15))
                                    .foregroundStyle(AppTheme.primaryText)
                                    .lineLimit(1)

                                Text("$\(product.price) • \(product.conditionTag)")
                                    .font(.poppinsRegular(13))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }

                            Spacer()

                            Button {
                                vm.removeSavedProduct(product)
                                productStore.toggleFavorite(for: product)
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "heart.fill")
                                        .foregroundStyle(AppTheme.accent)
                                    if pendingFavorites.isPending(product.id) {
                                        Image(systemName: "clock.fill")
                                            .font(.system(size: 8))
                                            .foregroundStyle(AppTheme.secondaryText)
                                            .offset(x: 4, y: -4)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var listingsSection: some View {
        VStack(spacing: 14) {
            if vm.listings.isEmpty {
                Text("You haven't uploaded any products yet.")
                    .font(.poppinsRegular(14))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }

            ForEach(vm.listings) { product in
                ListingCard(
                    product: product,
                    onDelete: {
                        listingPendingDelete = product
                    },
                    onTapDetail: { selectedListing = product }
                )
            }
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { listingPendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    listingPendingDelete = nil
                }
            }
        )
    }

    private var deleteErrorBinding: Binding<Bool> {
        Binding(
            get: { deleteErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    deleteErrorMessage = nil
                }
            }
        )
    }

    @MainActor
    private func deleteListing(product: Product?) async {
        guard let product else { return }

        do {
            try await productStore.deleteProduct(product)
            vm.deleteListing(product)
        } catch {
            deleteErrorMessage = error.localizedDescription
        }
    }
}
