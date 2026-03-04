//
//  AppTheme.swift
//  UniMarket-Swift
//

import SwiftUI

enum AppTheme {
    static let accent = Color(hex: "72A08A")
    static let accentAlt = Color(hex: "B1B87D")
    static let background = Color(hex: "F2F2F2")
    static let primaryText = Color.black
    static let secondaryText = Color.black.opacity(0.6)
}

extension Font {
    static func poppinsRegular(_ size: CGFloat) -> Font {
        .custom("Poppins-Regular", size: size)
    }

    static func poppinsSemiBold(_ size: CGFloat) -> Font {
        .custom("Poppins-SemiBold", size: size)
    }

    static func poppinsBold(_ size: CGFloat) -> Font {
        .custom("Poppins-Bold", size: size)
    }
}


extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let red = Double((int >> 16) & 0xFF) / 255.0
        let green = Double((int >> 8) & 0xFF) / 255.0
        let blue = Double(int & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}
