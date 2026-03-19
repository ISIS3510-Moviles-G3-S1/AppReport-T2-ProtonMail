//
//  ProfileMetricCard.swift
//  UniMarket-Swift
//
//  Created by Codex on 12/03/26.
//

import SwiftUI

struct ProfileMetricCard: View {
    let title: String
    let value: Int
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)

                Spacer()

                Text("Last 30 days")
                    .font(.poppinsRegular(10))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Text("\(value)")
                .font(.poppinsBold(28))
                .foregroundStyle(AppTheme.primaryText)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.poppinsSemiBold(14))
                    .foregroundStyle(AppTheme.primaryText)

                Text(subtitle)
                    .font(.poppinsRegular(11))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.white)
                .shadow(color: .black.opacity(0.08), radius: 6)
        )
    }
}
