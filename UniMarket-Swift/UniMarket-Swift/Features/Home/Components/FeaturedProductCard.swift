//
//  FeaturedProductCard.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct FeaturedProductCard: View {
    let product: Product?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white)
                .frame(height: 320)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(AppTheme.background)
                        .padding(2)
                )

            featuredImage

            if let product {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(product.price)")
                        .font(.poppinsBold(34))
                        .foregroundStyle(.black)

                    Text("\(product.conditionTag) ✓")
                        .font(.poppinsSemiBold(14))
                        .foregroundStyle(.black.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.accentAlt)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(14)
            }
        }
    }

    @ViewBuilder
    private var featuredImage: some View {
        if let product {
            if let imageURL = product.primaryImageURL, !imageURL.isEmpty {
                AsyncImageView(urlString: imageURL, cacheKey: imageURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.poppinsSemiBold(36))
                        .foregroundStyle(AppTheme.secondaryText)
                    Text("No image available")
                        .font(.poppinsRegular(13))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                Text("Your newest listing will appear here.")
                    .font(.poppinsRegular(15))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }
}
