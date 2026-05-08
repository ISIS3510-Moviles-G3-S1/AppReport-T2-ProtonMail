import SwiftUI

struct BrowseSearchView: View {
    let isStoreLoading: Bool
    @ObservedObject var viewModel: BrowseSearchViewModel
    let onSubmitSearch: () -> Void
    let onToggleFavorite: (Product) -> Void
    let onSelectProduct: (Product) -> Void
    let onResetFilters: () -> Void
    let onApplyFilters: () -> Void
    var onRefresh: (() async -> Void)? = nil

    @Binding var showFilters: Bool

    @ObservedObject private var network = NetworkMonitor.shared
    @ObservedObject private var prefs = UserPreferencesStore.shared

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .trailing) {
                VStack(spacing: 12) {
                    // Offline banner — shown when disconnected and user hasn't disabled it in Preferences
                    if !network.isConnected && prefs.showOfflineBanner {
                        HStack(spacing: 8) {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 13, weight: .semibold))
                            Text("You're offline — showing cached results")
                                .font(.poppinsRegular(12))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.25), value: network.isConnected)
                    }

                    HStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(AppTheme.secondaryText)
                            TextField("Search items...", text: $viewModel.query)
                                .font(.poppinsRegular(15))
                                .foregroundStyle(AppTheme.accent)
                                .onSubmit {
                                    onSubmitSearch()
                                }
                        }
                        .padding(12)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        Button {} label: {
                            Image(systemName: "camera")
                                .frame(width: 44, height: 44)
                                .background(AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                showFilters = true
                            }
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "slider.horizontal.3")
                                    .frame(width: 44, height: 44)
                                    .background(AppTheme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                if viewModel.activeFilterCount > 0 {
                                    Text("\(viewModel.activeFilterCount)")
                                        .font(.poppinsSemiBold(10))
                                        .foregroundStyle(.white)
                                        .padding(4)
                                        .background(AppTheme.accent)
                                        .clipShape(Circle())
                                        .offset(x: 6, y: -6)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            SearchTagChip(label: "All", isSelected: viewModel.selectedTag == nil) {
                                viewModel.selectTag(nil)
                            }

                            ForEach(viewModel.availableTags, id: \.self) { tag in
                                SearchTagChip(label: tag.capitalized, isSelected: viewModel.selectedTag == tag) {
                                    viewModel.selectTag(tag)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    ScrollView {
                        browseContent
                    }
                    .refreshable {
                        await onRefresh?()
                    }
                }

                if showFilters {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                showFilters = false
                            }
                        }

                    filtersPanel
                        .frame(width: min(320, proxy.size.width * 0.82))
                        .transition(.move(edge: .trailing))
                        .ignoresSafeArea()
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: showFilters)
    }

    private var browseContent: some View {
        Group {
            if isStoreLoading && viewModel.products.isEmpty {
                ProgressView("Loading products...")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
            } else if viewModel.isSearching && viewModel.filteredProducts.isEmpty {
                ProgressView("Searching products...")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
            } else if viewModel.filteredProducts.isEmpty {
                Text("No products available yet.")
                    .font(.poppinsRegular(14))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
            } else {
                productGrid(products: viewModel.filteredProducts)
            }
        }
    }

    private func productGrid(products: [Product]) -> some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(products) { product in
                ProductGridCard(
                    product: product,
                    onTapFavorite: {
                        onToggleFavorite(product)
                    },
                    onTapCard: {
                        onSelectProduct(product)
                    }
                )
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
        .padding(.bottom, 80)
    }

    private var filtersPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Filters")
                        .font(.poppinsBold(22))
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            showFilters = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.poppinsSemiBold(14))
                            .padding(10)
                            .background(AppTheme.background)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Price")
                        .font(.poppinsSemiBold(15))

                    Text("$\(viewModel.minPrice) - $\(viewModel.maxPrice)")
                        .font(.poppinsRegular(13))
                        .foregroundStyle(AppTheme.secondaryText)

                    Slider(value: minPriceBinding, in: Double(viewModel.priceBounds.lowerBound)...Double(viewModel.priceBounds.upperBound), step: 1)
                    Slider(value: maxPriceBinding, in: Double(viewModel.priceBounds.lowerBound)...Double(viewModel.priceBounds.upperBound), step: 1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Condition")
                        .font(.poppinsSemiBold(15))

                    SearchWrapChips(items: viewModel.availableConditions, selectedItems: viewModel.selectedConditions) { condition in
                        viewModel.toggleCondition(condition)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Minimum Rating")
                        .font(.poppinsSemiBold(15))

                    Text(String(format: "%.1f ★", viewModel.minRating))
                        .font(.poppinsRegular(13))
                        .foregroundStyle(AppTheme.secondaryText)

                    Slider(value: $viewModel.minRating, in: 0...5, step: 0.5)
                }

                Toggle(isOn: $viewModel.onlyFavorites) {
                    Text("Only favorites")
                        .font(.poppinsSemiBold(15))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Sort")
                        .font(.poppinsSemiBold(15))

                    Picker("Sort", selection: $viewModel.sortOption) {
                        ForEach(SearchSortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.poppinsRegular(14))
                }

                HStack(spacing: 10) {
                    Button("Reset") {
                        onResetFilters()
                    }
                    .font(.poppinsSemiBold(14))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button("Apply") {
                        onApplyFilters()
                    }
                    .font(.poppinsSemiBold(14))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.accentAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(16)
        }
        .background(AppTheme.cardBackground)
    }

    private var minPriceBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.minPrice) },
            set: { newValue in
                let newMin = Int(newValue)
                viewModel.minPrice = min(newMin, viewModel.maxPrice)
            }
        )
    }

    private var maxPriceBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.maxPrice) },
            set: { newValue in
                let newMax = Int(newValue)
                viewModel.maxPrice = max(newMax, viewModel.minPrice)
            }
        )
    }
}

private struct SearchTagChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.poppinsSemiBold(12))
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? AppTheme.accentAlt : AppTheme.cardBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppTheme.accent.opacity(0.45), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct SearchWrapChips: View {
    let items: [String]
    let selectedItems: Set<String>
    let onTap: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button {
                    onTap(item)
                } label: {
                    Text(item)
                        .font(.poppinsSemiBold(12))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(selectedItems.contains(item) ? AppTheme.accentAlt : AppTheme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
