//
//  AnalysisResult.swift
//  UniMarket-Swift
//
//  Created by AI Assistant on 17/03/26.
//

import Foundation

struct AnalysisResult: Codable {
    let category: String
    let colors: [String]
    let style: String?
    let pattern: String?
    let confidence: Double
    let processingTimeMs: Int
    let allTags: [ClothingTag]
    let timestamp: Date
    
    init(
        category: String,
        colors: [String],
        style: String?,
        pattern: String?,
        confidence: Double,
        processingTimeMs: Int,
        allTags: [ClothingTag],
        timestamp: Date = Date()
    ) {
        self.category = category
        self.colors = colors
        self.style = style
        self.pattern = pattern
        self.confidence = min(max(confidence, 0.0), 1.0)
        self.processingTimeMs = processingTimeMs
        self.allTags = allTags
        self.timestamp = timestamp
    }
    
    var confidencePercentage: Int {
        Int(confidence * 100)
    }
    
    var summaryText: String {
        var summary = "✅ Analysis Complete (\(processingTimeMs)ms)\n\n"
        summary += "Category: \(category)\n"
        
        if !colors.isEmpty {
            summary += "Colors: \(colors.joined(separator: ", "))\n"
        }
        
        if let style = style {
            summary += "Style: \(style)\n"
        }
        
        if let pattern = pattern {
            summary += "Pattern: \(pattern)\n"
        }
        
        summary += "Confidence: \(confidencePercentage)%"
        
        return summary
    }
}
