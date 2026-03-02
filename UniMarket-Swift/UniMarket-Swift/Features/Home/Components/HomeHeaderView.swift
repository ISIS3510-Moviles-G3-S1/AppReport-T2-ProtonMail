//
//  HomeHeaderView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct HomeHeaderView: View {
    var body: some View {
        VStack(spacing: 12) {

            Text("Sustainable Fashion for Students")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.15))
                .cornerRadius(20)

            Text("Your Campus\nYour Closet.")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Buy, sell, and swap second-hand clothes with students from your university. AI-powered tagging. Zero effort. Real impact.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
