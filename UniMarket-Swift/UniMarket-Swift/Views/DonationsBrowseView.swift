import SwiftUI

struct DonationsBrowseView: View {
    @StateObject var viewModel: DonationsBrowseViewModel
    @EnvironmentObject var productStore: ProductStore
    @Environment(\.isPresented) var isPresented

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.listings.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    donationGrid
                }
            }
            .navigationTitle("Donations")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.refresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: NSNotification.Name("networkStatusChanged")),
                perform: { _ in
                    if !NetworkMonitor.shared.isConnected {
                        viewModel.loadOfflineSnapshot()
                    }
                }
            )
        }
    }

    var donationGrid: some View {
        VStack(spacing: 0) {
            if let snapshot = viewModel.offlineSnapshot {
                HStack {
                    Image(systemName: "wifi.slash")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Last refreshed \(snapshot.timeSinceFetch)")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.yellow.opacity(0.1))
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(viewModel.listings) { product in
                            NavigationLink(destination: ProductDetailView(product: product)) {
                                DonationListingCard(product: product)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No Donations Available")
                .font(.headline)
            Text("Check back soon for more donation listings")
                .font(.caption)
                .foregroundColor(.gray)
            Button(action: { viewModel.refresh() }) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxHeight: .infinity, alignment: .center)
        .padding()
    }
}

struct DonationListingCard: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if let imageURL = product.primaryImageURL {
                    CachedRemoteImageView(urlString: imageURL)
                        .scaledToFill()
                        .frame(height: 150)
                        .clipped()
                } else {
                    Color.gray.opacity(0.2)
                        .frame(height: 150)
                }
                VStack(alignment: .leading) {
                    Text("FREE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(6)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    Spacer()
                }
                .padding(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(product.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                Text(product.sellerName)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}
