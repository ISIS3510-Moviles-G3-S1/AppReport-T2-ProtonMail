// Components/WatchlistAddButton.swift
// UniMarket-Swift
//
// Toggles a product's watchlist membership.
// Injected into ProductDetailView's action section (non-own listings only).
// Reads from the shared WatchlistViewModel via @EnvironmentObject so state
// stays in sync with WatchlistView regardless of navigation path.

import SwiftUI

struct WatchlistAddButton: View {
    let product: Product

    @EnvironmentObject private var watchlistVM: WatchlistViewModel

    var body: some View {
        let watching = watchlistVM.isWatched(product.id)

        Button {
            if watching {
                watchlistVM.removeFromWatchlist(productID: product.id)
            } else {
                watchlistVM.addToWatchlist(product)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: watching ? "bell.fill" : "bell")
                Text(watching ? "Watching ✓" : "Watch Price")
            }
            .font(.poppinsSemiBold(16))
            .foregroundStyle(AppTheme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(watching ? AppTheme.accentAlt.opacity(0.55) : AppTheme.accentAlt)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: watching)
    }
}
