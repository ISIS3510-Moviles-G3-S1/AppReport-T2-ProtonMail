//
//  UniMarket_SwiftApp.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI
import UIKit
import FirebaseCore
import UserNotifications
import SwiftData

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        AnalyticsService.shared.track(.appOpened())
        
        // Firebase Auth persistence is .local by default — the session is stored
        // in the device keychain and survives app restarts, so users won't be
        // forced to log in every time. To change this behaviour:
        //   .local   → persists across restarts (default, recommended)
        //   .session → clears on app termination (like an incognito session)
        //   .none    → never persists (user must log in every launch)
        // Auth.auth().setPersistence(.local) { ... } ← only needed if overriding
        return true
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}

@main
struct UniMarket_SwiftApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var session = SessionManager.shared
    @StateObject private var chatStore = ChatStore()
    @StateObject private var productStore = ProductStore()
    @StateObject private var cartStore = CartStore()

    // MARK: - Reviews ModelContainer
    //
    // Stored in applicationSupportDirectory/UniMarket-Reviews.store.
    // CloudKit is disabled — reviews are synced manually via Firestore.
    // Accessed by SellerReviewsView, ReviewsViewModel, and PendingReviewsSyncer.
    static let reviewsContainer: ModelContainer = {
        let storeURL = URL.applicationSupportDirectory
            .appendingPathComponent("UniMarket-Reviews.store")
        let config = ModelConfiguration(
            url: storeURL,
            cloudKitDatabase: .none
        )
        // Crash at launch is intentional: a migration failure here means the
        // store schema has changed without a proper migration plan.
        return try! ModelContainer(
            for: ReviewRecord.self, ReviewReplyRecord.self,
            configurations: config
        )
    }()

    // MARK: - Donations ModelContainer
    //
    // Stores DonationRequestRecord rows for offline-first claim/decision queues.
    // Drained by PendingDonationsSyncer when connectivity returns.
    static let donationsContainer: ModelContainer = {
        let storeURL = URL.applicationSupportDirectory
            .appendingPathComponent("UniMarket-Donations.store")
        let config = ModelConfiguration(
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try! ModelContainer(
            for: DonationRequestRecord.self,
            configurations: config
        )
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(chatStore)
                .environmentObject(productStore)
                .environmentObject(cartStore)
                // Inject the reviews container so @Query works in any
                // descendant view (SellerReviewsView uses it).
                .modelContainer(Self.reviewsContainer)
                .task {
                    productStore.prefetchImages(for: productStore.activeProducts)
                    // Bind syncers once; resumeIfNeeded drains anything
                    // left over from a prior session.
                    PendingListingsSyncer.shared.bind(to: NetworkMonitor.shared)
                    PendingChatMessagesSyncer.shared.bind(to: NetworkMonitor.shared)
                    PendingFavoritesSyncer.shared.bind(to: NetworkMonitor.shared)
                    PendingListingMutationsSyncer.shared.bind(to: NetworkMonitor.shared)
                    PendingReviewsSyncer.shared.bind(
                        to: NetworkMonitor.shared,
                        container: Self.reviewsContainer
                    )
                    PendingDonationsSyncer.shared.bind(
                        to: NetworkMonitor.shared,
                        container: Self.donationsContainer
                    )
                    await PendingListingsSyncer.shared.resumeIfNeeded()
                    await PendingChatMessagesSyncer.shared.resumeIfNeeded()
                    await PendingFavoritesSyncer.shared.resumeIfNeeded()
                    await PendingListingMutationsSyncer.shared.resumeIfNeeded()
                    await PendingReviewsSyncer.shared.resumeIfNeeded()
                    await PendingDonationsSyncer.shared.resumeIfNeeded()
                }
                .tint(AppTheme.accent)
                .font(.poppinsRegular(16))
        }
    }
}
