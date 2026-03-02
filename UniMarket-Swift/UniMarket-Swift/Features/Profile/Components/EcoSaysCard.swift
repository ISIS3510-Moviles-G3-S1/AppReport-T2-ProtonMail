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
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: 86, height: 86)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.green)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Eco says:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)

                Text(message)
                    .font(.subheadline)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.background)
                .shadow(radius: 6)
        )
    }
}
