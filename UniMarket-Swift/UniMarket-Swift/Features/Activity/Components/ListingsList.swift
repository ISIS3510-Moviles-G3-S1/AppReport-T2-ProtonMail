//
//  ListingsList.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct ListingsList: View {
    let listings: [Product]
    let onDelete: (Product) -> Void
    let onTapDetail: (Product) -> Void

    var body: some View {
        VStack(spacing: 14) {
            ForEach(listings) { product in
                ListingCard(
                    product: product,
                    onDelete: { onDelete(product) },
                    onTapDetail: { onTapDetail(product) }
                )
            }
        }
        .padding(.top, 8)
    }
}
