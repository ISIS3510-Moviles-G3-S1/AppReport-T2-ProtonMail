//
//  ReviewReplyRecord.swift
//  UniMarket-Swift
//
//  SwiftData model for replies to seller reviews.
//  The inverse relationship on ReviewRecord.replies ensures SwiftData
//  maintains referential integrity in both directions.
//

import Foundation
import SwiftData

@Model
final class ReviewReplyRecord {
    @Attribute(.unique) var id: String
    /// The ID of the parent ReviewRecord (denormalised for offline queries).
    var reviewID: String
    var replierID: String
    var replyText: String
    var createdAt: Date
    /// false until the record has been successfully pushed to Firestore.
    var isSynced: Bool

    /// Back-pointer to the parent review.
    @Relationship(inverse: \ReviewRecord.replies) var review: ReviewRecord?

    init(
        id: String,
        reviewID: String,
        replierID: String,
        replyText: String,
        createdAt: Date,
        isSynced: Bool
    ) {
        self.id = id
        self.reviewID = reviewID
        self.replierID = replierID
        self.replyText = replyText
        self.createdAt = createdAt
        self.isSynced = isSynced
    }
}
