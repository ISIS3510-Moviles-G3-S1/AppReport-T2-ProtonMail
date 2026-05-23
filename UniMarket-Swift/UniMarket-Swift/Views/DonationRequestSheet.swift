import SwiftUI

struct DonationRequestSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject var viewModel: DonationRequestViewModel
    @ObservedObject var networkMonitor = NetworkMonitor.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Product info
                HStack(spacing: 12) {
                    if let imageURL = viewModel.product.primaryImageURL {
                        CachedRemoteImageView(urlString: imageURL)
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipped()
                            .cornerRadius(8)
                    } else {
                        Color.gray.opacity(0.2)
                            .frame(width: 80, height: 80)
                            .cornerRadius(8)
                    }

                    VStack(alignment: .leading) {
                        Text(viewModel.product.title)
                            .font(.headline)
                        Text(viewModel.product.sellerName)
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("FREE - Donation")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)

                // Message field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add a message (optional)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    TextEditor(text: $viewModel.message)
                        .frame(height: 100)
                        .padding(8)
                        .border(Color.gray.opacity(0.3))
                        .cornerRadius(4)
                }
                .padding()

                // Offline banner
                if !networkMonitor.isConnected {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("We'll send this when you're back online.")
                            .font(.caption)
                        Spacer()
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(8)
                }

                Spacer()

                // CTA button
                Button(action: {
                    Task {
                        await viewModel.submitClaim()
                        dismiss()
                    }
                }) {
                    HStack {
                        Image(systemName: "hand.thumbsup.fill")
                        Text(networkMonitor.isConnected ? "Claim Donation" : "Queue Claim")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(viewModel.isSubmitting)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding()
            .navigationTitle("Request Donation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
