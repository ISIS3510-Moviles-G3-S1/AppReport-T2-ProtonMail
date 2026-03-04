//
//  SustainabilityProgressCard.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct SustainabilityProgressCard: View {
    let profile: UserProfile

    private var progress: Double {
        let minXP = Double(profile.levelMinXP)
        let maxXP = Double(profile.levelMaxXP)
        let current = Double(profile.xp)
        let clamped = max(min(current, maxXP), minXP)
        return (clamped - minXP) / (maxXP - minXP)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SUSTAINABILITY LEVEL")
                        .font(.poppinsRegular(10))
                        .foregroundStyle(AppTheme.secondaryText)
                    Text(profile.levelTitle)
                        .font(.poppinsSemiBold(15))
                        .foregroundStyle(AppTheme.primaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Next up")
                        .font(.poppinsRegular(10))
                        .foregroundStyle(AppTheme.secondaryText)
                    Text(profile.nextLevelTitle)
                        .font(.poppinsSemiBold(15))
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(AppTheme.primaryText)
                    Text("\(profile.xpToNext) XP to go")
                        .font(.poppinsRegular(12))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.background)
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.accent.opacity(0.8))
                        .frame(width: max(12, CGFloat(progress) * proxy.size.width), height: 12)
                }
            }
            .frame(height: 12)

            HStack {
                Text("\(profile.levelMinXP) XP")
                Spacer()
                Text("\(profile.xp) XP")
                    .font(.poppinsSemiBold(12))
                Spacer()
                Text("\(profile.levelMaxXP) XP")
            }
            .font(.poppinsRegular(12))
            .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.white)
                .shadow(color: .black.opacity(0.08), radius: 6)
        )
    }
}
