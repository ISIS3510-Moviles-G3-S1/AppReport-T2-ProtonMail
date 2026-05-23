//
//  WriteReviewView.swift
//  UniMarket-Swift
//
//  Full-screen sheet for composing a seller review.
//
//  Offline behaviour:
//    • Submit button reads "Queue Review" when !vm.isConnected.
//    • Yellow banner explains the review will sync automatically.
//    • ReviewsViewModel.submitReview persists locally first (isSynced=false)
//      so the review appears in @Query even while offline; PendingReviewsSyncer
//      pushes it to Firestore on the next connectivity event.
//

import SwiftUI

struct WriteReviewView: View {

    // MARK: - Properties

    let sellerID: String
    @ObservedObject var vm: ReviewsViewModel

    @EnvironmentObject private var session: SessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRating: Int = 0
    @State private var reviewText: String = ""
    @State private var isSubmitting = false
    @State private var showValidationError = false

    private let maxCharacters = 500

    // MARK: - Computed helpers

    private var remainingCharacters: Int { maxCharacters - reviewText.count }

    private var canSubmit: Bool {
        selectedRating >= 1 && !reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var submitLabel: String {
        vm.isConnected ? "Submit Review" : "Queue Review"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // ── Offline banner ───────────────────────────────
                        if !vm.isConnected {
                            HStack(spacing: 8) {
                                Image(systemName: "wifi.slash")
                                    .foregroundStyle(.yellow)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("You're offline")
                                        .font(.poppinsSemiBold(13))
                                        .foregroundStyle(.yellow)
                                    Text("Your review will be saved locally and sent automatically when you reconnect.")
                                        .font(.poppinsRegular(12))
                                        .foregroundStyle(.yellow.opacity(0.85))
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.yellow.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        // ── Star rating picker ───────────────────────────
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your Rating")
                                .font(.poppinsSemiBold(15))
                                .foregroundStyle(AppTheme.primaryText)

                            HStack(spacing: 10) {
                                ForEach(1...5, id: \.self) { star in
                                    Button {
                                        selectedRating = star
                                    } label: {
                                        Image(
                                            systemName: star <= selectedRating
                                                ? "star.fill"
                                                : "star"
                                        )
                                        .font(.system(size: 36))
                                        .foregroundStyle(
                                            star <= selectedRating
                                                ? AppTheme.accent
                                                : AppTheme.borderColor
                                        )
                                        .contentTransition(.symbolEffect(.replace))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            if showValidationError && selectedRating == 0 {
                                Text("Please select a star rating.")
                                    .font(.poppinsRegular(12))
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(16)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        // ── Review text editor ───────────────────────────
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Review")
                                .font(.poppinsSemiBold(15))
                                .foregroundStyle(AppTheme.primaryText)

                            ZStack(alignment: .topLeading) {
                                if reviewText.isEmpty {
                                    Text("Describe your experience with this seller…")
                                        .font(.poppinsRegular(14))
                                        .foregroundStyle(AppTheme.secondaryText)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 8)
                                }

                                TextEditor(text: $reviewText)
                                    .font(.poppinsRegular(14))
                                    .foregroundStyle(AppTheme.primaryText)
                                    .frame(minHeight: 140)
                                    .onChange(of: reviewText) { _, newValue in
                                        if newValue.count > maxCharacters {
                                            reviewText = String(newValue.prefix(maxCharacters))
                                        }
                                    }
                            }
                            .padding(10)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.borderColor, lineWidth: 0.7)
                            )

                            // Character counter
                            HStack {
                                if showValidationError && reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("Review text cannot be empty.")
                                        .font(.poppinsRegular(12))
                                        .foregroundStyle(.red)
                                }
                                Spacer()
                                Text("\(remainingCharacters) characters left")
                                    .font(.poppinsRegular(12))
                                    .foregroundStyle(
                                        remainingCharacters < 50
                                            ? .orange
                                            : AppTheme.secondaryText
                                    )
                            }
                        }

                        // ── Submit button ────────────────────────────────
                        Button {
                            handleSubmit()
                        } label: {
                            Group {
                                if isSubmitting {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(submitLabel)
                                }
                            }
                            .font(.poppinsSemiBold(16))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(canSubmit ? AppTheme.accent : AppTheme.accent.opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(isSubmitting)
                    }
                    .padding(16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Write a Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.poppinsRegular(16))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    // MARK: - Actions

    private func handleSubmit() {
        showValidationError = true
        guard canSubmit else { return }
        isSubmitting = true

        let reviewerID   = session.uid ?? ""
        let displayName  = session.currentUser?.displayName
                        ?? session.user?.displayName
                        ?? "Anonymous"
        let text         = reviewText.trimmingCharacters(in: .whitespacesAndNewlines)
        let rating       = selectedRating

        Task {
            await vm.submitReview(
                reviewerID: reviewerID,
                reviewerDisplayName: displayName,
                starRating: rating,
                reviewText: text,
                productID: nil
            )
            await MainActor.run {
                isSubmitting = false
                dismiss()
            }
        }
    }
}
