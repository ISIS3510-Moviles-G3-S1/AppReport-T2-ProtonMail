//
//  RegisterView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var session: SessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""          // just the part before @uniandes.edu.co
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var displayName = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var registrationSent = false

    private let domain = "@uniandes.edu.co"
    private var fullEmail: String { username.lowercased() + domain }

    private let accentColor = AppTheme.accent
    private let backgroundColor = AppTheme.background

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    logoSection

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Create account")
                            .font(.poppinsBold(30))
                            .foregroundStyle(.black)

                        Text("Join UniMarket with your university email.")
                            .font(.poppinsRegular(15))
                            .foregroundStyle(.black.opacity(0.75))

                        if registrationSent {
                            // Success state
                            VStack(spacing: 12) {
                                Image(systemName: "envelope.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(accentColor)

                                Text("Verification email sent!")
                                    .font(.poppinsSemiBold(18))
                                    .foregroundStyle(.black)

                                Text("Check your @uniandes.edu.co inbox and click the link to activate your account.")
                                    .font(.poppinsRegular(14))
                                    .foregroundStyle(.black.opacity(0.7))
                                    .multilineTextAlignment(.center)

                                Button {
                                    dismiss()
                                } label: {
                                    Text("Back to Login")
                                        .font(.poppinsSemiBold(16))
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(AppTheme.accentAlt)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .padding(.top, 8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)

                        } else {
                            // Form state
                            inputField(title: "Full Name", text: $displayName, isSecure: false, keyboard: .default)
                            emailUsernameField
                            inputField(title: "Password", text: $password, isSecure: true, keyboard: .default)
                            inputField(title: "Confirm Password", text: $confirmPassword, isSecure: true, keyboard: .default)

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.poppinsRegular(13))
                                    .foregroundStyle(.red)
                            }

                            Button {
                                Task { await submit() }
                            } label: {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(AppTheme.accentAlt)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                } else {
                                    Text("Create Account")
                                        .font(.poppinsSemiBold(18))
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(AppTheme.accentAlt)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                            }
                            .disabled(isSubmitting)
                        }
                    }
                    .padding(20)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(accentColor.opacity(0.35), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
            }
        }
        .navigationBarBackButtonHidden(registrationSent)
    }

    private func submit() async {
        errorMessage = nil

        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your full name."; return
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords don't match."; return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."; return
        }

        isSubmitting = true
        do {
            try await session.register(email: fullEmail, password: password, displayName: displayName)
            registrationSent = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    private var logoSection: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.white)
            .frame(height: 160)
            .overlay {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .padding(12)
            }
    }

    private var emailUsernameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("University Email")
                .font(.poppinsSemiBold(14))
                .foregroundStyle(.black)

            HStack(spacing: 0) {
                TextField("username", text: $username)
                    .font(.poppinsRegular(15))
                    .foregroundStyle(.black)
                    .colorScheme(.light)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.emailAddress)
                    .padding(.vertical, 12)
                    .padding(.leading, 14)

                Text(domain)
                    .font(.poppinsRegular(15))
                    .foregroundStyle(.black.opacity(0.45))
                    .padding(.trailing, 14)
                    .lineLimit(1)
                    .fixedSize()
            }
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private func inputField(title: String, text: Binding<String>, isSecure: Bool, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.poppinsSemiBold(14))
                .foregroundStyle(.black)

            if isSecure {
                SecureField(title, text: text)
                    .font(.poppinsRegular(15))
                    .foregroundStyle(.black)
                    .colorScheme(.light)
                    .textInputAutocapitalization(.never)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(backgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                TextField(title, text: text)
                    .font(.poppinsRegular(15))
                    .foregroundStyle(.black)
                    .colorScheme(.light)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(keyboard)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(backgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

#Preview {
    RegisterView()
        .environmentObject(SessionManager())
}
