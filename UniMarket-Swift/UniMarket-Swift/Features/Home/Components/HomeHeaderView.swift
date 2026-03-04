//
//  HomeHeaderView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct HomeHeaderView: View {
    var body: some View {
        VStack(spacing: 14) {
            Text("Sustainable Fashion for Students")
                .font(.poppinsSemiBold(12))
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(AppTheme.accent.opacity(0.24))
                .clipShape(Capsule())

            Text("Your Campus")
                .font(.poppinsBold(48))
                .foregroundStyle(AppTheme.accent)
                .multilineTextAlignment(.center)
                .lineSpacing(0)
            
            Text("Your Closet")
                .font(Font.poppinsBold(48))
                .foregroundStyle(AppTheme.accentAlt)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            
            

            Text("Buy, sell, and swap second-hand clothes with students from your university. AI-powered tagging. Zero effort. Real impact.")
                .font(.poppinsRegular(19))
                .foregroundStyle(.black.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)
        }
    }
}
