// Views/WatchlistView.swift
// UniMarket-Swift
//
// Displays the user's price watchlist.
// Pulls prices on demand; shows stale / offline-aware captions per row.

import SwiftUI

// MARK: - WatchlistView

struct WatchlistView: View {
    @ObservedObject var viewModel: WatchlistViewModel

    var body: some View {
        Group {
            if viewModel.watchedItems.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
    }

    // MARK: - List

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.watchedItems) { entry in
                    WatchlistRowView(
                        entry: entry,
                        snapshot: viewModel.cachedPrices[entry.id],
                        isOffline: !viewModel.isConnected
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 90)
        }
        .refreshable {
            await viewModel.refreshAndWait()
        }
        .overlay(alignment: .bottom) {
            refreshBar
                .padding(.horizontal)
                .padding(.bottom, 96)
        }
    }

    // MARK: - Refresh bar

    @ViewBuilder
    private var refreshBar: some View {
        if viewModel.isConnected {
            Button {
                viewModel.refreshAllPrices()
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isRefreshing {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text(viewModel.isRefreshing ? "Checking prices…" : "Refresh prices")
                        .font(.poppinsSemiBold(13))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(AppTheme.accent)
                .clipShape(Capsule())
            }
            .disabled(viewModel.isRefreshing)
            .opacity(viewModel.isRefreshing ? 0.75 : 1)
            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 13, weight: .semibold))
                Text("Connect to refresh")
                    .font(.poppinsSemiBold(13))
            }
            .foregroundStyle(AppTheme.secondaryText)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(AppTheme.cardBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.borderColor, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bell.badge")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.secondaryText)

            Text("No items watched")
                .font(.poppinsSemiBold(17))
                .foregroundStyle(AppTheme.primaryText)

            Text("Tap \"Watch Price\" on any listing to\ntrack price drops here.")
                .font(.poppinsRegular(14))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - WatchlistRowView

struct WatchlistRowView: View {
    let entry: WatchlistEntry
    /// nil until the first successful price fetch.
    let snapshot: WatchlistPriceSnapshot?
    let isOffline: Bool

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.poppinsSemiBold(15))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(2)

                priceRow

                if isOffline {
                    offlineCaption
                } else {
                    lastCheckedCaption
                }
            }

            Spacer(minLength: 0)

            if let snapshot {
                deltaPill(current: snapshot.price, baseline: snapshot.previousPrice ?? entry.originalPrice)
            }
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.background)
                .frame(width: 68, height: 68)

            if let url = entry.imageURL, !url.isEmpty {
                CachedRemoteImageView(urlString: url, cacheKey: url)
                    .frame(width: 68, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 22))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(width: 68, height: 68)
            }
        }
    }

    private var priceRow: some View {
        HStack(spacing: 6) {
            // Original price (at time of adding to watchlist)
            Text("$\(entry.originalPrice)")
                .font(.poppinsRegular(13))
                .foregroundStyle(AppTheme.secondaryText)
                .strikethrough(snapshot != nil && snapshot!.price != entry.originalPrice,
                               color: AppTheme.secondaryText)

            if let snapshot {
                Text("$\(snapshot.price)")
                    .font(.poppinsSemiBold(15))
                    .foregroundStyle(
                        snapshot.price < entry.originalPrice ? Color(hex: "3A9D5D")
                            : snapshot.price > entry.originalPrice ? Color.red
                            : AppTheme.primaryText
                    )
            } else {
                Text("—")
                    .font(.poppinsRegular(14))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var offlineCaption: some View {
        HStack(spacing: 4) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 10))
            Text("Offline — showing last known price")
                .font(.poppinsRegular(11))
        }
        .foregroundStyle(Color(UIColor.systemGray3))
    }

    @ViewBuilder
    private var lastCheckedCaption: some View {
        if let snapshot {
            Text("Last checked: \(relativeTime(from: snapshot.cachedAt))")
                .font(.poppinsRegular(11))
                .foregroundStyle(AppTheme.secondaryText)
        } else {
            Text("Not yet checked")
                .font(.poppinsRegular(11))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    // MARK: - Delta pill

    @ViewBuilder
    private func deltaPill(current: Int, baseline: Int) -> some View {
        if current == baseline {
            EmptyView()
        } else {
            let drop = current < baseline
            let diff = abs(current - baseline)
            HStack(spacing: 2) {
                Image(systemName: drop ? "arrow.down" : "arrow.up")
                    .font(.system(size: 9, weight: .bold))
                Text("$\(diff)")
                    .font(.poppinsSemiBold(11))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(drop ? Color(hex: "3A9D5D") : Color.red)
            .clipShape(Capsule())
        }
    }

    // MARK: - Helpers

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
