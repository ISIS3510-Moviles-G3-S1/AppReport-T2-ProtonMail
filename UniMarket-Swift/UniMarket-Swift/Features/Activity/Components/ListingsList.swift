//
//  ListingsList.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct ListingsList: View {
    let listings: [Listing]
    let onDelete: (Listing) -> Void
    let onTapDetail: (Listing) -> Void

    var body: some View {
        VStack(spacing: 14) {
            ForEach(listings) { listing in
                ListingCard(
                    listing: listing,
                    onDelete: { onDelete(listing) },
                    onTapDetail: { onTapDetail(listing) }
                )
            }
        }
        .padding(.top, 8)
    }
}
