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

    var body: some View {
        VStack(spacing: 16) {
            Text("UniMarket")
                .font(.largeTitle).bold()

            TextField("Email", text: $email)
                .autocorrectionDisabled(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button("Log in") {
                session.isLoggedIn = true // login fake
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
