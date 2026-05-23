import SwiftUI

struct IncomingDonationRequestsView: View {
    @StateObject var viewModel: IncomingDonationRequestsViewModel
    @ObservedObject private var syncer = PendingDonationsSyncer.shared

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.requests.isEmpty {
                ProgressView().tint(AppTheme.accent)
            } else if viewModel.requests.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
        .navigationTitle("Incoming Donation Requests")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.refresh() }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("📬").font(.system(size: 64))
            Text("No requests received yet")
                .font(.poppinsBold(18))
                .foregroundStyle(AppTheme.primaryText)
            Text("When users request your donations, they will appear here.")
                .font(.poppinsRegular(13))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - List grouped by listing ID

    private var groupedRequests: [(listingID: String, items: [DonationRequestRecord])] {
        // Preserve the original (already-sorted-desc-by-createdAt) order of first occurrence.
        var seen = [String: Int]()
        var ordered: [String] = []
        var buckets: [String: [DonationRequestRecord]] = [:]
        for r in viewModel.requests {
            if seen[r.donationListingID] == nil {
                seen[r.donationListingID] = ordered.count
                ordered.append(r.donationListingID)
                buckets[r.donationListingID] = []
            }
            buckets[r.donationListingID, default: []].append(r)
        }
        return ordered.map { ($0, buckets[$0] ?? []) }
    }

    private var listContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(groupedRequests, id: \.listingID) { group in
                    ListingGroupCard(listingID: group.listingID, requests: group.items, viewModel: viewModel)
                }
            }
            .padding(16)
        }
        .refreshable {
            viewModel.refresh()
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }
}

// MARK: - Listing group card

private struct ListingGroupCard: View {
    let listingID: String
    let requests: [DonationRequestRecord]
    @ObservedObject var viewModel: IncomingDonationRequestsViewModel
    @State private var expanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Listing ID: \(listingID)")
                            .font(.poppinsBold(14))
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text("\(requests.count) claim request\(requests.count == 1 ? "" : "s")")
                            .font(.poppinsRegular(12))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if expanded {
                ForEach(requests) { req in
                    Divider().background(AppTheme.borderColor)
                    RequestRow(request: req, viewModel: viewModel)
                }
            }
        }
        .background(AppTheme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Request row (avatar, name, email, message, action buttons)

private struct RequestRow: View {
    let request: DonationRequestRecord
    @ObservedObject var viewModel: IncomingDonationRequestsViewModel
    @State private var isResolving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(viewModel.displayName(for: request.requesterID))
                            .font(.poppinsSemiBold(14))
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)
                        if !request.isSyncedDecision {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.orange)
                        }
                    }
                    Text(viewModel.email(for: request.requesterID))
                        .font(.poppinsRegular(12))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                    if let msg = request.requesterMessage, !msg.isEmpty {
                        Text("\u{201C}\(msg)\u{201D}")
                            .font(.poppinsRegular(12)).italic()
                            .foregroundStyle(AppTheme.primaryText)
                            .padding(8)
                            .background(AppTheme.secondaryText.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .padding(.top, 4)
                    }
                }
                Spacer(minLength: 0)
            }

            actionRow
        }
        .padding(14)
    }

    private var avatar: some View {
        let name = viewModel.displayName(for: request.requesterID)
        let initial = name.first.map { String($0).uppercased() } ?? "?"
        return ZStack {
            Circle().fill(AppTheme.accent.opacity(0.15))
            Text(initial)
                .font(.poppinsBold(15))
                .foregroundStyle(AppTheme.accent)
        }
        .frame(width: 40, height: 40)
    }

    @ViewBuilder
    private var actionRow: some View {
        if request.status == .pending {
            HStack(spacing: 8) {
                Spacer()
                Button {
                    Task {
                        isResolving = true
                        await viewModel.declineRequest(request.id)
                        isResolving = false
                    }
                } label: {
                    Text("Decline")
                        .font(.poppinsSemiBold(13))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.red, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isResolving)

                Button {
                    Task {
                        isResolving = true
                        await viewModel.approveRequest(request.id)
                        isResolving = false
                    }
                } label: {
                    Text("Approve")
                        .font(.poppinsBold(13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isResolving)
            }
        } else {
            HStack {
                Spacer()
                statusPill
            }
        }
    }

    private var statusPill: some View {
        let approved = request.status == .approved
        let color: Color = approved ? .green : .red
        let icon = approved ? "checkmark.circle.fill" : "xmark.circle.fill"
        let label = approved ? "APPROVED" : "DECLINED"
        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
            Text(label)
                .font(.poppinsBold(11))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
