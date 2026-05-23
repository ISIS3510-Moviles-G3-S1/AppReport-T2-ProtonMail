import SwiftUI

// MARK: - NotificationsView

/// Aggregated notification hub showing four concurrent data sources in a live-
/// updating List.  As each source completes in the background, its section
/// re-renders independently — no artificial delay, purely structural latency.
///
/// **Entry point**: bell-icon toolbar button in `HomeView`.
/// **Presentation**: sheet with its own `NavigationStack`.
struct NotificationsView: View {

    @StateObject private var viewModel = NotificationsViewModel()

    @EnvironmentObject private var chatStore:    ChatStore
    @EnvironmentObject private var productStore: ProductStore
    @EnvironmentObject private var session:      SessionManager

    // Navigation state for deep-link destinations.
    @State private var selectedConversationID: String?
    @State private var selectedProduct:        Product?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {

                // ── Offline banner ────────────────────────────────────────────
                if !viewModel.isConnected {
                    offlineBanner
                        .zIndex(1)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // ── Main list ─────────────────────────────────────────────────
                List {
                    // Messages
                    Section {
                        if viewModel.sections.unreadMessages.isEmpty {
                            emptyRow(text: "No unread messages")
                        } else {
                            ForEach(viewModel.sections.unreadMessages) { item in
                                notificationRow(item)
                            }
                        }
                    } header: {
                        sectionHeader("Messages", count: viewModel.sections.unreadMessages.count)
                    }

                    // Price Drops
                    Section {
                        if viewModel.sections.priceDrops.isEmpty {
                            emptyRow(text: "No price drops detected")
                        } else {
                            ForEach(viewModel.sections.priceDrops) { item in
                                notificationRow(item)
                            }
                        }
                    } header: {
                        sectionHeader("Price Drops", count: viewModel.sections.priceDrops.count)
                    }

                    // Sync Status
                    Section {
                        if viewModel.sections.syncStatus.isEmpty {
                            emptyRow(text: "All changes synced ✓")
                        } else {
                            ForEach(viewModel.sections.syncStatus) { item in
                                notificationRow(item)
                            }
                        }
                    } header: {
                        sectionHeader("Sync Status", count: viewModel.sections.syncStatus.count)
                    }

                    // Recent Activity
                    Section {
                        if viewModel.sections.recentActivity.isEmpty {
                            emptyRow(text: "No recent activity")
                        } else {
                            ForEach(viewModel.sections.recentActivity) { item in
                                notificationRow(item)
                            }
                        }
                    } header: {
                        sectionHeader("Recent Activity", count: viewModel.sections.recentActivity.count)
                    }

                    // Footer
                    if let refreshed = viewModel.lastRefreshedAt {
                        Section {
                            Text("Last refreshed: \(refreshed.relativeFormatted)")
                                .font(.poppinsRegular(12))
                                .foregroundStyle(AppTheme.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .listRowBackground(Color.clear)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.visible)
                .refreshable {
                    viewModel.refresh(chatStore: chatStore, productStore: productStore)
                }
                // Deep-link destinations registered on the NavigationStack.
                .navigationDestination(item: $selectedConversationID) { conversationID in
                    ChatThreadView(conversationID: conversationID)
                }
                .navigationDestination(item: $selectedProduct) { product in
                    ProductDetailView(product: product)
                }
                .navigationDestination(for: SyncQueueDestination.self) { _ in
                    SyncQueueView()
                }
                // Title: replaced by ProgressView while loading WITH partial data
                // (progressive rendering in flight).
                .navigationTitle(viewModel.isLoading && !viewModel.sections.isEmpty ? "" : "Notifications")
                .toolbar {
                    // Principal slot: ProgressView when loading + partial data visible.
                    if viewModel.isLoading && !viewModel.sections.isEmpty {
                        ToolbarItem(placement: .principal) {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.85)
                                Text("Updating…")
                                    .font(.poppinsSemiBold(14))
                                    .foregroundStyle(AppTheme.primaryText)
                            }
                        }
                    }
                }
                .padding(.top, (!viewModel.isConnected) ? 44 : 0)
            }
        }
        .task {
            viewModel.hydrateFromCache()
            viewModel.refresh(chatStore: chatStore, productStore: productStore)
        }
        // Re-trigger refresh when the Combine reconnect fires (ViewModel posts this
        // internally but the view also needs to forward the current stores).
        .onReceive(NotificationCenter.default.publisher(for: .notificationsReconnected)) { _ in
            viewModel.refresh(chatStore: chatStore, productStore: productStore)
        }
    }

    // MARK: - Row builder

    /// Wraps each `NotificationItem` in a `NotificationRowView` and wires the
    /// appropriate deep-link navigation when tapped.
    @ViewBuilder
    private func notificationRow(_ item: NotificationItem) -> some View {
        Button {
            navigateTo(item.deepLinkTarget, item: item)
        } label: {
            NotificationRowView(item: item)
        }
        .buttonStyle(.plain)
        .listRowBackground(AppTheme.cardBackground)
    }

    private func navigateTo(_ target: DeepLinkTarget, item: NotificationItem) {
        AnalyticsService.shared.track(.notificationTapped(
            type:   item.type.rawValue,
            target: target.analyticsLabel
        ))
        switch target {
        case .chatThread(let id):
            selectedConversationID = id
        case .productDetail(let id):
            selectedProduct = productStore.products.first { $0.id == id }
        case .activity, .syncQueue:
            break   // handled via NavigationLink / NavigationDestination below
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 4) {
            Text(title.uppercased())
                .font(.poppinsSemiBold(11))
                .foregroundStyle(AppTheme.secondaryText)
            if count > 0 {
                Text("\(count)")
                    .font(.poppinsSemiBold(11))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.accent)
                    .clipShape(Capsule())
            }
        }
    }

    private func emptyRow(text: String) -> some View {
        Text(text)
            .font(.poppinsRegular(14))
            .foregroundStyle(AppTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .listRowBackground(AppTheme.cardBackground)
    }

    // MARK: - Offline banner

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.orange)
            Group {
                if let last = viewModel.lastRefreshedAt {
                    Text("Offline — last updated \(last.relativeFormatted)")
                } else {
                    Text("Offline — showing cached data")
                }
            }
        }
        .font(.poppinsRegular(13))
        .foregroundStyle(AppTheme.primaryText)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.yellow.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }
}

// MARK: - NotificationRowView

/// A single notification row: system icon | title + subtitle stack | relative timestamp.
struct NotificationRowView: View {
    let item: NotificationItem

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconBackgroundColor.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: item.type.systemIconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconBackgroundColor)
            }

            // Text
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.poppinsSemiBold(14))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.poppinsRegular(12))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            // Relative timestamp
            Text(item.timestamp.relativeFormatted)
                .font(.poppinsRegular(11))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 6)
    }

    private var iconBackgroundColor: Color {
        switch item.type {
        case .unreadMessage:  return AppTheme.accent
        case .priceDrop:      return .orange
        case .syncStatus:     return AppTheme.accentAlt
        case .recentActivity: return Color(uiColor: .secondaryLabel)
        }
    }
}

// MARK: - SyncQueueDestination (Hashable navigation value)

struct SyncQueueDestination: Hashable {}

// MARK: - SyncQueueView

/// Inline summary of all pending sync queues. Shown when a syncStatus
/// notification is tapped with target == .syncQueue.
private struct SyncQueueView: View {
    @ObservedObject private var pendingListings  = PendingListingsSyncer.shared
    @ObservedObject private var pendingMessages  = PendingChatMessagesSyncer.shared
    @ObservedObject private var pendingFavorites = PendingFavoritesSyncer.shared
    @ObservedObject private var pendingMutations = PendingListingMutationsSyncer.shared

    var body: some View {
        List {
            queueRow(
                title:   "Listings",
                count:   pendingListings.pendingCount,
                icon:    "tag.fill",
                draining: pendingListings.isDraining
            )
            queueRow(
                title:   "Messages",
                count:   pendingMessages.pendingCount,
                icon:    "bubble.left.fill",
                draining: pendingMessages.isDraining
            )
            queueRow(
                title:   "Favorites",
                count:   pendingFavorites.pendingCount,
                icon:    "heart.fill",
                draining: pendingFavorites.isDraining
            )
            queueRow(
                title:   "Listing Edits",
                count:   pendingMutations.pendingCount,
                icon:    "pencil.circle.fill",
                draining: pendingMutations.isDraining
            )
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Sync Queue")
    }

    private func queueRow(
        title: String, count: Int, icon: String, draining: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(count > 0 ? AppTheme.accent : AppTheme.secondaryText)
                .frame(width: 24)
            Text(title)
                .font(.poppinsRegular(15))
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            if draining {
                ProgressView().scaleEffect(0.8)
            }
            Text(count == 0 ? "Synced" : "\(count) pending")
                .font(.poppinsRegular(13))
                .foregroundStyle(count > 0 ? .orange : AppTheme.secondaryText)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Date.relativeFormatted

extension Date {
    /// Human-readable relative string: "just now", "5 min ago", "Yesterday", etc.
    var relativeFormatted: String {
        let elapsed = -timeIntervalSinceNow
        switch elapsed {
        case ..<60:
            return "just now"
        case 60..<3_600:
            let mins = Int(elapsed / 60)
            return "\(mins) min ago"
        case 3_600..<86_400:
            let hrs = Int(elapsed / 3_600)
            return "\(hrs) hr\(hrs == 1 ? "" : "s") ago"
        default:
            let cal = Calendar.current
            if cal.isDateInYesterday(self) { return "Yesterday" }
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return f.string(from: self)
        }
    }
}

// MARK: - DeepLinkTarget analytics label

extension DeepLinkTarget {
    var analyticsLabel: String {
        switch self {
        case .chatThread:    return "chat_thread"
        case .productDetail: return "product_detail"
        case .activity:      return "activity"
        case .syncQueue:     return "sync_queue"
        }
    }
}
