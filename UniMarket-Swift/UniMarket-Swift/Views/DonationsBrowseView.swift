import SwiftUI

struct DonationsBrowseView: View {
    @StateObject var viewModel: DonationsBrowseViewModel
    @EnvironmentObject var productStore: ProductStore
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                refreshStatusBar
                categoryChipsBar
                contentArea
            }
        }
        .navigationTitle("Donations")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.refresh() }
        .onChange(of: networkMonitor.isConnected) { wasConnected, isConnected in
            // When connectivity comes back, mirror the Flutter behaviour: re-fetch.
            guard !wasConnected, isConnected else { return }
            viewModel.refresh(forceNetwork: true)
        }
    }

    // MARK: - Top status bar (offline banner / last-refreshed pill)

    @ViewBuilder
    private var refreshStatusBar: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 10) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red)
                Text("Offline Mode • \(refreshedLabel)")
                    .font(.poppinsSemiBold(13))
                    .foregroundStyle(.red)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.10))
        } else if viewModel.lastRefreshTime != nil {
            HStack {
                Text(refreshedLabel)
                    .font(.poppinsRegular(11))
                    .italic()
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    private var refreshedLabel: String {
        guard let ts = viewModel.lastRefreshTime else { return "Not refreshed yet" }
        let diff = Date().timeIntervalSince(ts)
        if diff < 60 { return "Last refreshed just now" }
        let minutes = Int(diff / 60)
        if minutes < 60 { return "Last refreshed \(minutes)m ago" }
        return "Refreshed at \(Self.timeFormatter.string(from: ts))"
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    // MARK: - Category filter chips

    private var categoryChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DonationsBrowseViewModel.categories, id: \.key) { cat in
                    chip(for: cat.key, label: cat.label)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 48)
        .padding(.vertical, 8)
    }

    private func chip(for key: String, label: String) -> some View {
        let selected = viewModel.selectedCategory == key
        return Button {
            viewModel.selectCategory(key)
        } label: {
            Text(label)
                .font(.poppinsSemiBold(13))
                .foregroundStyle(selected ? AppTheme.primaryText : AppTheme.secondaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? AppTheme.accent.opacity(0.25) : AppTheme.cardBackground)
                .overlay(
                    Capsule().stroke(
                        selected ? AppTheme.accent : AppTheme.borderColor,
                        lineWidth: selected ? 1.5 : 1
                    )
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content area (loading / error / empty / grid)

    @ViewBuilder
    private var contentArea: some View {
        if let error = viewModel.errorMessage, viewModel.listings.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Text("Error loading donations")
                    .font(.poppinsSemiBold(15))
                    .foregroundStyle(.red)
                Text(error)
                    .font(.poppinsRegular(12))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else if viewModel.isLoading && viewModel.listings.isEmpty {
            VStack { Spacer(); ProgressView().tint(AppTheme.accent); Spacer() }
                .frame(maxWidth: .infinity)
        } else if viewModel.listings.isEmpty {
            emptyState
        } else {
            grid
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("🎁").font(.system(size: 64))
            Text("No donations available")
                .font(.poppinsBold(18))
                .foregroundStyle(AppTheme.primaryText)
            Text("Try selecting a different filter.")
                .font(.poppinsRegular(13))
                .foregroundStyle(AppTheme.secondaryText)
            Button {
                viewModel.refresh(forceNetwork: true)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.poppinsSemiBold(14))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.listings) { product in
                    NavigationLink(value: product) {
                        DonationListingCard(product: product)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .refreshable {
            viewModel.refresh(forceNetwork: true)
            // Let the spinner show briefly so the gesture feels acknowledged.
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        .navigationDestination(for: Product.self) { product in
            ProductDetailView(product: product)
        }
    }
}

// MARK: - Card

struct DonationListingCard: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if let url = product.primaryImageURL {
                    CachedRemoteImageView(urlString: url, cacheKey: url)
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                        .clipped()
                } else {
                    ZStack {
                        AppTheme.cardBackground
                        Image(systemName: "gift")
                            .font(.system(size: 36))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .frame(height: 140)
                }

                Text("FREE")
                    .font(.poppinsBold(10))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .padding(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(product.title)
                    .font(.poppinsSemiBold(14))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)

                Text(product.conditionTag)
                    .font(.poppinsRegular(11))
                    .foregroundStyle(AppTheme.secondaryText)

                if !product.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(product.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.poppinsRegular(10))
                                    .foregroundStyle(AppTheme.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.accent.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding(8)
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.borderColor, lineWidth: 1)
        )
    }
}
