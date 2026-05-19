//
//  CheckoutViewModel.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import Combine
import Foundation

@MainActor
final class CheckoutViewModel: ObservableObject {
    @Published var fullName = ""
    @Published var email = ""
    @Published var pickupLocation = ""
    @Published var cardholderName = ""
    @Published var cardNumber = ""
    @Published var expiryDate = ""
    @Published var securityCode = ""
    @Published var billingZip = ""
    @Published var rememberCheckoutDetails = false
    @Published var usesSavedPayment = false
    @Published private(set) var savedPaymentSummary: String?
    @Published var validationMessage: String?
    @Published var isProcessing = false
    @Published var didComplete = false
    @Published var orderNumber = ""

    private let defaults: UserDefaults
    private let storageKeyPrefix = "unimarket.checkout.saved_details"
    private var savedDetails: SavedCheckoutDetails?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var canSubmit: Bool {
        !isProcessing && !didComplete
    }

    var hasSavedPayment: Bool {
        savedDetails != nil
    }

    func loadSavedDetails(for userID: String?) {
        guard let data = defaults.data(forKey: storageKey(for: userID)),
              let details = try? JSONDecoder().decode(SavedCheckoutDetails.self, from: data)
        else { return }

        savedDetails = details
        savedPaymentSummary = "Card ending in \(details.cardLastFour)"
        usesSavedPayment = true
        rememberCheckoutDetails = true

        if fullName.isEmpty { fullName = details.fullName }
        if email.isEmpty { email = details.email }
        if pickupLocation.isEmpty { pickupLocation = details.pickupLocation }
        cardholderName = details.cardholderName
        expiryDate = details.expiryDate
        billingZip = details.billingZip
        cardNumber = ""
        securityCode = ""
    }

    func useSavedPayment() {
        guard savedDetails != nil else { return }
        usesSavedPayment = true
        cardNumber = ""
        securityCode = ""
        validationMessage = nil
    }

    func enterNewCard() {
        usesSavedPayment = false
        cardNumber = ""
        securityCode = ""
        validationMessage = nil
    }

    func forgetSavedDetails(for userID: String?) {
        defaults.removeObject(forKey: storageKey(for: userID))
        savedDetails = nil
        savedPaymentSummary = nil
        usesSavedPayment = false
        rememberCheckoutDetails = false
    }

    func updateCardNumber(_ value: String) {
        usesSavedPayment = false
        let digits = value.filter(\.isNumber).prefix(19)
        cardNumber = stride(from: 0, to: digits.count, by: 4)
            .map { offset in
                let start = digits.index(digits.startIndex, offsetBy: offset)
                let end = digits.index(start, offsetBy: min(4, digits.distance(from: start, to: digits.endIndex)))
                return String(digits[start..<end])
            }
            .joined(separator: " ")
    }

    func updateExpiryDate(_ value: String) {
        let digits = value.filter(\.isNumber).prefix(4)
        if digits.count <= 2 {
            expiryDate = String(digits)
            return
        }

        let monthEnd = digits.index(digits.startIndex, offsetBy: 2)
        expiryDate = "\(digits[..<monthEnd])/\(digits[monthEnd...])"
    }

    func updateSecurityCode(_ value: String) {
        usesSavedPayment = false
        securityCode = String(value.filter(\.isNumber).prefix(4))
    }

    func updateBillingZip(_ value: String) {
        billingZip = String(value.filter(\.isNumber).prefix(6))
    }

    func submit(items: [CartItem], userID: String?) async -> Bool {
        validationMessage = nil
        guard validate(items: items) else { return false }

        isProcessing = true
        try? await Task.sleep(nanoseconds: 800_000_000)
        orderNumber = "UM-\(String(UUID().uuidString.prefix(8)).uppercased())"

        if rememberCheckoutDetails {
            saveDetails(for: userID)
        } else if hasSavedPayment {
            forgetSavedDetails(for: userID)
        }

        isProcessing = false
        didComplete = true
        return true
    }

    private func validate(items: [CartItem]) -> Bool {
        guard !items.isEmpty else {
            validationMessage = "Your cart is empty."
            return false
        }

        guard !trimmed(fullName).isEmpty else {
            validationMessage = "Enter your full name."
            return false
        }

        guard isValidEmail(email) else {
            validationMessage = "Enter a valid email address."
            return false
        }

        guard !trimmed(pickupLocation).isEmpty else {
            validationMessage = "Enter a pickup location."
            return false
        }

        guard !trimmed(cardholderName).isEmpty else {
            validationMessage = "Enter the cardholder name."
            return false
        }

        if usesSavedPayment {
            guard savedDetails != nil else {
                validationMessage = "Choose a saved card or enter a new card."
                return false
            }
        } else {
            let cardDigits = cardNumber.filter(\.isNumber)
            guard (13...19).contains(cardDigits.count) else {
                validationMessage = "Enter a valid card number."
                return false
            }

            let cvvDigits = securityCode.filter(\.isNumber)
            guard (3...4).contains(cvvDigits.count) else {
                validationMessage = "Enter a valid CVV."
                return false
            }
        }

        guard isValidExpiryDate(expiryDate) else {
            validationMessage = "Enter a valid expiry date."
            return false
        }

        guard billingZip.filter(\.isNumber).count >= 4 else {
            validationMessage = "Enter a valid billing ZIP."
            return false
        }

        return true
    }

    private func saveDetails(for userID: String?) {
        let cardLastFour: String
        let paymentToken: String

        if usesSavedPayment, let savedDetails {
            cardLastFour = savedDetails.cardLastFour
            paymentToken = savedDetails.paymentToken
        } else {
            let cardDigits = cardNumber.filter(\.isNumber)
            cardLastFour = String(cardDigits.suffix(4))
            paymentToken = "demo_\(UUID().uuidString)"
        }

        let details = SavedCheckoutDetails(
            fullName: trimmed(fullName),
            email: trimmed(email),
            pickupLocation: trimmed(pickupLocation),
            cardholderName: trimmed(cardholderName),
            cardLastFour: cardLastFour,
            expiryDate: expiryDate,
            billingZip: billingZip,
            paymentToken: paymentToken,
            updatedAt: .now
        )

        guard let data = try? JSONEncoder().encode(details) else { return }
        defaults.set(data, forKey: storageKey(for: userID))
        savedDetails = details
        savedPaymentSummary = "Card ending in \(details.cardLastFour)"
        usesSavedPayment = true
        cardNumber = ""
        securityCode = ""
    }

    private func isValidEmail(_ value: String) -> Bool {
        let trimmedValue = trimmed(value)
        return trimmedValue.contains("@") && trimmedValue.contains(".")
    }

    private func isValidExpiryDate(_ value: String) -> Bool {
        let parts = value.split(separator: "/")
        guard parts.count == 2,
              let month = Int(parts[0]),
              let year = Int(parts[1]),
              (1...12).contains(month)
        else {
            return false
        }

        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date()) % 100
        let currentMonth = calendar.component(.month, from: Date())
        return year > currentYear || (year == currentYear && month >= currentMonth)
    }

    private func storageKey(for userID: String?) -> String {
        let normalizedUserID = userID?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalizedUserID, !normalizedUserID.isEmpty else {
            return "\(storageKeyPrefix).guest"
        }

        return "\(storageKeyPrefix).\(normalizedUserID)"
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct SavedCheckoutDetails: Codable {
    let fullName: String
    let email: String
    let pickupLocation: String
    let cardholderName: String
    let cardLastFour: String
    let expiryDate: String
    let billingZip: String
    let paymentToken: String
    let updatedAt: Date
}
