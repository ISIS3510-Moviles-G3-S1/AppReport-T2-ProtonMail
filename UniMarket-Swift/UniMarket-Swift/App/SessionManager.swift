//
//  SessionManager.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI
import FirebaseAuth
import Combine
import FirebaseFirestore


@MainActor
final class SessionManager: ObservableObject {
    private let db = Firestore.firestore()
    private let analytics = AnalyticsService.shared
    @Published var user: FirebaseAuth.User? = nil
    @Published var isLoading = true

    // Keep auth state derived from the current user to avoid divergent flags.
    var isLoggedIn: Bool {
        user?.isEmailVerified == true
    }

    private var authListener: AuthStateDidChangeListenerHandle?

    init() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }
                self.user = user
                self.isLoading = false
                self.updateAnalyticsUserState(for: user)
            }
        }
    }

    deinit {
        if let authListener {
            Auth.auth().removeStateDidChangeListener(authListener)
        }
    }

    // MARK: - Register
    func register(email: String, password: String, displayName: String) async throws {
        guard email.hasSuffix("@uniandes.edu.co") else {
            analytics.track(.registrationFailed(method: "email_password", reason: AuthError.invalidDomain.analyticsReason))
            throw AuthError.invalidDomain
        }

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()

            try await db.collection("users").document(result.user.uid).setData([
                "uid": result.user.uid,
                "displayName": displayName,
                "email": email,
                "createdAt": FieldValue.serverTimestamp(),
                "isVerified": false,
                "numTransactions": 0,
                "ratingStars": 0.0,
                "profilePic": "" ,// Placeholder, can be updated later with actual profile picture URL
                "xpPoints": 0
            ])

            try await result.user.sendEmailVerification()
            analytics.track(.registrationSucceeded(method: "email_password"))
        } catch {
            analytics.track(.registrationFailed(method: "email_password", reason: error.analyticsReason))
            throw error
        }
    }

    // MARK: - Sign In
    func signIn(email: String, password: String) async throws {
        guard email.hasSuffix("@uniandes.edu.co") else {
            analytics.track(.loginFailed(method: "email_password", reason: AuthError.invalidDomain.analyticsReason))
            throw AuthError.invalidDomain
        }
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            guard result.user.isEmailVerified else {
                analytics.track(.emailVerificationRequired())
                try Auth.auth().signOut()
                self.user = nil
                self.isLoading = false
                throw AuthError.emailNotVerified
            }

            self.user = result.user
            analytics.track(.loginSucceeded(method: "email_password"))
        } catch {
            analytics.track(.loginFailed(method: "email_password", reason: error.analyticsReason))
            throw error
        }
    }

    // MARK: - Sign Out
    func signOut() throws {
        try Auth.auth().signOut()
        user = nil
        isLoading = false
        analytics.track(.signOut())
        analytics.reset()
    }

    private func updateAnalyticsUserState(for user: FirebaseAuth.User?) {
        guard let user else {
            analytics.reset()
            return
        }

        analytics.setUserID(user.uid)
        analytics.setUserProperty(emailDomain(from: user.email), forName: "email_domain")
        analytics.setUserProperty(user.isEmailVerified ? "true" : "false", forName: "email_verified")
    }

    private func emailDomain(from email: String?) -> String? {
        guard let email, let domain = email.split(separator: "@").last else {
            return nil
        }
        return String(domain)
    }
}

// MARK: - Custom Errors
enum AuthError: LocalizedError {
    case invalidDomain
    case emailNotVerified

    var errorDescription: String? {
        switch self {
        case .invalidDomain:
            return "Only @uniandes.edu.co email addresses are allowed."
        case .emailNotVerified:
            return "Please verify your email before signing in. Check your inbox."
        }
    }

    var analyticsReason: String {
        switch self {
        case .invalidDomain:
            return "invalid_domain"
        case .emailNotVerified:
            return "email_not_verified"
        }
    }
}

private extension Error {
    var analyticsReason: String {
        if let authError = self as? AuthError {
            return authError.analyticsReason
        }

        let nsError = self as NSError
        return "\(nsError.domain.lowercased())_\(nsError.code)"
            .replacingOccurrences(of: " ", with: "_")
    }
}
