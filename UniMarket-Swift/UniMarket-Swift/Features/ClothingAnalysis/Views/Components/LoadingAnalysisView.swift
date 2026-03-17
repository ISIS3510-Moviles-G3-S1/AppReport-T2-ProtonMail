//
//  LoadingAnalysisView.swift
//  UniMarket-Swift
//
//  Created by AI Assistant on 17/03/26.
//

import SwiftUI

struct LoadingAnalysisView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Animated spinner
            VStack {
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(AppTheme.background, lineWidth: 8)
                        .frame(width: 80, height: 80)
                    
                    // Animated progress circle
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [AppTheme.accent, AppTheme.accentAlt]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
                }
            }
            
            VStack(spacing: 12) {
                Text("Analyzing your item...")
                    .font(.poppinsSemiBold(18))
                    .foregroundColor(AppTheme.primaryText)
                
                Text("AI is identifying material, color, and style")
                    .font(.poppinsRegular(14))
                    .foregroundColor(AppTheme.secondaryText)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    LoadingAnalysisView()
}
