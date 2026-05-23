import Foundation

// Listing the user submitted but hasn't reached Firestore yet.
// See EvCon.md §1 for the on-disk layout and image-sidecar rationale.
struct PendingListing: Codable, Equatable, Identifiable {
    var id: String { pendingID }

    let pendingID: String
    let userID: String
    var title: String
    var price: Int
    var conditionTag: String
    var listingDescription: String
    var tags: [String]
    var imageCount: Int
    let queuedAt: Date
    var lastTriedAt: Date?
    var retryCount: Int
    var lastError: String?
    /// "sale" | "donation" | "barter". Stored as raw string for forward-compat.
    /// Older queue entries lacking this field decode as "sale".
    var kindRaw: String = "sale"

    enum CodingKeys: String, CodingKey {
        case pendingID, userID, title, price, conditionTag, listingDescription
        case tags, imageCount, queuedAt, lastTriedAt, retryCount, lastError, kindRaw
    }

    init(
        pendingID: String,
        userID: String,
        title: String,
        price: Int,
        conditionTag: String,
        listingDescription: String,
        tags: [String],
        imageCount: Int,
        queuedAt: Date,
        lastTriedAt: Date?,
        retryCount: Int,
        lastError: String?,
        kindRaw: String = "sale"
    ) {
        self.pendingID = pendingID
        self.userID = userID
        self.title = title
        self.price = price
        self.conditionTag = conditionTag
        self.listingDescription = listingDescription
        self.tags = tags
        self.imageCount = imageCount
        self.queuedAt = queuedAt
        self.lastTriedAt = lastTriedAt
        self.retryCount = retryCount
        self.lastError = lastError
        self.kindRaw = kindRaw
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pendingID = try c.decode(String.self, forKey: .pendingID)
        userID = try c.decode(String.self, forKey: .userID)
        title = try c.decode(String.self, forKey: .title)
        price = try c.decode(Int.self, forKey: .price)
        conditionTag = try c.decode(String.self, forKey: .conditionTag)
        listingDescription = try c.decode(String.self, forKey: .listingDescription)
        tags = try c.decode([String].self, forKey: .tags)
        imageCount = try c.decode(Int.self, forKey: .imageCount)
        queuedAt = try c.decode(Date.self, forKey: .queuedAt)
        lastTriedAt = try c.decodeIfPresent(Date.self, forKey: .lastTriedAt)
        retryCount = try c.decode(Int.self, forKey: .retryCount)
        lastError = try c.decodeIfPresent(String.self, forKey: .lastError)
        kindRaw = try c.decodeIfPresent(String.self, forKey: .kindRaw) ?? "sale"
    }
}
