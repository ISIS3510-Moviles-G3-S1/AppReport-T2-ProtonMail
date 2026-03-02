//
//  ListingsList.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct ListingsList: View {
    let listings: [Listing]
    let onEdit: (Listing) -> Void
    let onDelete: (Listing) -> Void

    var body: some View {
        VStack(spacing: 14) {
            ForEach(listings) { listing in
                ListingCard(
                    listing: listing,
                    onEdit: { onEdit(listing) },
                    onDelete: { onDelete(listing) }
                )
            }
        }
        .padding(.top, 8)
    }
}
