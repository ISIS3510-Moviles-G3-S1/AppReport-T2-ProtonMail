//
//  AnalysisError.swift
//  UniMarket-Swift
//
//  Created by Felipe Mesa on 19/03/26.
//

import Foundation

/// Errors that can occur during clothing image analysis using Core ML
enum AnalysisError: LocalizedError {
    case modelLoadFailed
    case invalidImage
    case noResults
    case processingFailed(String)
    case colorExtractionFailed
    
    var errorDescription: String? {
        switch self {
        case .modelLoadFailed:
            return "Failed to load ML model"
        case .invalidImage:
            return "Invalid or corrupt image format"
        case .noResults:
            return "No classification results returned"
        case .processingFailed(let reason):
            return "Image processing failed: \(reason)"
        case .colorExtractionFailed:
            return "Failed to extract colors from image"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .modelLoadFailed:
            return "Please restart the app to reload the ML model"
        case .invalidImage:
            return "Try selecting a different image file"
        case .noResults:
            return "Try a clearer or larger image of clothing"
        case .processingFailed:
            return "Please try again, or try a different image"
        case .colorExtractionFailed:
            return "Try a different image with clearer colors"
        }
    }
}
