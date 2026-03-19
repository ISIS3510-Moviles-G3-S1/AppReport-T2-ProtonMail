//
//  SearchView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var productStore: ProductStore
    @StateObject private var vm = SearchViewModel()
    @State private var selectedProduct: Product?
    @State private var showFilters = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    HStack {
                        Text("Browse")
                            .font(.poppinsBold(30))
                            .foregroundStyle(AppTheme.accent)
                        Spacer()
                        Text("UniMarket")
                            .font(.poppinsRegular(12))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .padding(.horizontal)

                    HStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(AppTheme.secondaryText)
                            TextField("Search items...", text: $vm.query)
                                .font(.poppinsRegular(15))
                                .foregroundStyle(AppTheme.accent)
                        }
                        .padding(12)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        Button {} label: {
                            Image(systemName: "camera")
                                .frame(width: 44, height: 44)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                showFilters = true
                            }
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "slider.horizontal.3") //filtros
                                    .frame(width: 44, height: 44)
                                    .background(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                if vm.activeFilterCount > 0 {
                                    Text("\(vm.activeFilterCount)")
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
                            tagChip(label: "All", isSelected: vm.selectedTag == nil) {
                                vm.selectTag(nil)
                            }

                            ForEach(vm.availableTags, id: \.self) { tag in
                                tagChip(label: tag.capitalized, isSelected: vm.selectedTag == tag) {
                                    vm.selectTag(tag)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    ScrollView {
                        if productStore.isLoading && vm.products.isEmpty {
                            ProgressView("Loading products...")
                                .frame(maxWidth: .infinity)
                                .padding(.top, 48)
                        } else if vm.filteredProducts.isEmpty {
                            Text("No products available yet.")
                                .font(.poppinsRegular(14))
                                .foregroundStyle(AppTheme.secondaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 48)
                        } else {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(vm.filteredProducts) { product in
                                    ProductGridCard(
                                        product: product,
                                        onTapFavorite: {
                                            productStore.toggleFavorite(for: product)
                                            vm.toggleFavorite(for: product)
                                        },
                                        onTapCard: {
                                            selectedProduct = product
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 4)
                            .padding(.bottom, 80)
                        }
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

                    HStack {
                        Spacer()
                        filtersPanel
                            .frame(width: min(320, proxy.size.width * 0.82))
                            .transition(.move(edge: .trailing))
                    }
                    .ignoresSafeArea()
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: showFilters)
        .task {
            vm.updateProducts(productStore.activeProducts)
        }
        .onReceive(productStore.$products) { products in
            vm.updateProducts(products.filter { $0.status == .active }.sorted { $0.createdAt > $1.createdAt })
        }
        .navigationDestination(item: $selectedProduct) { product in
            ProductDetailView(product: product)
        }
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

                    Text("$\(vm.minPrice) - $\(vm.maxPrice)")
                        .font(.poppinsRegular(13))
                        .foregroundStyle(AppTheme.secondaryText)

                    Slider(value: minPriceBinding, in: Double(vm.priceBounds.lowerBound)...Double(vm.priceBounds.upperBound), step: 1)
                    Slider(value: maxPriceBinding, in: Double(vm.priceBounds.lowerBound)...Double(vm.priceBounds.upperBound), step: 1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Condition")
                        .font(.poppinsSemiBold(15))

                    WrapChips(items: vm.availableConditions, selectedItems: vm.selectedConditions) { condition in
                        vm.toggleCondition(condition)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Minimum Rating")
                        .font(.poppinsSemiBold(15))

                    Text(String(format: "%.1f ★", vm.minRating))
                        .font(.poppinsRegular(13))
                        .foregroundStyle(AppTheme.secondaryText)

                    Slider(value: $vm.minRating, in: 0...5, step: 0.5)
                }

                Toggle(isOn: $vm.onlyFavorites) {
                    Text("Only favorites")
                        .font(.poppinsSemiBold(15))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Sort")
                        .font(.poppinsSemiBold(15))

                    Picker("Sort", selection: $vm.sortOption) {
                        ForEach(SearchViewModel.SortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.poppinsRegular(14))
                }

                HStack(spacing: 10) {
                    Button("Reset") {
                        vm.resetFilters()
                    }
                    .font(.poppinsSemiBold(14))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button("Apply") {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            showFilters = false
                        }
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
        .background(Color.white)
    }

    private var minPriceBinding: Binding<Double> {
        Binding(
            get: { Double(vm.minPrice) },
            set: { newValue in
                let newMin = Int(newValue)
                vm.minPrice = min(newMin, vm.maxPrice)
            }
        )
    }

    private var maxPriceBinding: Binding<Double> {
        Binding(
            get: { Double(vm.maxPrice) },
            set: { newValue in
                let newMax = Int(newValue)
                vm.maxPrice = max(newMax, vm.minPrice)
            }
        )
    }

    private func tagChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.poppinsSemiBold(12))
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? AppTheme.accentAlt : Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppTheme.accent.opacity(0.45), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct WrapChips: View {
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
