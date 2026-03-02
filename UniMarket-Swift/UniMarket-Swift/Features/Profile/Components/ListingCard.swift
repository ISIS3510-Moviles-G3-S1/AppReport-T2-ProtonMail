//
//  ListingCard.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct ListingCard: View {
    let listing: Listing
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 180)
                    .overlay(
                        Image(systemName: listing.imageName)
                            .font(.system(size: 44))
                            .foregroundColor(.gray.opacity(0.6))
                    )

                Text(listing.status.rawValue)
                    .font(.caption2).bold()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(badgeColor(listing.status).opacity(0.35))
                    .cornerRadius(14)
                    .padding(10)
            }

            Text(listing.title)
                .font(.headline)
                .lineLimit(2)

            Text("$\(listing.price)")
                .font(.headline)
                .foregroundColor(.green)

            HStack(spacing: 10) {
                Button(action: onEdit) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.12))
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.background)
                .shadow(radius: 6)
        )
    }

    private func badgeColor(_ status: ListingStatus) -> Color {
        switch status {
        case .active: return .green
        case .paused: return .orange
        case .sold: return .gray
        }
    }
}
