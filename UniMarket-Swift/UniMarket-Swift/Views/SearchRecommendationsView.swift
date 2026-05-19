import SwiftUI

struct SearchRecommendationsView: View {
    @ObservedObject var viewModel: SearchRecommendationsViewModel
    let onSelectRecentSearch: (String) -> Void
    let onToggleFavorite: (Product) -> Void
    let onSelectProduct: (Product) -> Void
    var isInCart: (Product) -> Bool = { _ in false }
    var onAddToCart: ((Product) -> Void)? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !viewModel.recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Based on your recent searches")
                            .font(.poppinsSemiBold(14))
                            .foregroundStyle(AppTheme.secondaryText)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(viewModel.recentSearches, id: \.self) { search in
                                    RecommendationChip(label: search) {
                                        onSelectRecentSearch(search)
                                    }
                                }
                            }
                        }
                    }
                }

                if viewModel.isLoadingRecommendations && viewModel.recommendedProducts.isEmpty {
                    ProgressView("Building recommendations...")
                        .font(.poppinsRegular(14))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                } else if viewModel.recommendedProducts.isEmpty {
                    Text("Like products and search for items to unlock personalized recommendations.")
                        .font(.poppinsRegular(14))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recommended for you")
                            .font(.poppinsSemiBold(16))
                            .foregroundStyle(AppTheme.primaryText)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(viewModel.recommendedProducts) { product in
                                ProductGridCard(
                                    product: product,
                                    onTapFavorite: {
                                        onToggleFavorite(product)
                                    },
                                    onTapCard: {
                                        onSelectProduct(product)
                                    },
                                    isInCart: isInCart(product),
                                    onTapAddToCart: onAddToCart.map { addToCart in
                                        { addToCart(product) }
                                    }
                                )
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 80)
        }
    }
}

private struct RecommendationChip: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.poppinsSemiBold(12))
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.cardBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppTheme.accent.opacity(0.45), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
