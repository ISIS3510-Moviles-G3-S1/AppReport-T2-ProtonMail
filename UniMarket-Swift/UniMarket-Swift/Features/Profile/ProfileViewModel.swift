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
    struct MonthlyProductStats {
        let listingsCreated: Int
        let itemsSold: Int
    }

    enum Tab: String, CaseIterable {
        case activity = "Activity Feed"
        case listings = "My Listings"
    }

    @Published var selectedTab: Tab = .activity
    @Published var currentUser: User?

    @Published var profile: UserProfile = UserProfile(
        name: "Loading...",
        university: "UniMarket Member",
        memberSince: "...",
        rating: 0,
        transactions: 0,
        xp: 0,
        levelTitle: "Level 1",
        nextLevelTitle: "Level 2",
        xpToNext: 100,
        levelMinXP: 0,
        levelMaxXP: 100,
        profilePicURL: ""
    )

    @Published var ecoMessage = "Welcome! Start selling items to earn XP and unlock new levels."

    @Published var activity: [String] = [
        "Nora liked your item \"Cream Knit Sweater\".",
        "You posted \"Vintage Levi's Denim Jacket\".",
        "Kai sent you a message about \"Canvas Tote Bag\"."
    ]

    @Published var listings: [Product] = [
        Product(
            id: "1",
            title: "Vintage Levi's Denim Jacket",
            price: 25,
            sellerName: "Alex Lopez",
            conditionTag: "Good",
            tags: ["outerwear", "denim"],
            imageName: "jacket",
            description: "Classic denim jacket in great condition.",
            createdAt: Calendar.current.date(byAdding: .day, value: -8, to: .now) ?? .now,
            status: .active
        ),
        Product(
            id: "2",
            title: "Cream Knit Sweater",
            price: 20,
            sellerName: "Alex Lopez",
            conditionTag: "Good",
            tags: ["knitwear"],
            imageName: "tshirt",
            description: "Soft sweater with a relaxed fit.",
            createdAt: Calendar.current.date(byAdding: .day, value: -20, to: .now) ?? .now,
            soldAt: Calendar.current.date(byAdding: .day, value: -4, to: .now),
            status: .sold
        ),
        Product(
            id: "3",
            title: "Canvas Tote Bag",
            price: 12,
            sellerName: "Alex Lopez",
            conditionTag: "Like New",
            tags: ["bags"],
            imageName: "bag",
            description: "Large tote bag with plenty of room.",
            createdAt: Calendar.current.date(byAdding: .day, value: -45, to: .now) ?? .now,
            status: .paused
        )
    ]

    @Published var editingListing: Product? = nil

    private var cancellables = Set<AnyCancellable>()

    private enum CacheKey {
        static let dynamicTransactions = "profile.dynamic.transactions"
        static let dynamicRating = "profile.dynamic.rating"
        static let dynamicXP = "profile.dynamic.xp"
        static let cachedName = "profile.cached.name"
        static let cachedProfilePic = "profile.cached.profilePic"
        static let cachedUniversity = "profile.cached.university"
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

        if profile.rating != user.ratingStars {
            profile.rating = user.ratingStars
            didChange = true
        }
        if profile.transactions != user.numTransactions {
            profile.transactions = user.numTransactions
            didChange = true
        }
        if profile.xp != user.xpPoints {
            profile.xp = user.xpPoints
            profile.levelTitle = levelInfo.title
            profile.nextLevelTitle = levelInfo.nextTitle
            profile.xpToNext = levelInfo.xpToNext
            profile.levelMinXP = levelInfo.minXP
            profile.levelMaxXP = levelInfo.maxXP
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
            profile.name = user.displayName
            defaults.set(user.displayName, forKey: CacheKey.cachedName)
        }

        if defaults.string(forKey: CacheKey.cachedProfilePic) != user.profilePic {
            profile.profilePicURL = user.profilePic
            defaults.set(user.profilePic, forKey: CacheKey.cachedProfilePic)
        }
    }

    private func hydrateFromCache() {
        let defaults = UserDefaults.standard

        let cachedName = defaults.string(forKey: CacheKey.cachedName) ?? "Loading..."
        let cachedUniversity = defaults.string(forKey: CacheKey.cachedUniversity) ?? "UniMarket Member"
        let cachedMemberSince = defaults.string(forKey: CacheKey.cachedMemberSince) ?? "..."
        let cachedProfilePic = defaults.string(forKey: CacheKey.cachedProfilePic) ?? ""

        let cachedRating = defaults.double(forKey: CacheKey.dynamicRating)
        let cachedTransactions = defaults.integer(forKey: CacheKey.dynamicTransactions)
        let cachedXP = defaults.integer(forKey: CacheKey.dynamicXP)

        let levelInfo = calculateLevelInfo(xp: cachedXP)
        profile = UserProfile(
            name: cachedName,
            university: cachedUniversity,
            memberSince: cachedMemberSince,
            rating: cachedRating,
            transactions: cachedTransactions,
            xp: cachedXP,
            levelTitle: levelInfo.title,
            nextLevelTitle: levelInfo.nextTitle,
            xpToNext: levelInfo.xpToNext,
            levelMinXP: levelInfo.minXP,
            levelMaxXP: levelInfo.maxXP,
            profilePicURL: cachedProfilePic
        )
        updateEcoMessage(xp: cachedXP)
    }

    private func applyDynamicFields(_ user: User) {
        let levelInfo = calculateLevelInfo(xp: user.xpPoints)
        profile.rating = user.ratingStars
        profile.transactions = user.numTransactions
        profile.xp = user.xpPoints
        profile.levelTitle = levelInfo.title
        profile.nextLevelTitle = levelInfo.nextTitle
        profile.xpToNext = levelInfo.xpToNext
        profile.levelMinXP = levelInfo.minXP
        profile.levelMaxXP = levelInfo.maxXP

        let defaults = UserDefaults.standard
        defaults.set(user.ratingStars, forKey: CacheKey.dynamicRating)
        defaults.set(user.numTransactions, forKey: CacheKey.dynamicTransactions)
        defaults.set(user.xpPoints, forKey: CacheKey.dynamicXP)

        updateEcoMessage(xp: user.xpPoints)
    }

    private func updateDisplayIdentityIfChanged(_ user: User) {
        let defaults = UserDefaults.standard

        if defaults.string(forKey: CacheKey.cachedName) != user.displayName {
            profile.name = user.displayName
            defaults.set(user.displayName, forKey: CacheKey.cachedName)
        }

        if defaults.string(forKey: CacheKey.cachedProfilePic) != user.profilePic {
            profile.profilePicURL = user.profilePic
            defaults.set(user.profilePic, forKey: CacheKey.cachedProfilePic)
        }
    }

    private func seedImmutableFieldsOnLoginIfNeeded(_ user: User) {
        let defaults = UserDefaults.standard
        let lastSeedUID = defaults.string(forKey: CacheKey.staticSeedUID)

        guard lastSeedUID != user.id else {
            if let university = defaults.string(forKey: CacheKey.cachedUniversity) {
                profile.university = university
            }
            if let memberSince = defaults.string(forKey: CacheKey.cachedMemberSince) {
                profile.memberSince = memberSince
            }
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM yyyy"
        let memberSince = dateFormatter.string(from: user.createdAt)
        let university = user.email.split(separator: "@").last.map(String.init) ?? "UniMarket University"

        profile.university = university
        profile.memberSince = memberSince

        defaults.set(university, forKey: CacheKey.cachedUniversity)
        defaults.set(memberSince, forKey: CacheKey.cachedMemberSince)
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
            let previousCacheKey = profile.profilePicURL

            try await AuthService.shared.updateProfileImage(withImageUrl: uploadedURL)

            if !previousCacheKey.isEmpty {
                AsyncImageView.invalidateCache(for: previousCacheKey)
            }
            AsyncImageView.invalidateCache(for: uploadedURL)

            let versionedURL = versionedProfileImageKey(from: uploadedURL)
            profile.profilePicURL = versionedURL
            UserDefaults.standard.set(versionedURL, forKey: CacheKey.cachedProfilePic)
        } catch {
            print("DEBUG: Failed to upload profile image with error \(error.localizedDescription)")
        }
    }

    func deleteProfileImage() async {
        do {
            let previousCacheKey = profile.profilePicURL
            try await AuthService.shared.updateProfileImage(withImageUrl: "")

            if !previousCacheKey.isEmpty {
                AsyncImageView.invalidateCache(for: previousCacheKey)
            }

            profile.profilePicURL = ""
            UserDefaults.standard.set("", forKey: CacheKey.cachedProfilePic)
        } catch {
            print("DEBUG: Failed to delete profile image with error \(error.localizedDescription)")
        }
    }

    var monthlyProductStats: MonthlyProductStats {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .month, value: -1, to: .now) ?? .now

        let listingsCreated = listings.filter { $0.createdAt >= cutoffDate }.count
        let itemsSold = listings.filter { product in
            guard let soldAt = product.soldAt else { return false }
            return soldAt >= cutoffDate
        }.count

        return MonthlyProductStats(
            listingsCreated: listingsCreated,
            itemsSold: itemsSold
        )
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
}
//#Preview {
//    ProfileView()
//        .environmentObject(SessionManager())
//}
