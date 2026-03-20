//
//  ClothingAnalysisViewModel.swift
//  UniMarket-Swift
//
//  Created by AI Assistant on 17/03/26.
//

import Foundation
import UIKit
import Combine

class ClothingAnalysisViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isAnalyzing = false
    @Published var analysisResult: AnalysisResult?
    @Published var errorMessage: String?
    @Published var processingTimeMs: Int = 0
    @Published var selectedImage: UIImage?
    @Published var editableTags: [ClothingTag] = []
    
    // MARK: - Private Properties
    private let coreMLFacade = CoreMLAnalysisFacade()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Analyzes a clothing image and updates view state using Core ML
    /// - Parameter image: The UIImage to analyze
    func analyzeImage(_ image: UIImage) {
        selectedImage = image
        isAnalyzing = true
        errorMessage = nil
        
        Task {
            do {
                // Use Core ML facade for image analysis (100% offline, no API calls)
                let result = try await coreMLFacade.analyzeImage(image)
                
                // Update state on main thread
                await MainActor.run {
                    self.analysisResult = result
                    self.processingTimeMs = result.processingTimeMs
                    self.editableTags = result.allTags
                    self.isAnalyzing = false
                }
            } catch let error as AnalysisError {
                await MainActor.run {
                    self.errorMessage = error.errorDescription ?? "Unknown error occurred"
                    self.isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isAnalyzing = false
                }
            }
        }
    }
    
    /// Retries the analysis with the current image
    func retryAnalysis() {
        guard let image = selectedImage else {
            errorMessage = "No image selected"
            return
        }
        analyzeImage(image)
    }
    
    /// Clears all analysis results
    func clearResults() {
        selectedImage = nil
        analysisResult = nil
        errorMessage = nil
        processingTimeMs = 0
        editableTags = []
        isAnalyzing = false
    }
    
    /// Updates a specific tag
    /// - Parameters:
    ///   - tag: The tag to update
    ///   - remove: If true, removes the tag; if false, updates it
    func updateTag(_ tag: ClothingTag, remove: Bool = false) {
        if remove {
            editableTags.removeAll { $0.id == tag.id }
        } else {
            if let index = editableTags.firstIndex(where: { $0.id == tag.id }) {
                editableTags[index] = tag
            }
        }
    }
    
    /// Removes a tag by ID
    func removeTag(withId id: UUID) {
        editableTags.removeAll { $0.id == id }
    }
    
    /// Gets tags grouped by category
    var tagsByCategory: [ClothingTag.TagCategory: [ClothingTag]] {
        Dictionary(grouping: editableTags, by: { $0.category })
    }
    
    /// Prepares final tags for creating a listing
    /// - Returns: Dictionary with categorized tags ready for listing creation
    func prepareFinalTags() -> [String: [String]] {
        var finalTags: [String: [String]] = [:]
        
        for (category, tags) in tagsByCategory {
            finalTags[category.rawValue] = tags.map { $0.name }
        }
        
        return finalTags
    }
    
    // MARK: - Analytics & Logging
    
    /// Logs the analysis event for analytics
    func logAnalyticsEvent() {
        guard let result = analysisResult else { return }
        
        let event: [String: Any] = [
            "event": "clothing_analysis_completed",
            "processing_time_ms": result.processingTimeMs,
            "category": result.category,
            "colors_count": result.colors.count,
            "total_tags": result.allTags.count,
            "confidence": result.confidencePercentage,
            "timestamp": result.timestamp.timeIntervalSince1970
        ]
        
        // TODO: Send to analytics service
        print("📊 Analytics Event: \(event)")
    }
    
    /// Logs when user confirms and proceeds with the listing
    func logListingCreationStart() {
        let event: [String: Any] = [
            "event": "listing_creation_with_ai_tags",
            "tags_count": editableTags.count,
            "processing_time_ms": processingTimeMs
        ]
        
        // TODO: Send to analytics service
        print("📊 Analytics Event: \(event)")
    }
}

// MARK: - View State Helpers
extension ClothingAnalysisViewModel {
    
    var hasAnalysisResults: Bool {
        analysisResult != nil
    }
    
    var hasError: Bool {
        errorMessage != nil
    }
    
    var mainCategoryTag: ClothingTag? {
        editableTags.first { $0.category == .category }
    }
    
    var colorTags: [ClothingTag] {
        editableTags.filter { $0.category == .color }
    }
    
    var styleTags: [ClothingTag] {
        editableTags.filter { $0.category == .style }
    }
    
    var patternTags: [ClothingTag] {
        editableTags.filter { $0.category == .pattern }
    }
}
