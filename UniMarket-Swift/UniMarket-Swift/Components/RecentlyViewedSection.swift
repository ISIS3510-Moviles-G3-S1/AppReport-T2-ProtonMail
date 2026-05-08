import SwiftUI

struct RecentlyViewedSection: View {
    @EnvironmentObject private var productStore: ProductStore

    let products: [Product]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.accent.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Recently Viewed")
                        .font(.poppinsBold(24))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("Products you've checked out recently.")
                        .font(.poppinsRegular(13))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()
            }

            if products.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "eye.slash")
                        .foregroundStyle(AppTheme.secondaryText)
                    Text("Products you view will appear here.")
                        .font(.poppinsRegular(13))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(products) { product in
                            NavigationLink {
                                ProductDetailView(product: product)
                            } label: {
                                ProductGridCard(
                                    product: product,
                                    onTapFavorite: {
                                        productStore.toggleFavorite(for: product)
                                    },
                                    onTapCard: {}
                                )
                                .frame(width: 220)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(18)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.14), lineWidth: 1)
        )
    }
}
