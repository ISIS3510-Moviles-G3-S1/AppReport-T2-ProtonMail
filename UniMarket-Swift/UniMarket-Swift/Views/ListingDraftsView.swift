import SwiftUI

struct ListingDraftsView: View {
    let userID: String?
    let onOpen: (ListingDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [ListingDraft] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                content
            }
            .navigationTitle("Drafts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.poppinsSemiBold(14))
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .task {
                await loadDrafts()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
                .tint(AppTheme.accent)
        } else if let errorMessage {
            Text(errorMessage)
                .font(.poppinsRegular(13))
                .foregroundStyle(.red)
                .padding()
        } else if drafts.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                Text("No saved drafts")
                    .font(.poppinsSemiBold(18))
                    .foregroundStyle(AppTheme.primaryText)
                Text("Drafts appear here when connection drops while you are filling out a listing.")
                    .font(.poppinsRegular(13))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(drafts) { draft in
                        draftRow(draft)
                    }
                }
                .padding(16)
            }
        }
    }

    private func draftRow(_ draft: ListingDraft) -> some View {
        HStack(spacing: 12) {
            Image(systemName: draft.imageCount > 0 ? "photo.on.rectangle" : "doc.text")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 42, height: 42)
                .background(AppTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(draft.title.isEmpty ? "Untitled listing" : draft.title)
                    .font(.poppinsSemiBold(14))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)

                Text(draftSubtitle(for: draft))
                    .font(.poppinsRegular(12))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                onOpen(draft)
                dismiss()
            } label: {
                Text("Open")
                    .font(.poppinsSemiBold(12))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                Task { await deleteDraft(draft) }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.background)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete draft")
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private func draftSubtitle(for draft: ListingDraft) -> String {
        let price = draft.priceText.isEmpty ? "No price" : "$\(draft.priceText)"
        let photos = "\(draft.imageCount) photo\(draft.imageCount == 1 ? "" : "s")"
        return "\(price) - \(photos) - \(draft.savedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private func loadDrafts() async {
        guard let userID else {
            drafts = []
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            drafts = try await ListingDraftStore.shared.allDrafts(for: userID)
        } catch {
            errorMessage = "Could not load saved drafts."
        }
        isLoading = false
    }

    private func deleteDraft(_ draft: ListingDraft) async {
        do {
            try await ListingDraftStore.shared.remove(draftID: draft.draftID, userID: draft.userID)
            drafts.removeAll { $0.draftID == draft.draftID }
        } catch {
            errorMessage = "Could not delete this draft."
        }
    }
}
