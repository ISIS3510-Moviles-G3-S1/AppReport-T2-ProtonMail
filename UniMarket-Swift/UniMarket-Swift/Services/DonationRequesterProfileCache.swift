import Foundation

final class CachedDonationRequester {
    let uid: String
    let displayName: String
    let profilePicURL: String?

    init(uid: String, displayName: String, profilePicURL: String?) {
        self.uid = uid
        self.displayName = displayName
        self.profilePicURL = profilePicURL
    }
}

/// NSCache-backed profile cache for donation request senders.
/// countLimit=100, totalCostLimit=128 KB, soft TTL=600s checked at lookup.
/// Mirrors UserProfileCache; cleared on sign-out via NotificationCenter.
final class DonationRequesterProfileCache {
    static let shared = DonationRequesterProfileCache()

    private let cache = NSCache<NSString, CachedDonationRequester>()
    private let ttl: TimeInterval = 600
    private var expirationTimes: [String: Date] = [:]
    private let lock = NSLock()
    private var notificationToken: NSObjectProtocol?

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 128 * 1024

        notificationToken = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("userDidSignOut"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clear()
        }
    }

    func get(uid: String) -> CachedDonationRequester? {
        lock.lock()
        defer { lock.unlock() }

        guard let cached = cache.object(forKey: uid as NSString) else { return nil }
        if let expiration = expirationTimes[uid], Date() > expiration {
            cache.removeObject(forKey: uid as NSString)
            expirationTimes.removeValue(forKey: uid)
            return nil
        }
        return cached
    }

    func set(_ requester: CachedDonationRequester, for uid: String) {
        lock.lock()
        defer { lock.unlock() }
        let cost = requester.displayName.utf8.count + (requester.profilePicURL?.utf8.count ?? 0) + 32
        cache.setObject(requester, forKey: uid as NSString, cost: cost)
        expirationTimes[uid] = Date().addingTimeInterval(ttl)
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAllObjects()
        expirationTimes.removeAll()
    }

    deinit {
        if let token = notificationToken {
            NotificationCenter.default.removeObserver(token)
        }
    }
}
