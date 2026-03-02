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

            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.15))
                .frame(height: 300)

            VStack(alignment: .trailing, spacing: 4) {
                Text("$18")
                    .bold()
                Text("Like New ✓")
                    .font(.caption)
            }
            .padding()
            .background(Color.green.opacity(0.7))
            .cornerRadius(12)
            .padding()
        }
    }
}
