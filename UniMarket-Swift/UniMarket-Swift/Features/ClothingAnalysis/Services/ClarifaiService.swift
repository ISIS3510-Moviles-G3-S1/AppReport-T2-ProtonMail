//
//  ClarifaiService.swift
//  UniMarket-Swift
//
//  Created by AI Assistant on 17/03/26.
//

import Foundation
import UIKit

// MARK: - Protocol for Testability
protocol ImageAnalysisService {
    func analyzeImage(_ image: UIImage) async throws -> AnalysisResult
}

// MARK: - Clarifai Service Implementation
class ClarifaiService: NSObject, ImageAnalysisService {
    private let session: URLSession
    private let decoder = JSONDecoder()

    // MARK: - Initialization
    override init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.requestTimeout
        config.timeoutIntervalForResource = APIConfig.requestTimeout
        self.session = URLSession(configuration: config)
        super.init()
    }

    // MARK: - Main Analysis Method
    /// Analyzes a clothing image and returns structured analysis result
    /// - Parameter image: The UIImage to analyze
    /// - Returns: AnalysisResult containing tags and processing time
    /// - Throws: ClarifaiServiceError for various failure scenarios
    func analyzeImage(_ image: UIImage) async throws -> AnalysisResult {
        let startTime = Date()

        // Validate configuration
        guard APIConfig.isConfigured() else {
            #if DEBUG
            throw ClarifaiServiceError.notConfigured(
                "Clarifai API key is not configured.\n\(APIConfig.debugConfigurationState())"
            )
            #else
            throw ClarifaiServiceError.notConfigured("Clarifai API key is not configured")
            #endif
        }

        // Prepare image
        let processedImage = try preprocessImage(image)
        let imageBase64 = try encodeImageToBase64(processedImage)
        let request = try buildRequest(with: imageBase64)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw mapNetworkError(error)
        }

        // Validate response
        try validateResponse(response, data: data)

        // Parse response
        let result = try parseResponse(data, processingStartTime: startTime)

        return result
    }

    // MARK: - Private Methods

    /// Preprocesses the image: resizes and optimizes for API
    private func preprocessImage(_ image: UIImage) throws -> UIImage {
        let maxDimension = APIConfig.maxImageDimension

        if image.size.width > maxDimension || image.size.height > maxDimension {
            return resizeImage(image, maxDimension: maxDimension)
        }

        return image
    }

    /// Resizes image to fit within max dimension while maintaining aspect ratio
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let aspectRatio = image.size.width / image.size.height

        let newWidth: CGFloat
        let newHeight: CGFloat

        if aspectRatio > 1 {
            newWidth = maxDimension
            newHeight = maxDimension / aspectRatio
        } else {
            newHeight = maxDimension
            newWidth = maxDimension * aspectRatio
        }

        let newSize = CGSize(width: newWidth, height: newHeight)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage ?? image
    }

    /// Encodes UIImage to Base64 string
    private func encodeImageToBase64(_ image: UIImage) throws -> String {
        let maxBytes = APIConfig.maxImageSize
        var quality = APIConfig.imageCompressionQuality
        let minQuality: CGFloat = 0.2
        let step: CGFloat = 0.1

        var bestData: Data?

        while quality >= minQuality {
            guard let jpegData = image.jpegData(compressionQuality: quality) else {
                throw ClarifaiServiceError.imageEncodingFailed
            }

            #if DEBUG
            print("📷 Clarifai image encode quality=\(String(format: "%.1f", quality)) size=\(jpegData.count) bytes")
            #endif

            if jpegData.count <= maxBytes {
                bestData = jpegData
                break
            }

            quality -= step
        }

        guard let finalData = bestData else {
            throw ClarifaiServiceError.imageTooLarge
        }

        return finalData.base64EncodedString()
    }
    /// Builds URLRequest for Clarifai API
    private func buildRequest(with base64Image: String) throws -> URLRequest {
        guard let url = URL(string: "\(APIConfig.clarifaiBaseURL)/users/\(APIConfig.clarifaiUserID)/apps/\(APIConfig.clarifaiAppID)/models/\(APIConfig.apparelModelID)/outputs") else {
            throw ClarifaiServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Key \(APIConfig.clarifaiAPIKey)", forHTTPHeaderField: "Authorization")

        // Build request body
        let requestBody: [String: Any] = [
            "inputs": [
                [
                    "data": [
                        "image": [
                            "base64": base64Image
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        return request
    }

    /// Validates HTTP response
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClarifaiServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 400:
            let rawMessage = String(data: data, encoding: .utf8) ?? "no body"
            print("❌ 400 Bad Request body: \(rawMessage)")
            throw ClarifaiServiceError.badRequest(details: extractServerMessage(from: data))
        case 404:                                                          // ← ADD THIS
            let rawMessage = String(data: data, encoding: .utf8) ?? "no body"
            print("❌ 404 Not Found — URL may be wrong: \(rawMessage)")
            throw ClarifaiServiceError.httpError(status: 404)
        case 401, 403:
            throw ClarifaiServiceError.unauthorized
        case 402:
            let rawMessage = String(data: data, encoding: .utf8) ?? "no body"
            print("❌ 402 Payment Required: \(rawMessage)")
            throw ClarifaiServiceError.httpError(status: 402)
        case 429:
            throw ClarifaiServiceError.rateLimitExceeded
        case 500...599:
            throw ClarifaiServiceError.serverError
        default:
            throw ClarifaiServiceError.httpError(status: httpResponse.statusCode)
        }
    }

    private func extractServerMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let status = json["status"] as? [String: Any],
           let description = status["description"] as? String,
           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return description
        }

        let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return text?.isEmpty == false ? text : nil
    }

    private func mapNetworkError(_ error: Error) -> ClarifaiServiceError {
        let nsError = error as NSError
        let code = URLError.Code(rawValue: nsError.code)

        switch code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return .noInternet
        case .timedOut:
            return .requestTimedOut
        default:
            return .networkError(error)
        }
    }

    /// Parses Clarifai API response
    private func parseResponse(_ data: Data, processingStartTime: Date) throws -> AnalysisResult {
        let processingTimeMs = Int(Date().timeIntervalSince(processingStartTime) * 1000)

        let apiResponse = try decoder.decode(ClarifaiAPIResponse.self, from: data)

        guard let outputs = apiResponse.outputs, !outputs.isEmpty else {
            throw ClarifaiServiceError.noResults
        }

        guard let conceptsOutput = outputs.first,
              let data = conceptsOutput.data,
              let concepts = data.concepts else {
            throw ClarifaiServiceError.malformedResponse
        }

        // Categorize concepts into tags
        var tags: [ClothingTag] = []
        var categoryTag: String = "Unknown"
        var colors: [String] = []
        var style: String?
        var pattern: String?
        var highestConfidence: Double = 0.0

        // Define tag categories
        let categoryKeywords = ["shirt", "pants", "dress", "shoes", "jacket", "coat", "sweater",
                               "blouse", "skirt", "shorts", "jeans", "top", "vest", "hoodie",
                               "cardigan", "blazer", "suit", "scarf", "hat", "belt"]
        let colorKeywords = ["red", "blue", "green", "black", "white", "yellow", "pink", "purple",
                            "orange", "brown", "gray", "grey", "navy", "beige", "tan", "gold",
                            "silver", "lime", "teal", "magenta", "turquoise"]
        let styleKeywords = ["casual", "formal", "vintage", "sporty", "elegant", "bohemian",
                            "classic", "modern", "retro", "streetwear", "preppy", "edgy",
                            "romantic", "minimalist", "loud", "bold", "minimalistic"]
        let patternKeywords = ["striped", "solid", "floral", "checkered", "dotted", "plaid",
                              "paisley", "geometric", "animal", "tie-dye", "ombre", "gradient",
                              "abstract", "polka", "print", "patterned"]

        // Process concepts
        for concept in concepts {
            let name = concept.name.lowercased()
            let confidence = concept.value

            highestConfidence = max(highestConfidence, confidence)

            let tag: ClothingTag

            if categoryKeywords.contains(name) {
                tag = ClothingTag(name: concept.name, confidence: confidence, category: .category)
                categoryTag = concept.name
            } else if colorKeywords.contains(name) {
                tag = ClothingTag(name: concept.name, confidence: confidence, category: .color)
                if confidence > 0.5 && !colors.contains(concept.name) {
                    colors.append(concept.name.capitalized)
                }
            } else if styleKeywords.contains(name) {
                tag = ClothingTag(name: concept.name, confidence: confidence, category: .style)
                if confidence > 0.5 && style == nil {
                    style = concept.name.capitalized
                }
            } else if patternKeywords.contains(name) {
                tag = ClothingTag(name: concept.name, confidence: confidence, category: .pattern)
                if confidence > 0.5 && pattern == nil {
                    pattern = concept.name.capitalized
                }
            } else {
                continue
            }

            tags.append(tag)
        }

        // Log analytics
        logAnalytics(processingTimeMs: processingTimeMs,
                    tagsDetected: tags.count,
                    confidence: highestConfidence)

        let result = AnalysisResult(
            category: categoryTag,
            colors: colors.isEmpty ? ["Unknown"] : colors,
            style: style,
            pattern: pattern,
            confidence: highestConfidence,
            processingTimeMs: processingTimeMs,
            allTags: tags,
            timestamp: Date()
        )

        return result
    }

    /// Logs analytics data for telemetry
    private func logAnalytics(processingTimeMs: Int, tagsDetected: Int, confidence: Double) {
        print("📊 Image analysis completed in \(processingTimeMs)ms")
        print("📊 Confidence score: \(Int(confidence * 100))%")
        print("📊 Tags detected: \(tagsDetected)")
    }
}

// MARK: - Error Types
enum ClarifaiServiceError: LocalizedError {
    case notConfigured(String)
    case invalidURL
    case imageEncodingFailed
    case imageTooLarge
    case invalidResponse
    case badRequest(details: String?)
    case unauthorized
    case rateLimitExceeded
    case serverError
    case httpError(status: Int)
    case noResults
    case malformedResponse
    case requestTimedOut
    case noInternet
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let message):
            return message
        case .invalidURL:
            return "Invalid API URL configuration"
        case .imageEncodingFailed:
            return "Failed to encode image"
        case .imageTooLarge:
            return "Image is too large (max 10MB)"
        case .invalidResponse:
            return "Invalid response from server"
        case .badRequest(let details):
            if let details, !details.isEmpty {
                return "Bad request: \(details)"
            }
            return "Bad request. Please check your image and try again"
        case .unauthorized:
            return "Unauthorized. Please check your API key configuration"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Free tier allows 5000 operations/month"
        case .serverError:
            return "Server error. Please try again later"
        case .httpError(let status):
            return "HTTP Error \(status). Please try again later"
        case .noResults:
            return "No analysis results returned. Try a clearer image"
        case .malformedResponse:
            return "Invalid response format from server"
        case .requestTimedOut:
            return "Request timed out. Please try again"
        case .noInternet:
            return "No internet connection. Please check your network and try again"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notConfigured:
            return "Set up your Clarifai API key in Config.xcconfig and map it in Info.plist as CLARIFAI_API_KEY = $(CLARIFAI_API_KEY)"
        case .imageTooLarge:
            return "Use a smaller image file"
        case .unauthorized:
            return "Check your API key configuration"
        case .rateLimitExceeded:
            return "You've reached the monthly limit. Try again next month"
        case .requestTimedOut, .noInternet:
            return "Try again when your connection is stable"
        default:
            return "Please try again"
        }
    }
}

// MARK: - API Response Models
private struct ClarifaiAPIResponse: Codable {
    let outputs: [ClarifaiOutput]?
    let status: ClarifaiStatus?
}

private struct ClarifaiOutput: Codable {
    let data: ClarifaiData?
}

private struct ClarifaiData: Codable {
    let concepts: [ClarifaiConcept]?
}

private struct ClarifaiConcept: Codable {
    let name: String
    let value: Double
}

private struct ClarifaiStatus: Codable {
    let code: Int?
    let description: String?
}
