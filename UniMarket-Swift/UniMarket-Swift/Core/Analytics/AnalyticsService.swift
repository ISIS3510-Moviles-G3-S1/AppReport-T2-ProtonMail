import Foundation
import FirebaseAnalytics

protocol AnalyticsProviding {
    func track(_ event: AnalyticsEvent)
    func setUserID(_ userID: String?)
    func setUserProperty(_ value: String?, forName name: String)
    func reset()
}

final class AnalyticsService {
    static let shared = AnalyticsService()

    private let providers: [AnalyticsProviding]
    private let isDebugLoggingEnabled: Bool

    init(
        providers: [AnalyticsProviding] = [FirebaseAnalyticsProvider()],
        isDebugLoggingEnabled: Bool = true
    ) {
        self.providers = providers
        self.isDebugLoggingEnabled = isDebugLoggingEnabled
    }

    func track(_ event: AnalyticsEvent) {
        providers.forEach { $0.track(event) }

        guard isDebugLoggingEnabled else { return }
        let renderedParameters = event.parameters
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.debugValue)" }
            .joined(separator: ", ")

        if renderedParameters.isEmpty {
            print("[Analytics] \(event.name)")
        } else {
            print("[Analytics] \(event.name) {\(renderedParameters)}")
        }
    }

    func setUserID(_ userID: String?) {
        providers.forEach { $0.setUserID(userID) }
    }

    func setUserProperty(_ value: String?, forName name: String) {
        providers.forEach { $0.setUserProperty(value, forName: name) }
    }

    func reset() {
        providers.forEach { $0.reset() }
    }
}

struct FirebaseAnalyticsProvider: AnalyticsProviding {
    func track(_ event: AnalyticsEvent) {
        let parameters = event.parameters.reduce(into: [String: Any]()) { partialResult, entry in
            partialResult[entry.key] = entry.value.firebaseValue
        }
        Analytics.logEvent(event.name, parameters: parameters)
    }

    func setUserID(_ userID: String?) {
        Analytics.setUserID(userID)
    }

    func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    func reset() {
        Analytics.setUserID(nil)
        Analytics.setUserProperty(nil, forName: "email_domain")
        Analytics.setUserProperty(nil, forName: "email_verified")
    }
}
