import FirebaseAuth
import SwiftUI

struct CheckoutView: View {
    private let analytics = AnalyticsService.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var cartStore: CartStore
    @EnvironmentObject private var session: SessionManager
    @StateObject private var viewModel = CheckoutViewModel()
    @State private var checkoutTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            if viewModel.didComplete {
                successState
            } else if cartStore.items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        demoNotice
                        orderSummary
                        contactSection
                        paymentSection

                        if let validationMessage = viewModel.validationMessage {
                            validationBanner(validationMessage)
                        }

                        submitButton
                    }
                    .padding(16)
                    .padding(.bottom, 80)
                }
            }
        }
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadSavedDetails(for: session.uid)
            if viewModel.email.isEmpty {
                viewModel.email = session.user?.email ?? ""
            }
            if viewModel.fullName.isEmpty {
                viewModel.fullName = session.currentUser?.displayName ?? session.user?.displayName ?? ""
            }
        }
        .onDisappear {
            checkoutTask?.cancel()
            checkoutTask = nil
        }
    }

    private var demoNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "creditcard.trianglebadge.exclamationmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Demo payment")
                    .font(.poppinsSemiBold(14))
                    .foregroundStyle(AppTheme.primaryText)
                Text("Only masked demo card info is saved locally.")
                    .font(.poppinsRegular(12))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.2), lineWidth: 1)
        )
    }

    private var orderSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Summary")
                .font(.poppinsSemiBold(16))
                .foregroundStyle(AppTheme.primaryText)

            ForEach(cartStore.items) { item in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.product.title)
                            .font(.poppinsSemiBold(13))
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)
                        Text(item.product.sellerName)
                            .font(.poppinsRegular(11))
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text("$\(item.product.price)")
                        .font(.poppinsSemiBold(13))
                        .foregroundStyle(AppTheme.primaryText)
                }
            }

            Divider()

            HStack {
                Text("Total")
                    .font(.poppinsSemiBold(16))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Text("$\(cartStore.subtotal)")
                    .font(.poppinsBold(20))
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var contactSection: some View {
        formSection(title: "Contact", icon: "person.text.rectangle") {
            checkoutTextField("Full name", text: $viewModel.fullName, contentType: .name)
            checkoutTextField("Email", text: $viewModel.email, keyboardType: .emailAddress, contentType: .emailAddress)
            checkoutTextField("Pickup location", text: $viewModel.pickupLocation)
        }
    }

    private var paymentSection: some View {
        formSection(title: "Payment", icon: "creditcard") {
            if let savedPaymentSummary = viewModel.savedPaymentSummary {
                savedPaymentCard(savedPaymentSummary)
            }

            checkoutTextField("Cardholder name", text: $viewModel.cardholderName, contentType: .name)

            if !viewModel.usesSavedPayment {
                checkoutTextField(
                    "Card number",
                    text: Binding(
                        get: { viewModel.cardNumber },
                        set: { viewModel.updateCardNumber($0) }
                    ),
                    keyboardType: .numberPad,
                    contentType: .creditCardNumber
                )
            }

            HStack(spacing: 10) {
                checkoutTextField(
                    "MM/YY",
                    text: Binding(
                        get: { viewModel.expiryDate },
                        set: { viewModel.updateExpiryDate($0) }
                    ),
                    keyboardType: .numberPad
                )

                if !viewModel.usesSavedPayment {
                    checkoutTextField(
                        "CVV",
                        text: Binding(
                            get: { viewModel.securityCode },
                            set: { viewModel.updateSecurityCode($0) }
                        ),
                        keyboardType: .numberPad
                    )
                }
            }

            checkoutTextField(
                "Billing ZIP",
                text: Binding(
                    get: { viewModel.billingZip },
                    set: { viewModel.updateBillingZip($0) }
                ),
                keyboardType: .numberPad,
                contentType: .postalCode
            )

            Toggle(isOn: $viewModel.rememberCheckoutDetails) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remember demo checkout details")
                        .font(.poppinsSemiBold(13))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Stores contact info and a masked card token in UserDefaults.")
                        .font(.poppinsRegular(11))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .tint(AppTheme.accent)
        }
    }

    private func savedPaymentCard(_ summary: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.usesSavedPayment ? "checkmark.circle.fill" : "creditcard")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(viewModel.usesSavedPayment ? AppTheme.accent : AppTheme.secondaryText)

            VStack(alignment: .leading, spacing: 2) {
                Text(summary)
                    .font(.poppinsSemiBold(13))
                    .foregroundStyle(AppTheme.primaryText)
                Text(viewModel.usesSavedPayment ? "Using saved demo card" : "Saved locally as a masked token")
                    .font(.poppinsRegular(11))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            if viewModel.usesSavedPayment {
                Button("New") {
                    viewModel.enterNewCard()
                }
                .font(.poppinsSemiBold(12))
                .foregroundStyle(AppTheme.accent)
            } else {
                Button("Use") {
                    viewModel.useSavedPayment()
                }
                .font(.poppinsSemiBold(12))
                .foregroundStyle(AppTheme.accent)
            }

            Button {
                viewModel.forgetSavedDetails(for: session.uid)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.background)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Forget saved checkout details")
        }
        .padding(12)
        .background(AppTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var submitButton: some View {
        Button {
            startCheckout()
        } label: {
            Group {
                if viewModel.isProcessing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Place Demo Order")
                }
            }
            .font(.poppinsSemiBold(16))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(viewModel.canSubmit ? AppTheme.accent : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canSubmit)
    }

    private func startCheckout() {
        checkoutTask?.cancel()
        let items = cartStore.items
        let userID = session.uid

        checkoutTask = Task { @MainActor in
            let completed = await viewModel.submit(items: items, userID: userID)
            guard !Task.isCancelled else { return }

            if completed {
                trackDemoOrderPlaced(items: items)
                cartStore.clear()
            }
            checkoutTask = nil
        }
    }

    private func trackDemoOrderPlaced(items: [CartItem]) {
        let aiStylistItems = items.filter { $0.source == AnalyticsSurface.aiStylist.rawValue }
        analytics.track(.demoOrderPlaced(
            orderNumber: viewModel.orderNumber,
            itemCount: items.count,
            subtotal: items.reduce(0) { $0 + $1.product.price },
            aiStylistItemCount: aiStylistItems.count,
            aiStylistSubtotal: aiStylistItems.reduce(0) { $0 + $1.product.price },
            usedSavedPayment: viewModel.usesSavedPayment
        ))
    }

    private var successState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(AppTheme.accent)

            Text("Order Placed")
                .font(.poppinsBold(24))
                .foregroundStyle(AppTheme.primaryText)

            Text(viewModel.orderNumber)
                .font(.poppinsSemiBold(15))
                .foregroundStyle(AppTheme.secondaryText)

            Button("Done") {
                dismiss()
            }
            .font(.poppinsSemiBold(16))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.top, 8)
        }
        .padding(20)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
            Text("Your cart is empty.")
                .font(.poppinsSemiBold(18))
                .foregroundStyle(AppTheme.primaryText)
        }
        .padding(20)
    }

    private func formSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(AppTheme.accent)
                Text(title)
                    .font(.poppinsSemiBold(16))
                    .foregroundStyle(AppTheme.primaryText)
            }

            content()
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private func checkoutTextField(
        _ placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        contentType: UITextContentType? = nil
    ) -> some View {
        TextField(placeholder, text: text)
            .font(.poppinsRegular(14))
            .keyboardType(keyboardType)
            .textContentType(contentType)
            .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
            .autocorrectionDisabled(keyboardType == .emailAddress)
            .padding(12)
            .background(AppTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func validationBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.poppinsRegular(12))
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
