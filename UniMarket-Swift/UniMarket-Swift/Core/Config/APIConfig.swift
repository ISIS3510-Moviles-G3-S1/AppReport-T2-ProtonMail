//
//  APIConfig.swift
//  UniMarket-Swift
//
//  Created by AI Assistant on 17/03/26.
//

import Foundation

struct APIConfig {
    // MARK: - Clarifai Configuration
    /// API Key for Clarifai service
    /// ⚠️ IMPORTANT: Replace with your actual API key from https://clarifai.com/
    /// For production, store this in a secure location (e.g., secure enclave, backend service)
    static let clarifaiAPIKey: String = {
        // Try to read from Info.plist first (recommended for production)
        if let key = Bundle.main.infoDictionary?["CLARIFAI_API_KEY"] as? String,
           !key.isEmpty {
            return key
        }
        
        // Fallback to a default value (use for development/testing only)
        // Replace this with your actual API key
        return "YOUR_CLARIFAI_API_KEY_HERE"
    }()
    
    static let clarifaiBaseURL = "https://api.clarifai.com/v2"
    
    /// Clarifai Apparel Recognition Model ID
    static let apparelModelID = "e0be3b9d6a454f0493ac3a30784001ff"
    
    // MARK: - API Limits
    /// Free tier: 5000 operations/month
    /// Rate limiting should be implemented on the backend
    static let maxRequestsPerMonth = 5000
    
    // MARK: - Request Configuration
    /// Timeout for API requests (in seconds)
    static let requestTimeout: TimeInterval = 30.0
    
    /// Maximum image size for API requests (in bytes) - 10MB
    static let maxImageSize = 10 * 1024 * 1024
    
    // MARK: - Image Processing
    /// Compression quality for JPEG images (0.0 to 1.0)
    static let imageCompressionQuality: CGFloat = 0.8
    
    /// Maximum dimension for resizing images
    static let maxImageDimension: CGFloat = 1024
    
    // MARK: - Helper Methods
    
    /// Validates that the API key is configured
    static func isConfigured() -> Bool {
        clarifaiAPIKey != "YOUR_CLARIFAI_API_KEY_HERE" && !clarifaiAPIKey.isEmpty
    }
    
    /// Gets a user-friendly error message if API is not configured
    static func configurationErrorMessage() -> String {
        """
        Clarifai API is not configured.
        
        To set up the API key:
        1. Create a free account at https://clarifai.com/
        2. Get your API key from the settings
        3. Add it to Info.plist as 'CLARIFAI_API_KEY'
        
        For testing, you can also replace the default value in APIConfig.swift
        """
    }
}
