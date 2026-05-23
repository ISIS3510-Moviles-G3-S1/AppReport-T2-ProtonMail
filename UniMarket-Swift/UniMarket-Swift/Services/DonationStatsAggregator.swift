import Foundation

actor DonationStatsAggregator {
    static let shared = DonationStatsAggregator()

    private var pendingRequestCounts: [String: Int] = [:]

    func increment(for listingID: String) {
        pendingRequestCounts[listingID, default: 0] += 1
    }

    func decrement(for listingID: String) {
        if let current = pendingRequestCounts[listingID], current > 0 {
            pendingRequestCounts[listingID] = current - 1
        }
    }

    func count(for listingID: String) -> Int {
        pendingRequestCounts[listingID] ?? 0
    }

    func reset(for listingID: String) {
        pendingRequestCounts.removeValue(forKey: listingID)
    }

    func resetAll() {
        pendingRequestCounts.removeAll()
    }
}
