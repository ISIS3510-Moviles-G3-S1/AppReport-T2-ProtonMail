//
//  ProductDetailView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct ProductDetailView: View {
    private let analytics = AnalyticsService.shared
    @EnvironmentObject private var chatStore: ChatStore
    @EnvironmentObject private var productStore: ProductStore

    @StateObject private var vm: ProductDetailViewModel
    @StateObject private var networkMonitor = NetworkMonitor()
    @State private var editingProduct: Product?
    @State private var chatConversationID: String?
    @State private var isStartingChat = false
    @State private var isUpdatingSaleState = false
    @State private var saleStateErrorMessage: String?
    @State private var showGenerateQR = false
    @State private var showScanQR = false

    private let onProductUpdated: ((Product) -> Void)?
    private let source: AnalyticsSurface

    init(
        product: Product,
        source: AnalyticsSurface = .unknown,
        isOwnListing: Bool = false,
        onProductUpdated: ((Product) -> Void)? = nil
    ) {
        _vm = StateObject(wrappedValue: ProductDetailViewModel(product: product, isOwnListing: isOwnListing))
        self.source = source
        self.onProductUpdated = onProductUpdated
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !networkMonitor.isConnected {
                        HStack(spacing: 8) {
                            Image(systemName: "internaldrive")
                                .foregroundStyle(AppTheme.secondaryText)
                            Text("You're offline — showing locally stored data")
                                .font(.poppinsRegular(13))
                                .foregroundStyle(AppTheme.secondaryText)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

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

                    if vm.isOwnListing {
                        saleStateSection
                    } else if vm.status == .sold {
                        soldNotice
                    }

                    if !vm.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Tags")
                                .font(.poppinsSemiBold(16))
                                .foregroundStyle(AppTheme.primaryText)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
                                ForEach(vm.tags, id: \.self) { tag in
                                    Text(tag.capitalized)
                                        .font(.poppinsSemiBold(12))
                                        .foregroundStyle(AppTheme.primaryText)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(AppTheme.accentAlt.opacity(0.35))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    actionButtons
                }
                .padding(16)
                .padding(.bottom, 110)
            }
        }
        .navigationTitle("Product Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let event = AnalyticsEvent.productDetailViewed(
                productID: vm.id,
                price: vm.price,
                condition: vm.conditionText,
                isOwnListing: vm.isOwnListing,
                source: source.rawValue
            )
            analytics.track(event)

            if let surfaceEvent = AnalyticsEvent.surfaceProductDetailViewed(
                productID: vm.id,
                price: vm.price,
                condition: vm.conditionText,
                isOwnListing: vm.isOwnListing,
                source: source.rawValue
            ) {
                analytics.track(surfaceEvent)
            }
            FavoritesCacheManager.shared.saveLastInteraction()
        }
        .onReceive(productStore.$products) { products in
            guard let updatedProduct = products.first(where: { $0.id == vm.id }) else { return }
            vm.sync(with: updatedProduct)
        }
        .sheet(item: $editingProduct) { product in
            EditListingView(
                product: product,
                onCancel: { editingProduct = nil },
                onSave: { updated in
                    Task {
                        try? await productStore.updateProduct(updated)
                        await MainActor.run {
                            vm.applyProductUpdate(updated)
                            onProductUpdated?(updated)
                            editingProduct = nil
                        }
                    }
                }
            )
        }
        .sheet(item: chatRouteBinding) { route in
            NavigationStack {
                ChatThreadView(conversationID: route.id)
                    .environmentObject(chatStore)
            }
        }
        .sheet(isPresented: $showGenerateQR) {
            NavigationStack {
                GenerateQRView(listingId: vm.id, sellerId: vm.sellerId, listingStatus: vm.status)
            }
        }
        .sheet(isPresented: $showScanQR) {
            ScanQRView(productID: vm.id, source: source)
        }
        .alert("Couldn't Update Listing", isPresented: saleStateErrorBinding) {
            Button("OK", role: .cancel) {
                saleStateErrorMessage = nil
            }
        } message: {
            Text(saleStateErrorMessage ?? "Unknown error")
        }
    }

    // MARK: - Image header

    private var imageHeader: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.cardBackground)
                .frame(height: 280)

            if vm.imageURLs.isEmpty {
                Image(systemName: "photo")
                    .font(.poppinsSemiBold(72))
                    .foregroundStyle(AppTheme.secondaryText)
                    .scaledToFit()
                    .frame(height: 280)
                    .frame(width: 300)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                TabView {
                    ForEach(vm.imageURLs, id: \.self) { imageURL in
                        CachedRemoteImageView(urlString: imageURL, cacheKey: imageURL)
                            .frame(height: 280)
                            .frame(width: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .frame(height: 280)
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
        }
    }

    // MARK: - Action buttons

    @ViewBuilder
    private var actionButtons: some View {
        if vm.isOwnListing {
            VStack(spacing: 10) {
                Button("Edit Listing") {
                    editingProduct = vm.editableProduct()
                }
                .font(.poppinsSemiBold(16))
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.accentAlt)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button {
                    showGenerateQR = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "qrcode")
                        Text("Generate QR Code")
                    }
                    .font(.poppinsSemiBold(16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(vm.status == .sold || isUpdatingSaleState)
                .opacity(vm.status == .sold || isUpdatingSaleState ? 0.55 : 1)
            }
        } else {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                // MARK: Favorite button
                Button {
                    let nextFavoriteState = !vm.isFavorite
                    if let product = productStore.products.first(where: { $0.id == vm.id }) {
                        productStore.toggleFavorite(for: product)
                    } else {
                        vm.toggleFavorite()
                    }
                    let event = AnalyticsEvent.favoriteToggled(
                        productID: vm.id,
                        isFavorite: nextFavoriteState,
                        source: source == .unknown ? AnalyticsSurface.productDetail.rawValue : source.rawValue
                    )
                    analytics.track(event)

                    if let surfaceEvent = AnalyticsEvent.surfaceFavoriteToggled(
                        productID: vm.id,
                        isFavorite: nextFavoriteState,
                        source: source.rawValue
                    ) {
                        analytics.track(surfaceEvent)
                    }
                    FavoritesCacheManager.shared.saveLastInteraction()
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
                .disabled(vm.status != .active)
                .opacity(vm.status == .active ? 1 : 0.55)

                // MARK: Message button
                Button {
                    guard !isStartingChat else { return }
                    isStartingChat = true
                    // BQ#1 buyer-intent marker — fires on tap, not after the
                    // Firestore write, so offline taps still count.
                    analytics.track(.chatStartedFromListing(
                        productID: vm.id,
                        sellerID: vm.sellerId,
                        price: vm.price,
                        source: source == .unknown
                            ? AnalyticsSurface.productDetail.rawValue
                            : source.rawValue
                    ))
                    Task {
                        do {
                            let listing = ChatMessage.ListingSnapshot(
                                listingId: vm.id,
                                title: vm.title,
                                price: vm.price,
                                imagePath: vm.imageURLs.first ?? ""
                            )
                            let conversationID = try await chatStore.startOrGetConversation(
                                sellerID: vm.sellerId,
                                listing: listing
                            )
                            await MainActor.run {
                                chatConversationID = conversationID
                                isStartingChat = false
                            }
                        } catch {
                            await MainActor.run { isStartingChat = false }
                        }
                    }
                } label: {
                    Group {
                        if isStartingChat {
                            ProgressView().tint(AppTheme.primaryText)
                        } else {
                            Text("Message")
                        }
                    }
                    .font(.poppinsSemiBold(16))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(vm.status != .active || isStartingChat)
                .opacity(vm.status == .active ? 1 : 0.55)
            }

            // MARK: Scan QR button (buyer)
            Button {
                showScanQR = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "qrcode.viewfinder")
                    Text("Scan QR to Confirm Pickup")
                }
                .font(.poppinsSemiBold(16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(vm.status != .active)
            .opacity(vm.status == .active ? 1 : 0.55)
            } // end VStack (buyer)
        }
    }

    private var saleStateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Listing Status")
                .font(.poppinsSemiBold(16))
                .foregroundStyle(AppTheme.primaryText)

            Toggle(isOn: soldToggleBinding) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mark as sold")
                        .font(.poppinsSemiBold(15))
                        .foregroundStyle(AppTheme.primaryText)

                    Text(vm.status == .sold ? "This listing is hidden from buyers across the app." : "Turn this on when the item is no longer available.")
                        .font(.poppinsRegular(13))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .tint(AppTheme.accent)
            .disabled(isUpdatingSaleState)

            if isUpdatingSaleState {
                ProgressView()
                    .tint(AppTheme.accent)
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var soldNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white)

            Text("This item has already been sold.")
                .font(.poppinsSemiBold(14))
                .foregroundStyle(.white)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Chat sheet routing

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

    private var soldToggleBinding: Binding<Bool> {
        Binding(
            get: { vm.status == .sold },
            set: { isSold in
                Task {
                    await updateSaleState(isSold: isSold)
                }
            }
        )
    }

    private var saleStateErrorBinding: Binding<Bool> {
        Binding(
            get: { saleStateErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    saleStateErrorMessage = nil
                }
            }
        )
    }

    @MainActor
    private func updateSaleState(isSold: Bool) async {
        guard vm.isOwnListing, !isUpdatingSaleState else { return }
        guard let updatedProduct = vm.productForSaleState(isSold: isSold) else { return }

        isUpdatingSaleState = true
        defer { isUpdatingSaleState = false }

        do {
            try await productStore.updateProduct(updatedProduct)
            vm.applyProductUpdate(updatedProduct)
            onProductUpdated?(updatedProduct)
        } catch {
            saleStateErrorMessage = error.localizedDescription
        }
    }
}
