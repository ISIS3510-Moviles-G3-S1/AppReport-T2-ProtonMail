//
//  LoadingView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//


import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppTheme.accent)
        }
    }
}

#Preview {
    LoadingView()
}
