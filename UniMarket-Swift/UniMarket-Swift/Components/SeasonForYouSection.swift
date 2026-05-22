import SwiftUI

struct SeasonForYouSection: View {
    @EnvironmentObject private var productStore: ProductStore

    let season: HomeViewModel.SeasonalMoment
    let products: [Product]
#if DEBUG
    @Binding var debugSelection: HomeViewModel.SeasonSelection
#endif

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: season.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.accent.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(season.title)
                        .font(.poppinsBold(24))
                        .foregroundStyle(AppTheme.primaryText)

                    Text(season.subtitle)
                        .font(.poppinsRegular(13))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

#if DEBUG
                Picker("Season", selection: $debugSelection) {
                    ForEach(HomeViewModel.SeasonSelection.allCases) { selection in
                        Text(selection.label).tag(selection)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.secondaryText)
#endif
            }

            if products.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(AppTheme.secondaryText)
                    Text("Seasonal picks will appear here when new listings match the season.")
                        .font(.poppinsRegular(13))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
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
