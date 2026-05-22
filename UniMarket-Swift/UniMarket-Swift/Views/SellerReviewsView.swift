//
//  SellerReviewsView.swift
//  UniMarket-Swift
//
//  Displays aggregate star average, review count, and a scrollable list of
//  reviews for a given seller.
//
//  Data layer:
//    • @Query with a #Predicate filter drives the list — NOT a manual array
//      filter on a @Published property. SwiftData updates the query
//      automatically whenever the shared ModelContainer saves.
//    • ReviewsViewModel.fetchReviews() refreshes from Firestore on appear
//      and writes results to a background context so @Query picks them up.
//
//  Offline behaviour:
//    • Yellow banner when !vm.isConnected.
//    • List still shows cached SwiftData records.
//    • "Write a Review" button remains active; WriteReviewView queues locally.
//

import SwiftUI
import SwiftData

struct SellerReviewsView: View {

    // MARK: - Properties

    let sellerID: String

    /// @Query drives the list. The predicate is fixed at init time using the
    /// injected sellerID; SwiftData re-evaluates it on every store change.
    @Query private var reviews: [ReviewRecord]

    @StateObject private var vm: ReviewsViewModel
    @EnvironmentObject private var session: SessionManager
    @State private var showWriteReview = false

    // MARK: - Init

    init(sellerID: String) {
        self.sellerID = sellerID

        // Dynamic @Query predicate — must be set in init before body runs.
        let filter = #Predicate<ReviewRecord> { $0.sellerID == sellerID }
        _reviews = Query(
            filter: filter,
            sort: \ReviewRecord.createdAt,
            order: .reverse
        )

        // ViewModel shares the same container that the app injects into the
        // environment, accessed via the static property to avoid an extra
        // environment lookup (which isn't available at @StateObject init time).
        _vm = StateObject(wrappedValue: ReviewsViewModel(
            sellerID: sellerID,
            container: UniMarket_SwiftApp.reviewsContainer
        ))
    }

    // MARK: - Computed helpers

    private var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        let total = reviews.reduce(0) { $0 + $1.starRating }
        return Double(total) / Double(reviews.count)
    }

    private var reviewCountLabel: String {
        switch reviews.count {
        case 0: return "No reviews yet"
        case 1: return "1 review"
        default: return "\(reviews.count) reviews"
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Offline banner ───────────────────────────────────────
                if !vm.isConnected {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .foregroundStyle(.yellow)
                        Text("You're offline — showing cached reviews")
                            .font(.poppinsRegular(13))
                            .foregroundStyle(.yellow)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.yellow.opacity(0.12))
                }

                // ── Aggregate header ─────────────────────────────────────
                VStack(spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.accent)

                        Text(reviews.isEmpty ? "—" : String(format: "%.1f", averageRating))
                            .font(.poppinsBold(40))
                            .foregroundStyle(AppTheme.primaryText)
                    }

                    Text(reviewCountLabel)
                        .font(.poppinsRegular(14))
                        .foregroundStyle(AppTheme.secondaryText)

                    if vm.isLoading {
                        ProgressView()
                            .tint(AppTheme.accent)
                            .padding(.top, 4)
                    }

                    if let errMsg = vm.errorMessage {
                        Text(errMsg)
                            .font(.poppinsRegular(12))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 16)

                Divider()

                // ── Review list ──────────────────────────────────────────
                if reviews.isEmpty && !vm.isLoading {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 44))
                            .foregroundStyle(AppTheme.secondaryText)
                        Text("No reviews yet")
                            .font(.poppinsSemiBold(16))
                            .foregroundStyle(AppTheme.secondaryText)
                        Text("Be the first to share your experience\nwith this seller.")
                            .font(.poppinsRegular(14))
                            .foregroundStyle(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(reviews) { review in
                            ReviewRowView(review: review)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(
                                    top: 4, leading: 16, bottom: 4, trailing: 16
                                ))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }

                // ── Write a Review button (only for other users' profiles) ──
                if session.uid != sellerID {
                    Button {
                        showWriteReview = true
                    } label: {
                        Text("Write a Review")
                            .font(.poppinsSemiBold(16))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .navigationTitle("Seller Reviews")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.fetchReviews(sellerID: sellerID)
        }
        .sheet(isPresented: $showWriteReview) {
            WriteReviewView(sellerID: sellerID, vm: vm)
                .environmentObject(session)
        }
    }
}
