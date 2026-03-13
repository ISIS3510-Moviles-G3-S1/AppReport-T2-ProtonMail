//
//  RootView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

private enum AuthRoute: Hashable {
    case register
}

struct RootView: View {
    @EnvironmentObject var session: SessionManager
    @State private var authPath: [AuthRoute] = []

    var body: some View {
        GeometryReader { proxy in
            Group {
                if session.isLoading {
                    LoadingView()
                } else if session.isLoggedIn {
                    MainTabView()
                } else {
                    NavigationStack(path: $authPath) {
                        LoginView(onRegisterTap: { authPath.append(.register) })
                            .navigationDestination(for: AuthRoute.self) { route in
                                switch route {
                                case .register:
                                    RegisterView()
                                }
                            }
                    }
                }
            }
            .onChange(of: session.isLoggedIn) { _, loggedIn in
                if loggedIn {
                    authPath = []
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
