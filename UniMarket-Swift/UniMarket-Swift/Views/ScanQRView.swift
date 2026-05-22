//
//  ScanQRView.swift
//  UniMarket-Swift
//
//  NOTE: NSCameraUsageDescription must be set in Info.plist.
//

import SwiftUI
import AVFoundation

struct ScanQRView: View {
    @StateObject private var vm: ScanQRViewModel
    @StateObject private var networkMonitor = NetworkMonitor()
    @Environment(\.dismiss) private var dismiss

    init(productID: String? = nil, source: AnalyticsSurface = .unknown) {
        _vm = StateObject(wrappedValue: ScanQRViewModel(productID: productID, source: source))
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if !networkMonitor.isConnected {
                offlineBlockedView
            } else {
                switch vm.scanState {
                case .scanning:
                    scanningView
                case .confirming(let payload):
                    confirmingView(payload: payload)
                case .loading:
                    loadingView
                case .confirmed:
                    confirmedView
                case .error(let message):
                    errorView(message: message)
                }
            }
        }
    }

    private var offlineBlockedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            Text("No Connection")
                .font(.poppinsBold(22))
                .foregroundStyle(AppTheme.primaryText)

            Text("You need a connection to confirm meetups")
                .font(.poppinsRegular(14))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)

            Button("Close") { dismiss() }
                .font(.poppinsSemiBold(16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.red)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(24)
    }

    // MARK: - States

    private var scanningView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Scan Pickup QR")
                    .font(.poppinsBold(22))
                    .foregroundStyle(AppTheme.primaryText)
                Text("Point your camera at the seller's QR code.")
                    .font(.poppinsRegular(13))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            QRScannerRepresentable { code in
                vm.handleScannedCode(code)
            }
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(AppTheme.accent, lineWidth: 2)
            )

            Button("Cancel") { dismiss() }
                .font(.poppinsSemiBold(16))
                .foregroundStyle(.red)
        }
        .padding(24)
    }

    private func confirmingView(payload: ScanQRViewModel.MeetupQRPayload) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.accent)

            Text("QR Code Scanned")
                .font(.poppinsBold(22))
                .foregroundStyle(AppTheme.primaryText)

            Text("Confirm pickup for this transaction?")
                .font(.poppinsRegular(14))
                .foregroundStyle(AppTheme.secondaryText)

            VStack(spacing: 4) {
                Text("Transaction ID")
                    .font(.poppinsRegular(11))
                    .foregroundStyle(AppTheme.secondaryText)
                Text(payload.transactionId)
                    .font(.poppinsSemiBold(12))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack(spacing: 12) {
                Button("Scan Again") { vm.resetScanning() }
                    .font(.poppinsSemiBold(16))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.accentAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button("Confirm") {
                    Task { await vm.confirmPickup(payload: payload) }
                }
                .font(.poppinsSemiBold(16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(24)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppTheme.accent)
            Text("Confirming pickup...")
                .font(.poppinsRegular(14))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var confirmedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(AppTheme.accent)

            Text("Pickup Confirmed!")
                .font(.poppinsBold(24))
                .foregroundStyle(AppTheme.primaryText)

            Text("The meetup has been recorded successfully.")
                .font(.poppinsRegular(14))
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

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.red)

            Text("Something went wrong")
                .font(.poppinsBold(22))
                .foregroundStyle(AppTheme.primaryText)

            Text(message)
                .font(.poppinsRegular(13))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Try Again") { vm.resetScanning() }
                    .font(.poppinsSemiBold(16))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.accentAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button("Close") { dismiss() }
                    .font(.poppinsSemiBold(16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(24)
    }
}

// MARK: - AVFoundation Scanner (UIViewControllerRepresentable)

struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onScan = onScan
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasScanned = false
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession?.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupSession() {
        let session = AVCaptureSession()

        guard
            let device = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { return }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)

        captureSession = session
        previewLayer = preview
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard
            !hasScanned,
            let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            obj.type == .qr,
            let value = obj.stringValue
        else { return }

        hasScanned = true
        captureSession?.stopRunning()
        onScan?(value)
    }
}
