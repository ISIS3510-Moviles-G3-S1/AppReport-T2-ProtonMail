//
//  SustainabilityProgressCard.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct SustainabilityProgressCard: View {
    typealias LevelInfo = (title: String, nextTitle: String, xpToNext: Int, minXP: Int, maxXP: Int)

    let xp: Int
    let xpToNext: Int
    let levelInfo: LevelInfo

    private var progress: Double {
        let minXP = Double(levelInfo.minXP)
        let maxXP = Double(levelInfo.maxXP)
        let current = Double(xp)
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
                    Text(levelInfo.title)
                        .font(.poppinsSemiBold(15))
                        .foregroundStyle(AppTheme.primaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Next up")
                        .font(.poppinsRegular(10))
                        .foregroundStyle(AppTheme.secondaryText)
                    Text(levelInfo.nextTitle)
                        .font(.poppinsSemiBold(15))
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(AppTheme.primaryText)
                    Text("\(xpToNext) XP to go")
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
                Text("\(levelInfo.minXP) XP")
                Spacer()
                Text("\(xp) XP")
                    .font(.poppinsSemiBold(12))
                Spacer()
                Text("\(levelInfo.maxXP) XP")
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
