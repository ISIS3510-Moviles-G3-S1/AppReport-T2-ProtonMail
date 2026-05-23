import SwiftUI

struct MyDonationsView: View {
    @StateObject var viewModel: MyDonationsViewModel
    @State private var selectedTab: Tab = .given

    enum Tab: Int, CaseIterable {
        case given, claimed
        var label: String { self == .given ? "Given" : "Claimed" }
        var icon: String { self == .given ? "heart.text.square" : "gift" }
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                tabHeader
                Divider().background(AppTheme.borderColor)
                tabContent
            }
        }
        .navigationTitle("My Donations")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.refresh() }
    }

    // MARK: - Tab header (custom, matches AppTheme styling)

    private var tabHeader: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func tabButton(_ tab: Tab) -> some View {
        let selected = selectedTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 14, weight: .semibold))
                    Text(tab.label)
                        .font(.poppinsSemiBold(14))
                }
                .foregroundStyle(selected ? AppTheme.accent : AppTheme.secondaryText)

                Rectangle()
                    .fill(selected ? AppTheme.accent : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content per tab

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .given:   givenList
        case .claimed: claimedList
        }
    }

    // MARK: - Given (donation listings I posted)

    @ViewBuilder
    private var givenList: some View {
        if viewModel.isLoading && viewModel.givenListings.isEmpty {
            VStack { Spacer(); ProgressView().tint(AppTheme.accent); Spacer() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.givenListings.isEmpty {
            emptyState(emoji: "🎁",
                       title: "No items donated yet",
                       subtitle: "Create a listing of kind \u{201C}Donation\u{201D} to start!")
        } else {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(viewModel.givenListings) { listing in
                        NavigationLink(value: listing) {
                            GivenListingRow(listing: listing)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .refreshable {
                viewModel.refresh()
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            .navigationDestination(for: Product.self) { product in
                ProductDetailView(product: product)
            }
        }
    }

    // MARK: - Claimed (my outgoing requests)

    @ViewBuilder
    private var claimedList: some View {
        if viewModel.isLoading && viewModel.claimedRequests.isEmpty {
            VStack { Spacer(); ProgressView().tint(AppTheme.accent); Spacer() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.claimedRequests.isEmpty {
            emptyState(emoji: "🛍️",
                       title: "No donation claims requested",
                       subtitle: "Browse donation listings and claim some items!")
        } else {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(viewModel.claimedRequests) { req in
                            ClaimedRequestRow(request: req)
                        }
                    }
                    .padding(16)
                }
                .refreshable {
                    viewModel.refresh()
                    try? await Task.sleep(nanoseconds: 250_000_000)
                }
                syncFooter
            }
        }
    }

    private var syncFooter: some View {
        let count = viewModel.syncingCount
        let waiting = count > 0
        return HStack(spacing: 8) {
            Image(systemName: waiting ? "arrow.triangle.2.circlepath" : "checkmark.icloud")
                .foregroundStyle(waiting ? .orange : .green)
            Text(waiting
                 ? "\(count) request\(count == 1 ? "" : "s") waiting to sync offline…"
                 : "All requests successfully synced")
                .font(.poppinsSemiBold(13))
                .foregroundStyle(waiting ? .orange : .green)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background((waiting ? Color.orange : Color.green).opacity(0.10))
    }

    private func emptyState(emoji: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Text(emoji).font(.system(size: 64))
            Text(title)
                .font(.poppinsBold(18))
                .foregroundStyle(AppTheme.primaryText)
            Text(subtitle)
                .font(.poppinsRegular(13))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Given row

private struct GivenListingRow: View {
    let listing: Product

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            ZStack {
                AppTheme.accent.opacity(0.15)
                if let url = listing.primaryImageURL {
                    CachedRemoteImageView(urlString: url, cacheKey: url)
                        .scaledToFill()
                } else {
                    Image(systemName: "heart.text.square")
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(listing.title)
                    .font(.poppinsBold(14))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                Text("Status: \(listing.status.firestoreValue.uppercased())")
                    .font(.poppinsRegular(11))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            statusPill(listing.status)
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statusPill(_ status: ProductStatus) -> some View {
        let active = status == .active
        let color: Color = active ? .green : AppTheme.secondaryText
        return Text(status.firestoreValue.uppercased())
            .font(.poppinsBold(11))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - Claimed row

private struct ClaimedRequestRow: View {
    let request: DonationRequestRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text("Listing ID: \(request.donationListingID)")
                    .font(.poppinsBold(14))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                if !request.isSyncedClaim || !request.isSyncedDecision {
                    sendingPill
                } else {
                    statusPill(request.status)
                }
            }
            if let msg = request.requesterMessage, !msg.isEmpty {
                Text("My message: \u{201C}\(msg)\u{201D}")
                    .font(.poppinsRegular(12)).italic()
                    .foregroundStyle(AppTheme.primaryText)
            }
            Text("Requested: \(Self.dateFormatter.string(from: request.createdAt))")
                .font(.poppinsRegular(11))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var sendingPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 10))
            Text("Sending…")
                .font(.poppinsBold(10))
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.orange.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func statusPill(_ status: DonationRequestStatus) -> some View {
        let color: Color = {
            switch status {
            case .pending:    return .orange
            case .approved:   return .green
            case .declined:   return .red
            case .withdrawn:  return AppTheme.secondaryText
            }
        }()
        return Text(status.rawValue.uppercased())
            .font(.poppinsBold(10))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()
}
