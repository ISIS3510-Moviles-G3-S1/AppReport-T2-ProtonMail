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
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(profile.levelTitle)
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Next up")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(profile.nextLevelTitle)
                        .font(.headline)
                        .multilineTextAlignment(.trailing)
                    Text("\(profile.xpToNext) XP to go")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 12)

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.7))
                    .frame(width: max(12, CGFloat(progress) * 280), height: 12)
            }

            HStack {
                Text("\(profile.levelMinXP) XP")
                Spacer()
                Text("\(profile.xp) XP")
                    .fontWeight(.semibold)
                Spacer()
                Text("\(profile.levelMaxXP) XP")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.background)
                .shadow(radius: 6)
        )
    }
}
