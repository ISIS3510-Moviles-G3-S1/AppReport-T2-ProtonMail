//
//  EcoSaysCard.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct EcoSaysCard: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.background)
                    .frame(width: 86, height: 86)
                Image(systemName: "leaf.fill")
                    .font(.poppinsSemiBold(30))
                    .foregroundStyle(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Eco says:")
                    .font(.poppinsSemiBold(14))
                    .foregroundStyle(AppTheme.accent)

                Text(message)
                    .font(.poppinsRegular(14))
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
