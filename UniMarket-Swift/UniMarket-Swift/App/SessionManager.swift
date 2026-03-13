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
            throw AuthError.invalidDomain
        }

        let result = try await Auth.auth().createUser(withEmail: email, password: password)

        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()

        try await db.collection("users").document(result.user.uid).setData([
            "uid": result.user.uid,
            "displayName": displayName,
            "email": email,
            "createdAt": FieldValue.serverTimestamp(),
            "isVerified": false
        ])

        try await result.user.sendEmailVerification()
    }

    // MARK: - Sign In
    func signIn(email: String, password: String) async throws {
        guard email.hasSuffix("@uniandes.edu.co") else {
            throw AuthError.invalidDomain
        }
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        guard result.user.isEmailVerified else {
            try Auth.auth().signOut()
            // Force state reset for unverified users.
            self.user = nil
            self.isLoading = false
            throw AuthError.emailNotVerified
        }

        // Update state immediately so RootView redirects without waiting for listener timing.
        self.user = result.user
    }

    // MARK: - Sign Out
    func signOut() throws {
        try Auth.auth().signOut()
        user = nil
        isLoading = false
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
}
