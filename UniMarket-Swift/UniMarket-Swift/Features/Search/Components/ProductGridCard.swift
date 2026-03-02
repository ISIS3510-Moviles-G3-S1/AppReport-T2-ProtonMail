//
//  ProductGridCard.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct ProductGridCard: View {
    let product: Product
    let onTapFavorite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 180)
                    .overlay(
                        Image(systemName: product.imageName)
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.6))
                    )

                // Tag condición
                Text(product.conditionTag)
                    .font(.caption2).bold()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(14)
                    .padding(10)

                // Corazón
                HStack {
                    Spacer()
                    Button(action: onTapFavorite) {
                        Image(systemName: product.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(10)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
            }

            Text(product.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)

            HStack {
                Text("$\(product.price)")
                    .fontWeight(.bold)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                    Text(String(format: "%.1f", product.rating))
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            Text(product.sellerName)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(radius: 4)
    }
}
