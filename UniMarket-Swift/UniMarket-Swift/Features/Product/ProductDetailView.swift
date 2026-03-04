//
//  ProductDetailView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct ProductDetailView: View {
    @EnvironmentObject private var chatStore: ChatStore

    @StateObject private var vm: ProductDetailViewModel
    @State private var editingListing: Listing?
    @State private var chatConversationID: String?

    private let onListingUpdated: ((Listing) -> Void)?

    init(product: Product) {
        _vm = StateObject(wrappedValue: ProductDetailViewModel(product: product))
        self.onListingUpdated = nil
    }

    init(listing: Listing, onListingUpdated: ((Listing) -> Void)? = nil) {
        _vm = StateObject(wrappedValue: ProductDetailViewModel(listing: listing))
        self.onListingUpdated = onListingUpdated
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    imageHeader

                    Text(vm.title)
                        .font(.poppinsBold(28))
                        .foregroundStyle(AppTheme.primaryText)

                    HStack {
                        Text("$\(vm.price)")
                            .font(.poppinsBold(24))
                            .foregroundStyle(AppTheme.accent)

                        Spacer()

                        Text(vm.conditionText)
                            .font(.poppinsSemiBold(12))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.accentAlt.opacity(0.45))
                            .clipShape(Capsule())
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Seller")
                            .font(.poppinsSemiBold(14))
                            .foregroundStyle(AppTheme.secondaryText)

                        HStack(spacing: 8) {
                            Text(vm.sellerName)
                                .font(.poppinsSemiBold(16))
                                .foregroundStyle(AppTheme.primaryText)

                            if let rating = vm.rating {
                                Text("•")
                                    .foregroundStyle(AppTheme.secondaryText)
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.accent)
                                Text(String(format: "%.1f", rating))
                                    .font(.poppinsRegular(14))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.poppinsSemiBold(16))
                            .foregroundStyle(AppTheme.primaryText)

                        Text(vm.description)
                            .font(.poppinsRegular(15))
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    actionButtons
                }
                .padding(16)
                .padding(.bottom, 110)
            }
        }
        .navigationTitle("Product Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingListing) { listing in
            EditListingView(
                listing: listing,
                onCancel: { editingListing = nil },
                onSave: { updated in
                    vm.applyListingUpdate(updated)
                    onListingUpdated?(updated)
                    editingListing = nil
                }
            )
        }
        .sheet(item: chatRouteBinding) { route in
            NavigationStack {
                ChatThreadView(conversationID: route.id)
            }
        }
    }

    private var imageHeader: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .frame(height: 280)

            Image(vm.imageName)
                .font(.poppinsSemiBold(72))
                .foregroundStyle(AppTheme.secondaryText)
                .scaledToFit()
                .frame(height: 280) // adjust per design
                .frame(width: 300)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))

        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if vm.isOwnListing {
            Button("Edit Listing") {
                editingListing = vm.editableListing()
            }
            .font(.poppinsSemiBold(16))
            .foregroundStyle(AppTheme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.accentAlt)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            HStack(spacing: 12) {
                Button {
                    vm.toggleFavorite()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: vm.isFavorite ? "heart.fill" : "heart")
                        Text(vm.isFavorite ? "Saved" : "Save")
                    }
                    .font(.poppinsSemiBold(16))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.accentAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Button("Message") {
                    chatConversationID = chatStore.startConversation(
                        productID: vm.id,
                        productTitle: vm.title,
                        sellerName: vm.sellerName,
                        productImageName: vm.imageName
                    )
                }
                .font(.poppinsSemiBold(16))
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private struct ChatRoute: Identifiable {
        let id: String
    }

    private var chatRouteBinding: Binding<ChatRoute?> {
        Binding<ChatRoute?>(
            get: {
                guard let id = chatConversationID else { return nil }
                return ChatRoute(id: id)
            },
            set: { newValue in
                chatConversationID = newValue?.id
            }
        )
    }
}
