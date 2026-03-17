//
//  ClothingTag.swift
//  UniMarket-Swift
//
//  Created by AI Assistant on 17/03/26.
//

import Foundation

struct ClothingTag: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let confidence: Double
    let category: TagCategory
    
    enum TagCategory: String, Codable, Hashable {
        case category
        case color
        case style
        case pattern
        
        var displayName: String {
            switch self {
            case .category:
                "Item Type"
            case .color:
                "Color"
            case .style:
                "Style"
            case .pattern:
                "Pattern"
            }
        }
    }
    
    init(id: UUID = UUID(), name: String, confidence: Double, category: TagCategory) {
        self.id = id
        self.name = name
        self.confidence = min(max(confidence, 0.0), 1.0) // Clamp between 0 and 1
        self.category = category
    }
    
    var confidencePercentage: Int {
        Int(confidence * 100)
    }
}
