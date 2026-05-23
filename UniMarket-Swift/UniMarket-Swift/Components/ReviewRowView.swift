//
//  ReviewRowView.swift
//  UniMarket-Swift
//
//  Single row in the SellerReviewsView list.
//  Displays star badge, reviewer name, formatted date, and review text.
//  An orange dot appears when the record is queued but not yet synced.
//

import SwiftUI

struct ReviewRowView: View {
    let review: ReviewRecord

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // ── Header row ──────────────────────────────────────────────
            HStack(alignment: .center, spacing: 8) {
                // Star badge
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { index in
                        Image(systemName: index <= review.starRating ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundStyle(
                                index <= review.starRating ? AppTheme.accent : AppTheme.borderColor
                            )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.accentAlt.opacity(0.25))
                .clipShape(Capsule())

                Text(review.reviewerDisplayName)
                    .font(.poppinsSemiBold(14))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)

                Spacer()

                // Pending-sync indicator
                if !review.isSynced {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Text(Self.dateFormatter.string(from: review.createdAt))
                    .font(.poppinsRegular(12))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            // ── Review text ─────────────────────────────────────────────
            Text(review.reviewText)
                .font(.poppinsRegular(14))
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.borderColor, lineWidth: 0.5)
        )
    }
}
