import SwiftUI

struct CartView: View {
    private let analytics = AnalyticsService.shared
    @EnvironmentObject private var cartStore: CartStore
    @EnvironmentObject private var productStore: ProductStore
    @EnvironmentObject private var session: SessionManager

    @State private var selectedProduct: Product?
    @State private var showClearConfirmation = false

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            if cartStore.items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(cartStore.items) { item in
                            CartItemRow(
                                item: item,
                                onSelect: {
                                    selectedProduct = item.product
                                },
                                onRemove: {
                                    cartStore.remove(productID: item.product.id)
                                }
                            )
                        }

                        orderSummary
                    }
                    .padding(16)
                    .padding(.bottom, 90)
                }
            }
        }
        .navigationTitle("Cart")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !cartStore.items.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") {
                        showClearConfirmation = true
                    }
                    .font(.poppinsSemiBold(14))
                    .foregroundStyle(.red)
                }
            }
        }
        .onAppear {
            cartStore.load(for: session.uid)
            cartStore.reconcile(with: productStore.products)
        }
        .onReceive(productStore.$products) { products in
            cartStore.reconcile(with: products)
        }
        .navigationDestination(item: $selectedProduct) { product in
            ProductDetailView(product: product, source: .cart)
        }
        .confirmationDialog(
            "Clear cart?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Cart", role: .destructive) {
                cartStore.clear()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all items from your cart on this device.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)

            Text("Your cart is empty.")
                .font(.poppinsSemiBold(18))
                .foregroundStyle(AppTheme.primaryText)

            Text("Add products from Browse or Product Details.")
                .font(.poppinsRegular(13))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var orderSummary: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Items")
                    .font(.poppinsRegular(14))
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
                Text("\(cartStore.itemCount)")
                    .font(.poppinsSemiBold(14))
                    .foregroundStyle(AppTheme.primaryText)
            }

            HStack {
                Text("Subtotal")
                    .font(.poppinsSemiBold(16))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Text("$\(cartStore.subtotal)")
                    .font(.poppinsBold(20))
                    .foregroundStyle(AppTheme.accent)
            }

            if cartStore.hasUnavailableItems {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Remove unavailable items before checkout.")
                        .font(.poppinsRegular(12))
                        .foregroundStyle(AppTheme.secondaryText)
                    Spacer()
                }
            }

            NavigationLink {
                CheckoutView()
            } label: {
                Text("Checkout")
                    .font(.poppinsSemiBold(16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(cartStore.hasUnavailableItems ? Color.gray : AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(cartStore.hasUnavailableItems)
            .simultaneousGesture(TapGesture().onEnded {
                guard !cartStore.hasUnavailableItems else { return }
                trackCheckoutStarted()
            })
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var aiStylistItemCount: Int {
        cartStore.items.filter { $0.source == AnalyticsSurface.aiStylist.rawValue }.count
    }

    private var aiStylistSubtotal: Int {
        cartStore.items
            .filter { $0.source == AnalyticsSurface.aiStylist.rawValue }
            .reduce(0) { $0 + $1.product.price }
    }

    private func trackCheckoutStarted() {
        analytics.track(.checkoutStarted(
            itemCount: cartStore.itemCount,
            subtotal: cartStore.subtotal,
            aiStylistItemCount: aiStylistItemCount,
            aiStylistSubtotal: aiStylistSubtotal
        ))
    }
}

private struct CartItemRow: View {
    let item: CartItem
    let onSelect: () -> Void
    let onRemove: () -> Void

    private var isAvailable: Bool {
        item.product.status == .active
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    productImage

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(item.product.title)
                                .font(.poppinsSemiBold(15))
                                .foregroundStyle(AppTheme.primaryText)
                                .lineLimit(1)

                            if !isAvailable {
                                Text(item.product.status.rawValue)
                                    .font(.poppinsSemiBold(10))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.gray)
                                    .clipShape(Capsule())
                            }
                        }

                        Text(item.product.sellerName)
                            .font(.poppinsRegular(12))
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(1)

                        Text("$\(item.product.price)")
                            .font(.poppinsBold(15))
                            .foregroundStyle(AppTheme.accent)
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.background)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove from cart")
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isAvailable ? Color.white.opacity(0.18) : Color.orange.opacity(0.35), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var productImage: some View {
        if let imageURL = item.product.primaryImageURL, !imageURL.isEmpty {
            CachedRemoteImageView(urlString: imageURL, cacheKey: imageURL)
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.background)
                Image(systemName: "photo")
                    .font(.poppinsSemiBold(22))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .frame(width: 76, height: 76)
        }
    }
}
