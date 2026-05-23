import SwiftUI

struct MyDonationsView: View {
    @StateObject var viewModel: MyDonationsViewModel
    @State private var selectedTab: Int = 0
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Donations", selection: $selectedTab) {
                    Text("Given").tag(0)
                    Text("Claimed").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                ZStack {
                    if selectedTab == 0 {
                        givenList
                    } else {
                        claimedList
                    }
                }

                if viewModel.syncingCount > 0 {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("\(viewModel.syncingCount) \(viewModel.syncingCount == 1 ? "claim" : "claims") syncing")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                }
            }
            .navigationTitle("My Donations")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.refresh()
            }
        }
    }

    var givenList: some View {
        List {
            ForEach(viewModel.givenDonations) { request in
                donationRow(request, isGiven: true)
            }
        }
        .listStyle(.plain)
    }

    var claimedList: some View {
        List {
            ForEach(viewModel.claimedDonations) { request in
                donationRow(request, isGiven: false)
            }
        }
        .listStyle(.plain)
    }

    func donationRow(_ request: DonationRequestRecord, isGiven: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(request.donationListingID)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(request.status.displayName)
                    .font(.caption)
                    .foregroundColor(statusColor(request.status))
            }

            Spacer()

            if !request.isSyncedClaim {
                Label("Sending…", systemImage: "arrow.up.circle")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 8)
    }

    func statusColor(_ status: DonationRequestStatus) -> Color {
        switch status {
        case .pending:
            return .yellow
        case .approved:
            return .green
        case .declined:
            return .red
        case .withdrawn:
            return .gray
        }
    }
}
