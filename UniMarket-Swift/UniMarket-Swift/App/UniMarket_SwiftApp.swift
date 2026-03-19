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
    @StateObject private var chatStore = ChatStore()

    @StateObject private var productStore = ProductStore()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(chatStore)
                .environmentObject(productStore)
                .tint(AppTheme.accent)
                .font(.poppinsRegular(16))
        }
    }
}
