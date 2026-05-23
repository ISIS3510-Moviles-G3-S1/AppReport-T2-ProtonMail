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
    /// Opens the upload sheet with kind=donation pre-selected.
    let onStartDonating: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button("Browse Items") {
                onBrowseItems()
            }
            .font(.poppinsSemiBold(15))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(AppTheme.accentAlt)
            .foregroundStyle(Color.black) // accentAlt is always a light fixed color — text must always be dark
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button("Start Selling") {
                onStartSelling()
            }
            .font(.poppinsSemiBold(15))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .foregroundStyle(AppTheme.primaryText)
            .background(AppTheme.background.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.accent, lineWidth: 1.2)
            )

            // Single secondary CTA — Donate. Swap/barter is not implemented in
            // the Swift app yet, so the previous "Swap" button was removed.
            smallButton(title: "Donate", icon: "gift", action: onStartDonating)
        }
    }

    private func smallButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                    .font(.poppinsSemiBold(14))
            }
            .foregroundStyle(AppTheme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.accent.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
