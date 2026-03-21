import Foundation

struct AnalyticsEvent {
    let name: String
    let parameters: [String: AnalyticsValue]

    init(name: String, parameters: [String: AnalyticsValue] = [:]) {
        self.name = name
        self.parameters = parameters
    }
}

enum AnalyticsValue {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    var firebaseValue: Any {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .bool(let value):
            return value ? 1 : 0
        }
    }

    var debugValue: String {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(format: "%.2f", value)
        case .bool(let value):
            return value ? "true" : "false"
        }
    }
}

extension AnalyticsEvent {
    static func appOpened() -> AnalyticsEvent {
        AnalyticsEvent(name: "app_opened")
    }

    static func authScreenViewed() -> AnalyticsEvent {
        AnalyticsEvent(name: "auth_screen_viewed")
    }

    static func loginAttempt(method: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "login_attempt",
            parameters: ["method": .string(method)]
        )
    }

    static func loginSucceeded(method: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "login_succeeded",
            parameters: ["method": .string(method)]
        )
    }

    static func loginFailed(method: String, reason: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "login_failed",
            parameters: [
                "method": .string(method),
                "reason": .string(reason)
            ]
        )
    }

    static func registrationAttempt(method: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "registration_attempt",
            parameters: ["method": .string(method)]
        )
    }

    static func registrationSucceeded(method: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "registration_succeeded",
            parameters: ["method": .string(method)]
        )
    }

    static func registrationFailed(method: String, reason: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "registration_failed",
            parameters: [
                "method": .string(method),
                "reason": .string(reason)
            ]
        )
    }

    static func emailVerificationRequired() -> AnalyticsEvent {
        AnalyticsEvent(name: "email_verification_required")
    }

    static func signOut() -> AnalyticsEvent {
        AnalyticsEvent(name: "sign_out")
    }

    static func tabSelected(_ tab: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "tab_selected",
            parameters: ["tab": .string(tab)]
        )
    }

    static func searchViewed() -> AnalyticsEvent {
        AnalyticsEvent(name: "search_viewed")
    }

    static func searchQueryChanged(length: Int, hasQuery: Bool) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "search_query_changed",
            parameters: [
                "query_length": .int(length),
                "has_query": .bool(hasQuery)
            ]
        )
    }

    static func searchFiltersApplied(
        activeFilterCount: Int,
        selectedTag: String?,
        selectedConditionCount: Int,
        onlyFavorites: Bool,
        minRating: Double,
        sortOption: String
    ) -> AnalyticsEvent {
        var parameters: [String: AnalyticsValue] = [
            "filter_count": .int(activeFilterCount),
            "condition_count": .int(selectedConditionCount),
            "only_favorites": .bool(onlyFavorites),
            "min_rating": .double(minRating),
            "sort_option": .string(sortOption)
        ]

        if let selectedTag, !selectedTag.isEmpty {
            parameters["tag"] = .string(selectedTag)
        }

        return AnalyticsEvent(name: "search_filters_applied", parameters: parameters)
    }

    static func searchReset() -> AnalyticsEvent {
        AnalyticsEvent(name: "search_filters_reset")
    }

    static func productListViewed(source: String, resultCount: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "product_list_viewed",
            parameters: [
                "source": .string(source),
                "result_count": .int(resultCount)
            ]
        )
    }

    static func productDetailViewed(productID: String, price: Int, condition: String, isOwnListing: Bool) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "product_detail_viewed",
            parameters: [
                "product_id": .string(productID),
                "price": .int(price),
                "condition": .string(condition),
                "is_own_listing": .bool(isOwnListing)
            ]
        )
    }

    static func favoriteToggled(productID: String, isFavorite: Bool, source: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "favorite_toggled",
            parameters: [
                "product_id": .string(productID),
                "is_favorite": .bool(isFavorite),
                "source": .string(source)
            ]
        )
    }

    static func uploadScreenViewed() -> AnalyticsEvent {
        AnalyticsEvent(name: "upload_screen_viewed")
    }

    static func listingPhotosSelected(count: Int, source: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "listing_photos_selected",
            parameters: [
                "count": .int(count),
                "source": .string(source)
            ]
        )
    }

    static func listingPhotoRemoved(remainingCount: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "listing_photo_removed",
            parameters: ["remaining_count": .int(remainingCount)]
        )
    }

    static func listingSubmitAttempt(photoCount: Int, hasDescription: Bool, condition: String, priceBucket: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "listing_submit_attempt",
            parameters: [
                "photo_count": .int(photoCount),
                "has_description": .bool(hasDescription),
                "condition": .string(condition),
                "price_bucket": .string(priceBucket)
            ]
        )
    }

    static func listingSubmitSucceeded(productID: String, sellerID: String, photoCount: Int, priceBucket: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "listing_submit_succeeded",
            parameters: [
                "product_id": .string(productID),
                "seller_id": .string(sellerID),
                "photo_count": .int(photoCount),
                "price_bucket": .string(priceBucket)
            ]
        )
    }

    static func listingSubmitFailed(reason: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "listing_submit_failed",
            parameters: ["reason": .string(reason)]
        )
    }

    static func listingMarkedSold(productID: String, sellerID: String, priceBucket: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "listing_marked_sold",
            parameters: [
                "product_id": .string(productID),
                "seller_id": .string(sellerID),
                "price_bucket": .string(priceBucket)
            ]
        )
    }
}
