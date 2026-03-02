//
//  HomeActionButtonsView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct HomeActionButtonsView: View {
    let onBrowseItems: () -> Void
    let onStartSelling: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button("Browse Items") {
                onBrowseItems()
            }
            .font(.poppinsSemiBold(22))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(AppTheme.accent)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            Button("Start Selling") {
                onStartSelling()
            }
            .font(.poppinsSemiBold(22))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .foregroundStyle(.black)
            .background(AppTheme.accentAlt.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.accent, lineWidth: 1.2)
            )

            HStack(spacing: 12) {
                smallButton(title: "Donate", icon: "gift") {
                }

                smallButton(title: "Swap", icon: "arrow.left.arrow.right") {
                }
            }
        }
    }

    private func smallButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                    .font(.poppinsSemiBold(14))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.accent.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
