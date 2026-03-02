//
//  ProfileHeaderCard.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct ProfileHeaderCard: View {
    let profile: UserProfile

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.25))
                    .frame(width: 56, height: 56)
                Image(systemName: "person.fill")
                    .foregroundColor(.green)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(profile.name)
                    .font(.headline)

                Text("\(profile.university) • Member since \(profile.memberSince)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                        Text(String(format: "%.1f", profile.rating))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    Text("• \(profile.transactions) transactions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("\(profile.xp) XP Points")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                    .padding(.top, 2)
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
