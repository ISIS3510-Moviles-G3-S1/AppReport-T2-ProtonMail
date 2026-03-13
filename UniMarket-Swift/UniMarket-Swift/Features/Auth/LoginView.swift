//
//  LoginView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct LoginView: View {
    var onRegisterTap: () -> Void = {}
    @EnvironmentObject var session: SessionManager
    @State private var username = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let domain = "@uniandes.edu.co"
    private var fullEmail: String { username.lowercased() + domain }

    private let accentColor = AppTheme.accent
    private let backgroundColor = AppTheme.background

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    logoSection

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Welcome back")
                            .font(.poppinsBold(30))
                            .foregroundStyle(.black)

                        Text("Log in to continue buying and selling on UniMarket.")
                            .font(.poppinsRegular(15))
                            .foregroundStyle(.black.opacity(0.75))

                        emailUsernameField
                        inputField(title: "Password", text: $password, isSecure: true)

                        Button {
                            Task {
                                isSubmitting = true
                                errorMessage = nil
                                do {
                                    try await session.signIn(email: fullEmail, password: password)
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                                isSubmitting = false
                            }
                        } label: {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(AppTheme.accentAlt)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            } else {
                                Text("Log in")
                                    .font(.poppinsSemiBold(18))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(AppTheme.accentAlt)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                        .disabled(isSubmitting)

                        HStack {
                            Spacer()
                            Text("Don't have an account?")
                                .font(.poppinsRegular(14))
                                .foregroundStyle(.black.opacity(0.6))
                            Spacer()
                        }
                        .padding(.top, 4)

                        Button(action: onRegisterTap) {
                            Text("Create an account")
                                .font(.poppinsSemiBold(16))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppTheme.background)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(AppTheme.accent, lineWidth: 1.5)
                                )
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.poppinsRegular(13))
                                .foregroundStyle(.red)
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

    private var logoSection: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.white)
            .frame(height: 160)
            .overlay {
                VStack(spacing: 10) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)

                }
                .padding(12)
            }
    }

    @ViewBuilder
    private func inputField(title: String, text: Binding<String>, isSecure: Bool) -> some View {
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
                    .keyboardType(.emailAddress)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(backgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(SessionManager())
}
