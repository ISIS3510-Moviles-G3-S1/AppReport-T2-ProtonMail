import SwiftUI

struct IncomingDonationRequestsView: View {
    @StateObject var viewModel: IncomingDonationRequestsViewModel
    @EnvironmentObject var sessionManager: SessionManager
    @ObservedObject var syncer = PendingDonationsSyncer.shared

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.requests.isEmpty && !viewModel.isLoading {
                    Text("No donation requests yet")
                        .foregroundColor(.gray)
                        .frame(maxHeight: .infinity, alignment: .center)
                } else {
                    requestList
                }
            }
            .navigationTitle("Donation Requests")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.refresh()
            }
        }
    }

    var requestList: some View {
        List {
            ForEach(viewModel.requests) { request in
            HStack(spacing: 12) {
                    // Requester avatar placeholder
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.requesterNames[request.requesterID] ?? "Unknown")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        if let message = request.requesterMessage, !message.isEmpty {
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        Text(request.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    // Clock badge for unsynced decisions
                    if !request.isSyncedDecision {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    VStack(spacing: 4) {
                        Button(action: {
                            Task { await viewModel.approveRequest(request.id) }
                        }) {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                        .disabled(!request.status.canTransition)

                        Button(action: {
                            Task { await viewModel.declineRequest(request.id) }
                        }) {
                            Image(systemName: "xmark")
                                .font(.caption)
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                                .background(Color.red)
                                .cornerRadius(4)
                        }
                        .disabled(!request.status.canTransition)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .listStyle(.plain)
    }
}

extension DonationRequestStatus {
    var canTransition: Bool {
        self == .pending
    }
}
