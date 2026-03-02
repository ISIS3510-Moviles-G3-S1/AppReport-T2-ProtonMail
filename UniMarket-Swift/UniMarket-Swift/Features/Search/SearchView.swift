//
//  SearchView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct SearchView: View {
    @StateObject private var vm = SearchViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 12) {

            // Header
            HStack {
                Text("Browse")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                Text("UniMarket")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            // Search bar + icons
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search items...", text: $vm.query)
                }
                .padding(12)
                .background(Color.gray.opacity(0.12))
                .cornerRadius(16)

                Button {} label: {
                    Image(systemName: "camera")
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)

                Button {} label: {
                    Image(systemName: "slider.horizontal.3")
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            // Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(vm.filteredProducts) { product in
                        ProductGridCard(product: product) {
                            vm.toggleFavorite(for: product)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 80) // espacio para tu tab bar custom
            }
        }
    }
}
