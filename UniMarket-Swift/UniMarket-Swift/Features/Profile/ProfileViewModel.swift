//
//  ProfileViewModel.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI
import Combine
import FirebaseFirestore

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
    
    // Derived UI Model
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
    
    // Mock Data - TODO: Replace with real db collection for activities
    @Published var activity: [String] = [
        "Nora liked your item “Cream Knit Sweater”.",
        "You posted “Vintage Levi’s Denim Jacket”.",
        "Kai sent you a message about “Canvas Tote Bag”."
    ]
    
    @Published var listings: [Product] = [
        Product(
            id: "1",
            title: "Vintage Levi’s Denim Jacket",
            price: 25,
            sellerName: "Alex López",
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
            sellerName: "Alex López",
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
            sellerName: "Alex López",
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
    
    init() {
        setupSubscribers()
    }
    
    func setupSubscribers() {
        AuthService.shared.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.currentUser = user
                if let user = user {
                    self?.mapUserToProfile(user)
                    self?.updateEcoMessage(xp: user.xpPoints)
                }
            }
            .store(in: &cancellables)
    }
    
    func mapUserToProfile(_ user: User) {
        let levelInfo = calculateLevelInfo(xp: user.xpPoints)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM yyyy"
        let memberSince = dateFormatter.string(from: user.createdAt)
        
        // Extract university from email if possible, else generic
        let university = user.email.split(separator: "@").last.map { String($0) } ?? "UniMarket University"
        
        self.profile = UserProfile(
            name: user.displayName,
            university: university,
            memberSince: memberSince,
            rating: user.ratingStars,
            transactions: user.numTransactions,
            xp: user.xpPoints,
            levelTitle: levelInfo.title,
            nextLevelTitle: levelInfo.nextTitle,
            xpToNext: levelInfo.xpToNext,
            levelMinXP: levelInfo.minXP,
            levelMaxXP: levelInfo.maxXP,
            profilePicURL: user.profilePic
        )
    }
    
    func calculateLevelInfo(xp: Int) -> (title: String, nextTitle: String, xpToNext: Int, minXP: Int, maxXP: Int) {
        // Sustainability Levels Logic
        // Level 1: 0-100 (Newcomer)
        // Level 2: 101-300 (Eco Learner)
        // Level 3: 301-600 (Eco Enthusiast)
        // Level 4: 601-1000 (Eco Explorer)
        // Level 5: 1001+ (Sustainability Star)
        
        switch xp {
        case 0..<100:
            return ("Level 1 – Newcomer", "Level 2 – Eco Learner", 100 - xp, 0, 100)
        case 100..<300:
            return ("Level 2 – Eco Learner", "Level 3 – Eco Enthusiast", 300 - xp, 100, 300)
        case 300..<600:
            return ("Level 3 – Eco Enthusiast", "Level 4 – Eco Explorer", 600 - xp, 300, 600)
        case 600..<1000:
            return ("Level 4 – Eco Explorer", "Level 5 – Sustainability Star", 1000 - xp, 600, 1000)
        default:
            return ("Level 5 – Sustainability Star", "Max Level", 0, 1000, 10000)
        }
    }
    
    func updateEcoMessage(xp: Int) {
        let levelInfo = calculateLevelInfo(xp: xp)
        if xp >= 1000 {
            self.ecoMessage = "You're a Sustainability Star! You've reached the top level. Keep leading the way!"
        } else {
            self.ecoMessage = "You're just \(levelInfo.xpToNext) XP away from \(levelInfo.nextTitle). Keep it up to unlock new badges and rewards!"
        }
    }
    
    func uploadProfileImage(_ image: UIImage) async {
        do {
            let url = try await ImageUploadService.uploadProfilePic(image)
            try await AuthService.shared.updateProfileImage(withImageUrl: url)
        } catch {
            print("DEBUG: Failed to upload profile image with error \(error.localizedDescription)")
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
