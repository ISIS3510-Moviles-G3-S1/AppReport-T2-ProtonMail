//
//  SessionManager.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI
import Combine

final class SessionManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
}
