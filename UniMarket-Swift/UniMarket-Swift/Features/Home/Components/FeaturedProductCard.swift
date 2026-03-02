//
//  FeaturedProductCard.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct FeaturedProductCard: View {
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

            VStack(alignment: .trailing, spacing: 2) {
                Text("$18")
                    .font(.poppinsBold(34))
                    .foregroundStyle(.black)

                Text("Like New ✓")
                    .font(.poppinsSemiBold(14))
                    .foregroundStyle(.black.opacity(0.9))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(14)
        }
    }
}
