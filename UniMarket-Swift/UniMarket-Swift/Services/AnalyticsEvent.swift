import Foundation

enum AnalyticsSurface: String {
    case browseSearch = "browse_search"
    case searchRecommendations = "search_recommendations"
    case productDetail = "product_detail"
    case aiStylist = "ai_stylist"
    case cart = "cart"
    case unknown = "unknown"
}

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
    private static func surfacePrefix(for source: String) -> String? {
        switch source {
        case AnalyticsSurface.browseSearch.rawValue:
            return "browse_search"
        case AnalyticsSurface.searchRecommendations.rawValue:
            return "search_recommendations"
        case AnalyticsSurface.aiStylist.rawValue:
            return "ai_stylist"
        default:
            return nil
        }
    }

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

    static func productSelected(productID: String, source: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "product_selected",
            parameters: [
                "product_id": .string(productID),
                "source": .string(source)
            ]
        )
    }

    static func aiStylistChatViewed(conversationID: String?, existingConversation: Bool) -> AnalyticsEvent {
        var parameters: [String: AnalyticsValue] = [
            "existing_conversation": .bool(existingConversation)
        ]
        if let conversationID {
            parameters["conversation_id"] = .string(conversationID)
        }

        return AnalyticsEvent(name: "ai_stylist_chat_viewed", parameters: parameters)
    }

    static func aiStylistPromptSent(
        conversationID: String?,
        promptLength: Int,
        hasReferenceImage: Bool,
        catalogCount: Int,
        mode: String
    ) -> AnalyticsEvent {
        var parameters: [String: AnalyticsValue] = [
            "prompt_length": .int(promptLength),
            "has_reference_image": .bool(hasReferenceImage),
            "catalog_count": .int(catalogCount),
            "mode": .string(mode)
        ]
        if let conversationID {
            parameters["conversation_id"] = .string(conversationID)
        }

        return AnalyticsEvent(name: "ai_stylist_prompt_sent", parameters: parameters)
    }

    static func aiStylistResponseReceived(
        conversationID: String?,
        responseSource: String,
        suggestedProductCount: Int,
        durationMs: Int
    ) -> AnalyticsEvent {
        var parameters: [String: AnalyticsValue] = [
            "response_source": .string(responseSource),
            "suggested_product_count": .int(suggestedProductCount),
            "duration_ms": .int(durationMs)
        ]
        if let conversationID {
            parameters["conversation_id"] = .string(conversationID)
        }

        return AnalyticsEvent(name: "ai_stylist_response_received", parameters: parameters)
    }

    static func aiStylistSuggestionSelected(
        conversationID: String?,
        messageID: String,
        productID: String,
        rank: Int,
        price: Int
    ) -> AnalyticsEvent {
        var parameters: [String: AnalyticsValue] = [
            "message_id": .string(messageID),
            "product_id": .string(productID),
            "rank": .int(rank),
            "price_bucket": .string(priceBucket(for: price))
        ]
        if let conversationID {
            parameters["conversation_id"] = .string(conversationID)
        }

        return AnalyticsEvent(name: "ai_stylist_suggestion_selected", parameters: parameters)
    }

    static func cartItemAdded(
        productID: String,
        price: Int,
        source: String,
        cartSize: Int,
        containsAIStylistItem: Bool
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "cart_item_added",
            parameters: [
                "product_id": .string(productID),
                "price_bucket": .string(priceBucket(for: price)),
                "source": .string(source),
                "cart_size": .int(cartSize),
                "contains_ai_stylist_item": .bool(containsAIStylistItem)
            ]
        )
    }

    static func cartItemAddRejected(productID: String, source: String, reason: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "cart_item_add_rejected",
            parameters: [
                "product_id": .string(productID),
                "source": .string(source),
                "reason": .string(reason)
            ]
        )
    }

    static func checkoutStarted(
        itemCount: Int,
        subtotal: Int,
        aiStylistItemCount: Int,
        aiStylistSubtotal: Int
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "checkout_started",
            parameters: [
                "item_count": .int(itemCount),
                "subtotal": .int(subtotal),
                "ai_stylist_item_count": .int(aiStylistItemCount),
                "ai_stylist_subtotal": .int(aiStylistSubtotal),
                "contains_ai_stylist_item": .bool(aiStylistItemCount > 0)
            ]
        )
    }

    static func demoOrderPlaced(
        orderNumber: String,
        itemCount: Int,
        subtotal: Int,
        aiStylistItemCount: Int,
        aiStylistSubtotal: Int,
        usedSavedPayment: Bool
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "demo_order_placed",
            parameters: [
                "order_number": .string(orderNumber),
                "item_count": .int(itemCount),
                "subtotal": .int(subtotal),
                "ai_stylist_item_count": .int(aiStylistItemCount),
                "ai_stylist_subtotal": .int(aiStylistSubtotal),
                "contains_ai_stylist_item": .bool(aiStylistItemCount > 0),
                "used_saved_payment": .bool(usedSavedPayment)
            ]
        )
    }

    static func productDetailViewed(
        productID: String,
        price: Int,
        condition: String,
        isOwnListing: Bool,
        source: String
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "product_detail_viewed",
            parameters: [
                "product_id": .string(productID),
                "price": .int(price),
                "condition": .string(condition),
                "is_own_listing": .bool(isOwnListing),
                "source": .string(source)
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

    static func surfaceFavoriteToggled(productID: String, isFavorite: Bool, source: String) -> AnalyticsEvent? {
        guard let prefix = surfacePrefix(for: source) else { return nil }

        return AnalyticsEvent(
            name: "\(prefix)_favorite_toggled",
            parameters: [
                "product_id": .string(productID),
                "is_favorite": .bool(isFavorite)
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

    /// BQ#1 buyer-intent funnel marker. See BQ.md / Wiki §7.
    static func chatStartedFromListing(
        productID: String,
        sellerID: String,
        price: Int,
        source: String
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "chat_started_from_listing",
            parameters: [
                "product_id": .string(productID),
                "seller_id": .string(sellerID),
                "price_bucket": .string(priceBucket(for: price)),
                "source": .string(source)
            ]
        )
    }

    /// Mirror of ProductService.priceBucket(for:); keep buckets identical.
    static func priceBucket(for price: Int) -> String {
        switch price {
        case ..<25_000:    return "under_25k"
        case 25_000..<50_000:  return "25k_50k"
        case 50_000..<100_000: return "50k_100k"
        default:           return "100k_plus"
        }
    }

    // MARK: - Notifications

    /// Fired when the concurrent aggregator completes a full refresh cycle.
    static func notificationsRefreshed(
        messageCount:   Int,
        priceDropCount: Int,
        syncCount:      Int,
        activityCount:  Int
    ) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "notifications_refreshed",
            parameters: [
                "message_count":    .int(messageCount),
                "price_drop_count": .int(priceDropCount),
                "sync_count":       .int(syncCount),
                "activity_count":   .int(activityCount),
                "total_count":      .int(messageCount + priceDropCount + syncCount + activityCount)
            ]
        )
    }

    /// Fired when the user taps a notification row and deep-links to a destination.
    static func notificationTapped(type: String, target: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "notification_tapped",
            parameters: [
                "notification_type": .string(type),
                "deep_link_target":  .string(target)
            ]
        )
    }

    // MARK: - Purchases

    static func purchaseConfirmed(productID: String, transactionID: String, source: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "purchase_confirmed",
            parameters: [
                "product_id": .string(productID),
                "transaction_id": .string(transactionID),
                "source": .string(source)
            ]
        )
    }

    static func surfaceProductDetailViewed(
        productID: String,
        price: Int,
        condition: String,
        isOwnListing: Bool,
        source: String
    ) -> AnalyticsEvent? {
        guard let prefix = surfacePrefix(for: source) else { return nil }

        return AnalyticsEvent(
            name: "\(prefix)_product_detail_viewed",
            parameters: [
                "product_id": .string(productID),
                "price": .int(price),
                "condition": .string(condition),
                "is_own_listing": .bool(isOwnListing)
            ]
        )
    }

    static func aiTaggingCompleted(durationMs: Int, tagCount: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "ai_tagging_completed",
            parameters: [
                "duration_ms": .int(durationMs),
                "tag_count": .int(tagCount)
            ]
        )
    }

    // MARK: - Watchlist Events (BQ#4)

    static func watchlistItemAdded(productID: String, category: String, originalPrice: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "watchlist_item_added",
            parameters: [
                "product_id": .string(productID),
                "category": .string(category),
                "original_price": .int(originalPrice)
            ]
        )
    }

    static func watchlistPriceDropDetected(productID: String, priceDelta: Int, category: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "watchlist_price_drop_detected",
            parameters: [
                "product_id": .string(productID),
                "price_delta": .int(priceDelta),
                "category": .string(category)
            ]
        )
    }

    // MARK: - Donation Events (BQ#3)

    static func donationListingCreated(listingID: String, category: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "donation_listing_created",
            parameters: [
                "listing_id": .string(listingID),
                "category": .string(category)
            ]
        )
    }

    static func donationBrowsed(countShown: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "donation_browsed",
            parameters: ["count_shown": .int(countShown)]
        )
    }

    static func donationClaimed(listingID: String, sellerID: String, timeSinceListingSeconds: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "donation_claimed",
            parameters: [
                "listing_id": .string(listingID),
                "seller_id": .string(sellerID),
                "time_since_listing_seconds": .int(timeSinceListingSeconds)
            ]
        )
    }

    static func donationApproved(listingID: String, requesterID: String, waitTimeSeconds: Int) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "donation_approved",
            parameters: [
                "listing_id": .string(listingID),
                "requester_id": .string(requesterID),
                "wait_time_seconds": .int(waitTimeSeconds)
            ]
        )
    }

    static func donationDeclined(listingID: String, requesterID: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "donation_declined",
            parameters: [
                "listing_id": .string(listingID),
                "requester_id": .string(requesterID)
            ]
        )
    }

    static func donationPickedUp(listingID: String) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "donation_picked_up",
            parameters: ["listing_id": .string(listingID)]
        )
    }
}
