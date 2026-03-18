//
//  UniMarket_SwiftApp.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI
import UIKit
import FirebaseCore

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // Firebase Auth persistence is .local by default — the session is stored
        // in the device keychain and survives app restarts, so users won't be
        // forced to log in every time. To change this behaviour:
        //   .local   → persists across restarts (default, recommended)
        //   .session → clears on app termination (like an incognito session)
        //   .none    → never persists (user must log in every launch)
        // Auth.auth().setPersistence(.local) { ... } ← only needed if overriding
        return true
    }
}

@main
struct UniMarket_SwiftApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var session = SessionManager()
    @StateObject private var chatStore = ChatStore()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(chatStore)
                .tint(AppTheme.accent)
                .font(.poppinsRegular(16))
        }
    }
}
