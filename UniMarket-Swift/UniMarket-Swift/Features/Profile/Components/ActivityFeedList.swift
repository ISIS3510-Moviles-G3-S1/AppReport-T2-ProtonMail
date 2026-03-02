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
                        .fill(Color.green.opacity(0.35))
                        .frame(width: 10, height: 10)
                        .padding(.top, 6)

                    Text(item)
                        .font(.subheadline)

                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.10))
                .cornerRadius(16)
            }
        }
        .padding(.top, 8)
    }
}
