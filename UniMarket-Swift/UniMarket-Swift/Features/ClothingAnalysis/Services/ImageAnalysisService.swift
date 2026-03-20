//
//  ImageAnalysisService.swift
//  UniMarket-Swift
//
//  Created by AI Assistant on 19/03/26.
//

import UIKit

/// Protocol defining the interface for any image analysis service
/// Allows for different implementations (was: Clarifai, now: Core ML)
protocol ImageAnalysisService {
    func analyzeImage(_ image: UIImage) async throws -> AnalysisResult
}

/// Core ML implementation conforming to ImageAnalysisService protocol
extension CoreMLAnalysisFacade: ImageAnalysisService {}
