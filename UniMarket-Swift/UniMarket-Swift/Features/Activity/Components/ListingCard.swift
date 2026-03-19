//
//  ListingCard.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct ListingCard: View {
    let product: Product
    let onDelete: () -> Void
    let onTapDetail: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onTapDetail) {
                VStack(alignment: .leading, spacing: 10) {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(AppTheme.background)
                            .frame(height: 180)
                            .overlay(productImage)

                        Text(product.status.rawValue)
                            .font(.poppinsSemiBold(10))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(badgeColor(product.status).opacity(0.35))
                            .clipShape(Capsule())
                            .padding(10)
                    }

                    Text(product.title)
                        .font(.poppinsSemiBold(16))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(2)

                    Text("$\(product.price)")
                        .font(.poppinsSemiBold(16))
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete")
                        .font(.poppinsSemiBold(14))
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white)
                .shadow(color: .black.opacity(0.08), radius: 6)
        )
    }

    private func badgeColor(_ status: ProductStatus) -> Color {
        switch status {
        case .active: return AppTheme.accent
        case .paused: return .orange
        case .sold: return .gray
        }
    }

    @ViewBuilder
    private var productImage: some View {
        if let imageURL = product.primaryImageURL, !imageURL.isEmpty {
            AsyncImageView(urlString: imageURL, cacheKey: imageURL)
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18))
        } else {
            Image(product.imageName)
                .resizable()
                .font(.poppinsSemiBold(44))
                .foregroundStyle(AppTheme.secondaryText)
                .scaledToFit()
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}
