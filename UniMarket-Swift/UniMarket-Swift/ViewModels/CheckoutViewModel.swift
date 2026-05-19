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
    @Published var validationMessage: String?
    @Published var isProcessing = false
    @Published var didComplete = false
    @Published var orderNumber = ""

    var canSubmit: Bool {
        !isProcessing && !didComplete
    }

    func updateCardNumber(_ value: String) {
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
        securityCode = String(value.filter(\.isNumber).prefix(4))
    }

    func updateBillingZip(_ value: String) {
        billingZip = String(value.filter(\.isNumber).prefix(6))
    }

    func submit(items: [CartItem]) async -> Bool {
        validationMessage = nil
        guard validate(items: items) else { return false }

        isProcessing = true
        try? await Task.sleep(nanoseconds: 800_000_000)
        orderNumber = "UM-\(String(UUID().uuidString.prefix(8)).uppercased())"
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

        let cardDigits = cardNumber.filter(\.isNumber)
        guard (13...19).contains(cardDigits.count) else {
            validationMessage = "Enter a valid card number."
            return false
        }

        guard isValidExpiryDate(expiryDate) else {
            validationMessage = "Enter a valid expiry date."
            return false
        }

        let cvvDigits = securityCode.filter(\.isNumber)
        guard (3...4).contains(cvvDigits.count) else {
            validationMessage = "Enter a valid CVV."
            return false
        }

        guard billingZip.filter(\.isNumber).count >= 4 else {
            validationMessage = "Enter a valid billing ZIP."
            return false
        }

        return true
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

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
