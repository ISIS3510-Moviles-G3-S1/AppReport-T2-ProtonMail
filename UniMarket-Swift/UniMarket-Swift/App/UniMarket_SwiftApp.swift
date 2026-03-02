//
//  UniMarket_SwiftApp.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

@main
struct UniMarket_SwiftApp: App {
    @StateObject private var session = SessionManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
        }
    }
}

