import Foundation

struct DonationListingSnapshot: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let imageURL: String?
    let categoryTag: String
    let sellerName: String
    let createdAt: Date
}

struct DonationSnapshot: Codable, Sendable {
    let listings: [DonationListingSnapshot]
    let fetchedAt: Date

    var timeSinceFetch: String {
        let interval = Date.now.timeIntervalSince(fetchedAt)
        let minutes = Int(interval) / 60
        let hours = minutes / 60
        let days = hours / 24
        if days > 0 { return "\(days)d ago" }
        if hours > 0 { return "\(hours)h ago" }
        if minutes > 0 { return "\(minutes)m ago" }
        return "now"
    }
}

/// Tiny JSON snapshot of donation listings for offline browsing.
/// I/O is synchronous — the payload is small and callers are already on the main actor.
enum DonationOfflineSnapshotStore {
    private static var snapshotURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Donations", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("donations_browse_snapshot.json")
    }

    static func persist(_ listings: [Product]) {
        let snaps = listings.map {
            DonationListingSnapshot(
                id: $0.id,
                title: $0.title,
                imageURL: $0.primaryImageURL,
                categoryTag: $0.tags.first ?? "uncategorized",
                sellerName: $0.sellerName,
                createdAt: $0.createdAt
            )
        }
        let snapshot = DonationSnapshot(listings: snaps, fetchedAt: .now)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: snapshotURL, options: .atomic)
    }

    static func load() -> DonationSnapshot? {
        guard let data = try? Data(contentsOf: snapshotURL) else { return nil }
        return try? JSONDecoder().decode(DonationSnapshot.self, from: data)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: snapshotURL)
    }
}
