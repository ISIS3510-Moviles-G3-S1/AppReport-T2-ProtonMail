//
//  RootView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI
import FirebaseAuth

private enum AuthRoute: Hashable {
    case register
}

struct RootView: View {
    @EnvironmentObject var session: SessionManager
    @EnvironmentObject private var productStore: ProductStore
    @EnvironmentObject private var chatStore: ChatStore
    @EnvironmentObject private var cartStore: CartStore
    @State private var authPath: [AuthRoute] = []

    var body: some View {
        GeometryReader { proxy in
            Group {
                if session.isLoading {
                    LoadingView()
                } else if session.isLoggedIn {
                    MainTabView()
                } else {
                    NavigationStack(path: $authPath) {
                        LoginView(onRegisterTap: { authPath.append(.register) })
                            .navigationDestination(for: AuthRoute.self) { route in
                                switch route {
                                case .register:
                                    RegisterView()
                                }
                            }
                    }
                }
            }
            .onChange(of: session.isLoggedIn) { _, loggedIn in
                if loggedIn {
                    authPath = []
                    // Start observing chat conversations when user logs in
                    chatStore.startObservingConversations()
                    runPostLoginWarmup()
                } else {
                    // Stop observing when user logs out
                    chatStore.stopObservingConversations()
                }
            }
            .onAppear {
                syncListingReminder(for: session.user?.uid)
                // Start observing conversations if already logged in
                if session.isLoggedIn {
                    chatStore.startObservingConversations()
                }
                cartStore.load(for: session.uid)
                cartStore.reconcile(with: productStore.products)
            }
            .onChange(of: session.user?.uid) { previousUserID, currentUserID in
                if let previousUserID, previousUserID != currentUserID {
                    Task {
                        await ListingReminderService.shared.clearReminder(for: previousUserID)
                    }
                }

                cartStore.load(for: currentUserID)
                cartStore.reconcile(with: productStore.products)
                syncListingReminder(for: currentUserID)
            }
            .onChange(of: productStore.products) { _, products in
                cartStore.reconcile(with: products)
                syncListingReminder(for: session.user?.uid)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    /// Triggers two parallel concurrency strategies right after authentication:
    ///
    /// 1. `LoginBootstrapper.bootstrap` — three Firestore reads (profile, saved IDs,
    ///    last listing date) launched as `async let` and awaited as a tuple. The
    ///    results are applied to the shared stores so the rest of the app starts
    ///    with hot data.
    /// 2. `ProfileInsightsPreloader.preloadAfterLogin` — `Task.detached(priority:
    ///    .background)` warming the eco-message and impact-insight caches before
    ///    the user ever opens the Profile tab.
    private func runPostLoginWarmup() {
        guard let uid = session.user?.uid else { return }

        Task {
            let result = await LoginBootstrapper.bootstrap(uid: uid)
            if let user = result.user { session.currentUser = user }
            productStore.applySavedItemIDs(result.savedItemIDs)
            await ListingReminderService.shared.syncReminder(
                for: uid,
                lastListingDate: result.lastListingDate
            )
        }

        ProfileInsightsPreloader.preloadAfterLogin(
            session: session,
            productStore: productStore
        )
    }

    private func syncListingReminder(for userID: String?) {
        guard let userID else { return }

        let lastListingDate = productStore
            .myListings(for: userID)
            .map(\.createdAt)
            .max()

        Task {
            await ListingReminderService.shared.syncReminder(for: userID, lastListingDate: lastListingDate)
        }
    }
}
