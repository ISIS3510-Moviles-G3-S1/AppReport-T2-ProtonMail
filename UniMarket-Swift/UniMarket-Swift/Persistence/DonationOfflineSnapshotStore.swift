import Foundation

// Declared at file scope so their Codable synthesis is nonisolated.
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

struct DonationListingSnapshot: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let imageURL: String?
    let categoryTag: String
    let sellerName: String
    let createdAt: Date
}

final class DonationOfflineSnapshotStore {
    static let shared = DonationOfflineSnapshotStore()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "com.unimarket.donations.snapshot")

    private var snapshotURL: URL {
        let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let donationsDir = supportDir.appendingPathComponent("Donations", isDirectory: true)
        try? fileManager.createDirectory(at: donationsDir, withIntermediateDirectories: true)
        return donationsDir.appendingPathComponent("donations_browse_snapshot.json")
    }

    // Nested typealiases so callsites using the old nested path still work.
    typealias DonationSnapshot = UniMarket_Swift.DonationSnapshot
    typealias DonationListingSnapshot = UniMarket_Swift.DonationListingSnapshot

    func persist(_ listings: [Product]) {
        queue.async { [weak self] in
            guard let self else { return }
            let snapshots = listings.map { product -> DonationListingSnapshot in
                DonationListingSnapshot(
                    id: product.id,
                    title: product.title,
                    imageURL: product.primaryImageURL,
                    categoryTag: product.tags.first ?? "uncategorized",
                    sellerName: product.sellerName,
                    createdAt: product.createdAt
                )
            }
            let snapshot = DonationSnapshot(listings: snapshots, fetchedAt: .now)
            do {
                let data = try self.encoder.encode(snapshot)
                try data.write(to: self.snapshotURL, options: .atomic)
            } catch {
                print("[DonationOfflineSnapshotStore] Failed to persist snapshot: \(error)")
            }
        }
    }

    func load() -> DonationSnapshot? {
        var snapshot: DonationSnapshot?
        queue.sync {
            do {
                let data = try Data(contentsOf: snapshotURL)
                snapshot = try decoder.decode(DonationSnapshot.self, from: data)
            } catch {
                print("[DonationOfflineSnapshotStore] Failed to load snapshot: \(error)")
            }
        }
        return snapshot
    }

    func clear() {
        queue.async { [weak self] in
            try? self?.fileManager.removeItem(at: self?.snapshotURL ?? URL(fileURLWithPath: ""))
        }
    }
}
