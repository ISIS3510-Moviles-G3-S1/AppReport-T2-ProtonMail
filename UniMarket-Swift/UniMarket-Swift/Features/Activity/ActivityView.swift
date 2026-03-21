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
        }
        .task {
            vm.sync(products: productStore.products, currentUserID: session.user?.uid)
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
                Task {
                    await deleteListing()
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
                                    AsyncImageView(urlString: imageURL, cacheKey: imageURL)
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
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(AppTheme.accent)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
    private func deleteListing() async {
        guard let product = listingPendingDelete else { return }

        do {
            try await productStore.deleteProduct(product)
            vm.deleteListing(product)
            listingPendingDelete = nil
        } catch {
            deleteErrorMessage = error.localizedDescription
        }
    }
}
