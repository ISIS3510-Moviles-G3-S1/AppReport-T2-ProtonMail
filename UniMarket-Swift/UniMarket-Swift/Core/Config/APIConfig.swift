//
//  APIConfig.swift
//  UniMarket-Swift
//
//  Created by AI Assistant on 17/03/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

struct APIConfig {
    private static let keyName = "CLARIFAI_API_KEY"

    // Resolve on each access so an early empty read does not get cached for app lifetime.
    static var clarifaiAPIKey: String {
        resolvedKey(from: Bundle.main)
    }

    static let clarifaiBaseURL = "https://api.clarifai.com/v2"
    static var clarifaiUserID: String {
        (Bundle.main.object(forInfoDictionaryKey: "CLARIFAI_USER_ID") as? String) ?? ""
    }
    static var clarifaiAppID: String {
        (Bundle.main.object(forInfoDictionaryKey: "CLARIFAI_APP_ID") as? String) ?? ""
    }
    static var apparelModelID: String {
        (Bundle.main.object(forInfoDictionaryKey: "APPAREL_MODEL_ID") as? String) ?? ""
    }
    static let maxRequestsPerMonth = 5000
    static let requestTimeout: TimeInterval = 30.0
    static let maxImageSize = 10 * 1024 * 1024
    static let imageCompressionQuality: CGFloat = 0.8
    static let maxImageDimension: CGFloat = 1024

    static func isConfigured() -> Bool {
        !clarifaiAPIKey.isEmpty && !clarifaiUserID.isEmpty &&
        !clarifaiAppID.isEmpty && !apparelModelID.isEmpty
    }

    static func debugConfigurationState() -> String {
        let mainValue = (Bundle.main.object(forInfoDictionaryKey: keyName) as? String) ?? "<nil>"
        let testValue = (Bundle(for: BundleToken.self).object(forInfoDictionaryKey: keyName) as? String) ?? "<nil>"

        return """
        APIConfig debug:
        - main bundle id: \(Bundle.main.bundleIdentifier ?? "<nil>")
        - test bundle id: \(Bundle(for: BundleToken.self).bundleIdentifier ?? "<nil>")
        - main raw key: \(mainValue)
        - test raw key: \(testValue)
        - userID: \(clarifaiUserID)
        - appID: \(clarifaiAppID)
        - modelID: \(apparelModelID)
        - resolved configured: \(isConfigured())
        """
    }

    private static func isBuildSettingPlaceholder(_ value: String) -> Bool {
        (value.hasPrefix("$(") && value.hasSuffix(")")) ||
        (value.hasPrefix("${") && value.hasSuffix("}"))
    }

    private static func resolvedKey(from bundle: Bundle) -> String {
        let raw = (bundle.object(forInfoDictionaryKey: keyName) as? String) ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isBuildSettingPlaceholder(trimmed) else {
            return ""
        }
        return trimmed
    }

    private final class BundleToken {}
}
