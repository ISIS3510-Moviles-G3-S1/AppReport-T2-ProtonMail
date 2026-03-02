//
//  LoginView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var session: SessionManager
    @State private var email = ""
    @State private var password = ""

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

                        inputField(title: "Email", text: $email, isSecure: false)
                        inputField(title: "Password", text: $password, isSecure: true)

                        Button {
                            session.isLoggedIn = true
                        } label: {
                            Text("Log in")
                                .font(.poppinsSemiBold(18))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppTheme.accentAlt)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private var logoSection: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.white)
            .frame(height: 160)
            .overlay {
                VStack(spacing: 10) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 72)

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
                    .textInputAutocapitalization(.never)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(backgroundColor)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                TextField(title, text: text)
                    .font(.poppinsRegular(15))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.emailAddress)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(backgroundColor)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(SessionManager())
}
