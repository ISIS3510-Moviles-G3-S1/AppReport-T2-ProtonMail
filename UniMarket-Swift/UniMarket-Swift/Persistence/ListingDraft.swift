import Foundation

nonisolated struct ListingDraft: Codable, Equatable, Identifiable, Sendable {
    var id: String { draftID }

    let draftID: String
    let userID: String
    var title: String
    var priceText: String
    var conditionTag: String
    var listingDescription: String
    var tags: [String]
    var imageCount: Int
    var savedAt: Date
}

struct ListingDraftPayload: Sendable {
    let draft: ListingDraft
    let imagesData: [Data]
}
