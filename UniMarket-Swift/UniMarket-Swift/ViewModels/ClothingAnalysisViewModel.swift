//
//  ClothingAnalysisViewModel.swift
//  UniMarket-Swift
//
//  Created by FELIPE MESA on 17/03/26.
//

import Foundation
import UIKit
import Combine

// @MainActor guarantees all @Published property mutations happen on the main thread,
// satisfying SwiftUI's requirement that ObservableObject updates are on the main thread.
@MainActor
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
        
        // Task.detached runs on a background executor (not @MainActor), making the
        // I/O context explicit. All UI mutations hop back via await MainActor.run.
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let start = Date()
            do {
                let result = try await self.coreMLFacade.analyzeImage(image)
                let durationMs = Int(Date().timeIntervalSince(start) * 1000)

                await AnalyticsService.shared.track(.aiTaggingCompleted(durationMs: durationMs, tagCount: result.allTags.count))

                await MainActor.run {
                    self.analysisResult = result
                    self.processingTimeMs = result.processingTimeMs
                    self.editableTags = result.allTags
                    self.isAnalyzing = false
                }
            } catch let error as AnalysisError {
                let durationMs = Int(Date().timeIntervalSince(start) * 1000)
                await AnalyticsService.shared.track(.aiTaggingCompleted(durationMs: durationMs, tagCount: 0))
                await MainActor.run {
                    self.errorMessage = error.errorDescription ?? "Unknown error occurred"
                    self.isAnalyzing = false
                }
            } catch {
                let durationMs = Int(Date().timeIntervalSince(start) * 1000)
                await AnalyticsService.shared.track(.aiTaggingCompleted(durationMs: durationMs, tagCount: 0))
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
            } else {
                editableTags.append(tag)
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
        AnalyticsService.shared.track(.aiTaggingCompleted(durationMs: result.processingTimeMs, tagCount: result.allTags.count))
    }

    /// Logs when user confirms and proceeds with the listing
    func logListingCreationStart() {
        AnalyticsService.shared.track(
            .aiTaggingCompleted(durationMs: processingTimeMs, tagCount: editableTags.count)
        )
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

    var seasonTags: [ClothingTag] {
        editableTags.filter { $0.category == .season }
    }
}
