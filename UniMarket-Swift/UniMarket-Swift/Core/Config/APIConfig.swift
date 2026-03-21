//
//  APIConfig.swift
//  UniMarket-Swift
//
//  Created by Felipe Mesa on 17/03/26.
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

struct APIConfig {
    private static let openRouterKeyName = "OpenRouterAPI"

    static var openRouterAPIKey: String {
        resolvedKey(from: Bundle.main, keyName: openRouterKeyName)
    }

    static let openRouterBaseURL = "https://openrouter.ai/api/v1/chat/completions"

    static var openRouterModel: String {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_MODEL") as? String) ?? "openai/gpt-oss-120b"
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "openai/gpt-oss-120b" : trimmed
    }
    static var openRouterReferer: String {
        ((Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_REFERER") as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static var openRouterTitle: String {
        ((Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_TITLE") as? String) ?? "UniMarket-Swift")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static let maxRequestsPerMonth = 5000
    static let requestTimeout: TimeInterval = 30.0
    static let maxImageSize = 10 * 1024 * 1024
    static let imageCompressionQuality: CGFloat = 0.8
    static let maxImageDimension: CGFloat = 1024

    static func isOpenRouterConfigured() -> Bool {
        !openRouterAPIKey.isEmpty
    }

    private static func isBuildSettingPlaceholder(_ value: String) -> Bool {
        (value.hasPrefix("$(") && value.hasSuffix(")")) ||
        (value.hasPrefix("${") && value.hasSuffix("}"))
    }

    private static func resolvedKey(from bundle: Bundle, keyName: String) -> String {
        let raw = (bundle.object(forInfoDictionaryKey: keyName) as? String) ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isBuildSettingPlaceholder(trimmed) else {
            return ""
        }
        return trimmed
    }

    private final class BundleToken {}
}
