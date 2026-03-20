//
//  ProfileViewModel.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

final class ProfileViewModel: ObservableObject {
    enum MetricsRange: String, CaseIterable, Identifiable {
        case week = "Last Week"
        case month = "Last Month"
        case allTime = "All Time"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .week:
                return "Last 7 days"
            case .month:
                return "Last 30 days"
            case .allTime:
                return "All time"
            }
        }
    }

    struct ProductStats {
        let listingsCreated: Int
        let itemsSold: Int
    }

    struct ProfileMetrics {
        let activeListings: Int
        let listingsCreated: Int
        let itemsSold: Int
    }

    enum Tab: String, CaseIterable {
        case activity = "Activity Feed"
        case listings = "My Listings"
    }

    @Published var selectedTab: Tab = .activity
    @Published var currentUser: User?

    @Published var displayName: String = "Loading..."
    @Published var memberSince: String = "..."
    @Published var rating: Double = 0
    @Published var transactions: Int = 0
    @Published var xp: Int = 0
    @Published var xpToNext: Int = 100
    @Published var profilePicURL: String = ""

    @Published var ecoMessage = "Welcome! Start selling items to earn XP and unlock new levels."
    @Published var selectedMetricsRange: MetricsRange = .month

    @Published var activity: [String] = [
        "Nora liked your item \"Cream Knit Sweater\".",
        "You posted \"Vintage Levi's Denim Jacket\".",
        "Kai sent you a message about \"Canvas Tote Bag\"."
    ]

    @Published var listings: [Product] = []

    @Published var editingListing: Product? = nil

    private var cancellables = Set<AnyCancellable>()
    private var listingsListener: ListenerRegistration?

    private enum CacheKey {
        static let dynamicTransactions = "profile.dynamic.transactions"
        static let dynamicRating = "profile.dynamic.rating"
        static let dynamicXP = "profile.dynamic.xp"
        static let cachedName = "profile.cached.name"
        static let cachedProfilePic = "profile.cached.profilePic"
        static let cachedMemberSince = "profile.cached.memberSince"
        static let staticSeedUID = "profile.static.seed.uid"
    }

    init() {
        hydrateFromCache()
        setupSubscribers()
    }

    func setupSubscribers() {
        AuthService.shared.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                guard let self else { return }
                self.currentUser = user
                guard let user else { return }

                self.seedImmutableFieldsOnLoginIfNeeded(user)
                self.updateDisplayIdentityIfChanged(user)
                self.applyDynamicFields(user)
            }
            .store(in: &cancellables)
    }

    @MainActor
    func onProfileTabSelected() async {
        await AuthService.shared.fetchUser()
        guard let user = AuthService.shared.currentUser else { return }

        let levelInfo = calculateLevelInfo(xp: user.xpPoints)
        var didChange = false

        if rating != user.ratingStars {
            rating = user.ratingStars
            didChange = true
        }
        if transactions != user.numTransactions {
            transactions = user.numTransactions
            didChange = true
        }
        if xp != user.xpPoints {
            xp = user.xpPoints
            xpToNext = levelInfo.xpToNext
            updateEcoMessage(xp: user.xpPoints)
            didChange = true
        }

        let defaults = UserDefaults.standard
        if didChange {
            defaults.set(user.ratingStars, forKey: CacheKey.dynamicRating)
            defaults.set(user.numTransactions, forKey: CacheKey.dynamicTransactions)
            defaults.set(user.xpPoints, forKey: CacheKey.dynamicXP)
        }

        if defaults.string(forKey: CacheKey.cachedName) != user.displayName {
            displayName = user.displayName
            defaults.set(user.displayName, forKey: CacheKey.cachedName)
        }

        if defaults.string(forKey: CacheKey.cachedProfilePic) != user.profilePic {
            profilePicURL = user.profilePic
            defaults.set(user.profilePic, forKey: CacheKey.cachedProfilePic)
        }
    }

    private func hydrateFromCache() {
        let defaults = UserDefaults.standard

        displayName = defaults.string(forKey: CacheKey.cachedName) ?? "Loading..."
        memberSince = defaults.string(forKey: CacheKey.cachedMemberSince) ?? "..."
        profilePicURL = defaults.string(forKey: CacheKey.cachedProfilePic) ?? ""

        rating = defaults.double(forKey: CacheKey.dynamicRating)
        transactions = defaults.integer(forKey: CacheKey.dynamicTransactions)
        xp = defaults.integer(forKey: CacheKey.dynamicXP)

        let levelInfo = calculateLevelInfo(xp: xp)
        xpToNext = levelInfo.xpToNext
        updateEcoMessage(xp: xp)
    }

    private func applyDynamicFields(_ user: User) {
        let levelInfo = calculateLevelInfo(xp: user.xpPoints)
        rating = user.ratingStars
        transactions = user.numTransactions
        xp = user.xpPoints
        xpToNext = levelInfo.xpToNext

        startObservingListings(for: user.id)

        let defaults = UserDefaults.standard
        defaults.set(user.ratingStars, forKey: CacheKey.dynamicRating)
        defaults.set(user.numTransactions, forKey: CacheKey.dynamicTransactions)
        defaults.set(user.xpPoints, forKey: CacheKey.dynamicXP)

        updateEcoMessage(xp: user.xpPoints)
    }

    private func updateDisplayIdentityIfChanged(_ user: User) {
        let defaults = UserDefaults.standard

        if defaults.string(forKey: CacheKey.cachedName) != user.displayName {
            displayName = user.displayName
            defaults.set(user.displayName, forKey: CacheKey.cachedName)
        }

        if defaults.string(forKey: CacheKey.cachedProfilePic) != user.profilePic {
            profilePicURL = user.profilePic
            defaults.set(user.profilePic, forKey: CacheKey.cachedProfilePic)
        }
    }

    private func seedImmutableFieldsOnLoginIfNeeded(_ user: User) {
        let defaults = UserDefaults.standard
        let lastSeedUID = defaults.string(forKey: CacheKey.staticSeedUID)

        guard lastSeedUID != user.id else {
            if let cachedMemberSince = defaults.string(forKey: CacheKey.cachedMemberSince) {
                memberSince = cachedMemberSince
            }
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM yyyy"
        let formattedMemberSince = dateFormatter.string(from: user.createdAt)

        memberSince = formattedMemberSince

        defaults.set(formattedMemberSince, forKey: CacheKey.cachedMemberSince)
        defaults.set(user.id, forKey: CacheKey.staticSeedUID)
    }

    func calculateLevelInfo(xp: Int) -> (title: String, nextTitle: String, xpToNext: Int, minXP: Int, maxXP: Int) {
        switch xp {
        case 0..<100:
            return ("Level 1 - Newcomer", "Level 2 - Eco Learner", 100 - xp, 0, 100)
        case 100..<300:
            return ("Level 2 - Eco Learner", "Level 3 - Eco Enthusiast", 300 - xp, 100, 300)
        case 300..<600:
            return ("Level 3 - Eco Enthusiast", "Level 4 - Eco Explorer", 600 - xp, 300, 600)
        case 600..<1000:
            return ("Level 4 - Eco Explorer", "Level 5 - Sustainability Star", 1000 - xp, 600, 1000)
        default:
            return ("Level 5 - Sustainability Star", "Max Level", 0, 1000, 10000)
        }
    }

    func updateEcoMessage(xp: Int) {
        let levelInfo = calculateLevelInfo(xp: xp)
        if xp >= 1000 {
            ecoMessage = "You're a Sustainability Star! You've reached the top level. Keep leading the way!"
        } else {
            ecoMessage = "You're just \(levelInfo.xpToNext) XP away from \(levelInfo.nextTitle). Keep it up to unlock new badges and rewards!"
        }
    }

    private func versionedProfileImageKey(from urlString: String) -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let separator = trimmed.contains("?") ? "&" : "?"
        return "\(trimmed)\(separator)v=\(Int(Date().timeIntervalSince1970))"
    }

    func uploadProfileImage(_ image: UIImage) async {
        do {
            let uploadedURL = try await ImageUploadService.uploadProfilePic(image)
            let previousCacheKey = profilePicURL

            try await AuthService.shared.updateProfileImage(withImageUrl: uploadedURL)

            if !previousCacheKey.isEmpty {
                AsyncImageView.invalidateCache(for: previousCacheKey)
            }
            AsyncImageView.invalidateCache(for: uploadedURL)

            let versionedURL = versionedProfileImageKey(from: uploadedURL)
            profilePicURL = versionedURL
            UserDefaults.standard.set(versionedURL, forKey: CacheKey.cachedProfilePic)
        } catch {
            print("DEBUG: Failed to upload profile image with error \(error.localizedDescription)")
        }
    }

    func deleteProfileImage() async {
        do {
            let previousCacheKey = profilePicURL
            try await AuthService.shared.updateProfileImage(withImageUrl: "")

            if !previousCacheKey.isEmpty {
                AsyncImageView.invalidateCache(for: previousCacheKey)
            }

            profilePicURL = ""
            UserDefaults.standard.set("", forKey: CacheKey.cachedProfilePic)
        } catch {
            print("DEBUG: Failed to delete profile image with error \(error.localizedDescription)")
        }
    }

    private func cutoffDate(for range: MetricsRange) -> Date? {
        let calendar = Calendar.current
        switch range {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: .now)
        case .month:
            return calendar.date(byAdding: .day, value: -30, to: .now)
        case .allTime:
            return nil
        }
    }

    func productStats(for range: MetricsRange) -> ProductStats {
        let cutoffDate = cutoffDate(for: range)
        let listingsCreated = listings.filter { product in
            guard let cutoffDate else { return true }
            return product.createdAt >= cutoffDate
        }.count
        let itemsSold = listings.filter { product in
            guard let soldAt = product.soldAt else { return false }
            guard let cutoffDate else { return true }
            return soldAt >= cutoffDate
        }.count

        return ProductStats(
            listingsCreated: listingsCreated,
            itemsSold: itemsSold
        )
    }

    var profileMetrics: ProfileMetrics {
        let stats = productStats(for: selectedMetricsRange)
        return ProfileMetrics(
            activeListings: listings.filter { $0.status == .active }.count,
            listingsCreated: stats.listingsCreated,
            itemsSold: stats.itemsSold
        )
    }

    var selectedMetricsRangeLabel: String {
        selectedMetricsRange.label
    }

    private func startObservingListings(for userID: String) {
        listingsListener?.remove()
        listingsListener = ProductService.shared.observeProducts { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let products):
                    self.listings = products
                        .filter { $0.sellerId == userID }
                        .sorted { $0.createdAt > $1.createdAt }
                case .failure:
                    self.listings = []
                }
            }
        }
    }

    func deleteListing(_ product: Product) {
        listings.removeAll { $0.id == product.id }
    }

    func openEdit(_ product: Product) {
        editingListing = product
    }

    func saveEdits(_ updated: Product) {
        guard let idx = listings.firstIndex(where: { $0.id == updated.id }) else { return }
        listings[idx] = updated
        editingListing = nil
    }

    deinit {
        listingsListener?.remove()
    }
}
//#Preview {
//    ProfileView()
//        .environmentObject(SessionManager())
//}
