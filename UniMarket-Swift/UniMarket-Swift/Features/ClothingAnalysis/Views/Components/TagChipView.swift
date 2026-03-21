//
//  TagChipView.swift
//  UniMarket-Swift
//
//  Created by Felipe Mesa on 17/03/26.
//

import SwiftUI

struct TagChipView: View {
    let tag: ClothingTag
    var onRemove: ((UUID) -> Void)?
    
    var backgroundColor: Color {
        switch tag.category {
        case .category:
            return AppTheme.accent.opacity(0.2)
        case .color:
            return AppTheme.accentAlt.opacity(0.2)
        case .style:
            return Color.blue.opacity(0.2)
        case .pattern:
            return Color.purple.opacity(0.2)
        }
    }
    
    var textColor: Color {
        switch tag.category {
        case .category:
            return AppTheme.accent
        case .color:
            return AppTheme.accentAlt
        case .style:
            return Color.blue
        case .pattern:
            return Color.purple
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tag.name)
                    .font(.poppinsSemiBold(14))
                    .foregroundColor(AppTheme.primaryText)
                
                Text("\(tag.confidencePercentage)%")
                    .font(.poppinsRegular(12))
                    .foregroundColor(AppTheme.secondaryText)
            }
            
            Spacer()
            
            if let onRemove = onRemove {
                Button(action: { onRemove(tag.id) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(textColor.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        TagChipView(
            tag: ClothingTag(name: "Shirt", confidence: 0.95, category: .category),
            onRemove: { _ in }
        )
        
        TagChipView(
            tag: ClothingTag(name: "Blue", confidence: 0.87, category: .color)
        )
        
        TagChipView(
            tag: ClothingTag(name: "Casual", confidence: 0.92, category: .style),
            onRemove: { _ in }
        )
    }
    .padding()
}
