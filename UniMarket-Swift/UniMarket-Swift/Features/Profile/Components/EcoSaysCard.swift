//
//  EcoSaysCard.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct EcoSaysCard: View {
    let message: String
    var isLoading: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    private var imageBackground: Color {
        colorScheme == .light ? .white : Color.white.opacity(0.12)
    }

    private var displayMessage: String {
        if isLoading {
            return "Preparing your personalized eco recommendation..."
        }
        return message
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(imageBackground)
                    .frame(width: 86, height: 86)
                Image("Eco")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 86)
                    .frame(width: 86)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Eco says:")
                    .font(.poppinsSemiBold(14))
                    .foregroundStyle(AppTheme.accent)

                Text(displayMessage)
                    .font(.poppinsRegular(10))
                    .foregroundStyle(AppTheme.primaryText)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.white)
                .shadow(color: .black.opacity(0.08), radius: 6)
        )
    }
}
