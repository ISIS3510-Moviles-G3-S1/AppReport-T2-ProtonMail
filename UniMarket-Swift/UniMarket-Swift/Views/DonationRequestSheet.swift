import SwiftUI

struct DonationRequestSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject var viewModel: DonationRequestViewModel
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    @State private var showSuccessToast = false
    @State private var toastMessage: String = ""
    @State private var toastIsError = false

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    grabHandle

                    Text("Claim Donation")
                        .font(.poppinsBold(20))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("You are requesting: \(viewModel.product.title)")
                        .font(.poppinsRegular(13))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)

                    messageField
                    offlineNote
                    submitButton

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.poppinsRegular(12))
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
                .padding(.bottom, 20)
            }

            if showSuccessToast {
                toast
                    .padding(.bottom, 24)
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden) // we draw our own
    }

    // MARK: - Pieces

    private var grabHandle: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(AppTheme.secondaryText.opacity(0.4))
            .frame(width: 40, height: 5)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var messageField: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                if viewModel.message.isEmpty {
                    Text("Include an optional message to the donor…")
                        .font(.poppinsRegular(14))
                        .foregroundStyle(AppTheme.secondaryText.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                }
                TextEditor(text: $viewModel.message)
                    .font(.poppinsRegular(14))
                    .foregroundStyle(AppTheme.primaryText)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 110)
            }
            .background(AppTheme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private var offlineNote: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 8) {
                Text("⚠️")
                Text("You are currently offline. Your claim will be saved and synced automatically once you are back online.")
                    .font(.poppinsRegular(12))
                    .foregroundStyle(.orange)
            }
        } else {
            Text("Your claim will be submitted directly to the owner.")
                .font(.poppinsRegular(12))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                Spacer()
                if viewModel.isSubmitting {
                    ProgressView()
                        .tint(.white)
                        .padding(.trailing, 6)
                }
                Text(networkMonitor.isConnected ? "Request Item" : "Queue Request")
                    .font(.poppinsBold(16))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.vertical, 14)
            .background(AppTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSubmitting)
    }

    private var toast: some View {
        HStack(spacing: 10) {
            Image(systemName: toastIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(.white)
            Text(toastMessage)
                .font(.poppinsSemiBold(13))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(toastIsError ? Color.red : Color.green)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Submit

    private func submit() async {
        await viewModel.submitClaim()
        let succeeded = viewModel.errorMessage == nil
        toastIsError = !succeeded
        toastMessage = succeeded
            ? (viewModel.isQueued
                ? "Draft saved! Will sync when connection is restored."
                : "Claim request submitted successfully!")
            : "Failed to submit claim. Please try again."

        withAnimation(.easeInOut(duration: 0.2)) { showSuccessToast = true }

        if succeeded {
            // Give the toast a moment, then dismiss.
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            dismiss()
        } else {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeInOut(duration: 0.2)) { showSuccessToast = false }
        }
    }
}
