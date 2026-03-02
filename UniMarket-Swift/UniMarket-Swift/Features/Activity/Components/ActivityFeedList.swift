//
//  ActivityFeedList.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct ActivityFeedList: View {
    let items: [String]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.35))
                        .frame(width: 10, height: 10)
                        .padding(.top, 6)

                    Text(item)
                        .font(.poppinsRegular(14))
                        .foregroundStyle(AppTheme.primaryText)

                    Spacer()
                }
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(.top, 8)
    }
}
