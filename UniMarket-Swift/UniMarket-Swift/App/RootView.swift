//
//  RootView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: SessionManager

    var body: some View {
        GeometryReader { proxy in
            Group {
                if session.isLoggedIn {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

#Preview("Logged In") {
    let session = SessionManager()
    session.isLoggedIn = true

    return RootView()
        .environmentObject(session)
}
