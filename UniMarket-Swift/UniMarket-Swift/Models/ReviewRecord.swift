//
//  ReviewRecord.swift
//  UniMarket-Swift
//
//  SwiftData model for seller reviews.
//  Stored in UniMarket-Reviews.store (applicationSupportDirectory).
//  isSynced = false means the record is pending a Firestore push;
//  PendingReviewsSyncer drains these on reconnect.
//

import Foundation
import SwiftData

@Model
final class ReviewRecord {
    @Attribute(.unique) var id: String
    var sellerID: String
    var reviewerID: String
    var reviewerDisplayName: String
    /// Star rating in the range 1–5.
    var starRating: Int
    var reviewText: String
    var createdAt: Date
    /// Optional — populated when the review is left from a ProductDetailView.
    var productID: String?
    /// false until the record has been successfully pushed to Firestore.
    var isSynced: Bool

    /// Replies to this review. Cascade-deleted with the parent.
    @Relationship(deleteRule: .cascade) var replies: [ReviewReplyRecord]

    init(
        id: String,
        sellerID: String,
        reviewerID: String,
        reviewerDisplayName: String,
        starRating: Int,
        reviewText: String,
        createdAt: Date,
        productID: String?,
        isSynced: Bool
    ) {
        self.id = id
        self.sellerID = sellerID
        self.reviewerID = reviewerID
        self.reviewerDisplayName = reviewerDisplayName
        self.starRating = starRating
        self.reviewText = reviewText
        self.createdAt = createdAt
        self.productID = productID
        self.isSynced = isSynced
        self.replies = []
    }
}
