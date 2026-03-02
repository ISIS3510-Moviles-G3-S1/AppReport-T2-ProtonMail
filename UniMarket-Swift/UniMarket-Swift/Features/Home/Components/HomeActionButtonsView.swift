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
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green.opacity(0.6))
            .foregroundColor(.white)
            .cornerRadius(25)

            Button("Start Selling") {
                onStartSelling()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.green, lineWidth: 1)
            )

            HStack(spacing: 12) {
                smallButton(title: "Donate", icon: "gift") {
                    // luego lo conectamos
                }
                smallButton(title: "Swap", icon: "arrow.left.arrow.right") {
                    // luego lo conectamos
                }
            }
        }
    }

    private func smallButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.green.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
