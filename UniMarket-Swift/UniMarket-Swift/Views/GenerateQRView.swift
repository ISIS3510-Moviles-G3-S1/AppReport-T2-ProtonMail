//
//  GenerateQRView.swift
//  UniMarket-Swift
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct GenerateQRView: View {
    @StateObject private var vm: GenerateQRViewModel
    @StateObject private var networkMonitor = NetworkMonitor()
    @Environment(\.dismiss) private var dismiss

    init(listingId: String, sellerId: String, listingStatus: ProductStatus) {
        _vm = StateObject(wrappedValue: GenerateQRViewModel(
            listingId: listingId,
            sellerId: sellerId,
            listingStatus: listingStatus
        ))
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            switch vm.viewState {
            case .idle, .error:
                inputView
            case .loading:
                loadingView
            case .generated(let transactionId, let qrPayload):
                generatedView(transactionId: transactionId, qrPayload: qrPayload)
            }
        }
        .navigationTitle("Generate Meetup QR")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Input view

    private var inputView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                if !networkMonitor.isConnected {
                    HStack(spacing: 10) {
                        Image(systemName: "wifi.slash")
                            .foregroundStyle(.red)
                        Text("You need a connection to confirm meetups")
                            .font(.poppinsSemiBold(14))
                            .foregroundStyle(.red)
                        Spacer()
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.red.opacity(0.25), lineWidth: 1)
                    )
                }

                if !vm.isListingActive {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Only active listings can generate a QR. This listing is currently \(vm.listingStatus.rawValue.lowercased()).")
                            .font(.poppinsRegular(13))
                            .foregroundStyle(AppTheme.primaryText)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.1))
                    )
                }

                Text("Create a pending meetup transaction and show this QR to the buyer at pickup.")
                    .font(.poppinsRegular(13))
                    .foregroundStyle(AppTheme.secondaryText)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Buyer Email")
                        .font(.poppinsSemiBold(13))
                        .foregroundStyle(AppTheme.secondaryText)

                    TextField("buyer@uniandes.edu.co", text: $vm.buyerEmail)
                        .font(.poppinsRegular(14))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppTheme.cardBackground)
                                .shadow(color: .black.opacity(0.06), radius: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Text("Use the buyer's account email so only that buyer can confirm.")
                        .font(.poppinsRegular(11))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                if case .error(let message) = vm.viewState {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(message)
                            .font(.poppinsRegular(13))
                            .foregroundStyle(.red)
                    }
                }

                Button {
                    Task { await vm.generateQR() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "qrcode")
                        Text("Generate QR Code")
                    }
                    .font(.poppinsSemiBold(16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(vm.isListingActive && networkMonitor.isConnected ? AppTheme.accent : AppTheme.secondaryText)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!vm.isListingActive || !networkMonitor.isConnected)
            }
            .padding(20)
        }
    }


    // MARK: - Loading view

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppTheme.accent)
            Text("Validating and creating transaction...")
                .font(.poppinsRegular(13))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    // MARK: - Generated view

    private func generatedView(transactionId: String, qrPayload: String) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                    Text("Transaction created")
                        .font(.poppinsSemiBold(14))
                        .foregroundStyle(AppTheme.primaryText)
                }

                qrImage(for: qrPayload)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(AppTheme.cardBackground)
                            .shadow(color: .black.opacity(0.08), radius: 6)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )

                VStack(spacing: 4) {
                    Text("Transaction ID")
                        .font(.poppinsRegular(11))
                        .foregroundStyle(AppTheme.secondaryText)
                    Text(transactionId)
                        .font(.poppinsSemiBold(12))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Text("Show this QR to the buyer at pickup. They will scan it to confirm the transaction.")
                    .font(.poppinsRegular(12))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)

                Button("Done") { dismiss() }
                    .font(.poppinsSemiBold(16))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.accentAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(24)
        }
    }

    // MARK: - QR image helper

    private func qrImage(for content: String) -> Image {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(content.utf8)
        filter.correctionLevel = "M"
        guard
            let output = filter.outputImage,
            let cgImage = context.createCGImage(
                output.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
                from: output.transformed(by: CGAffineTransform(scaleX: 10, y: 10)).extent
            )
        else { return Image(systemName: "xmark.circle") }
        return Image(uiImage: UIImage(cgImage: cgImage))
    }
}
