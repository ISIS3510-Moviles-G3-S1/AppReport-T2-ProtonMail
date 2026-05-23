import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit

// MARK: - Notification Names
extension Notification.Name {
    static let userDidCreateListing = Notification.Name("userDidCreateListing")
    static let userDidSellListing = Notification.Name("userDidSellListing")
    /// Posted by SessionManager.signOut() so caches keyed to the current user
    /// (e.g. WatchlistPriceCache) can flush their contents immediately.
    static let userDidSignOut = Notification.Name("userDidSignOut")
    /// Posted by NotificationAggregatorService when connectivity is restored
    /// so NotificationsView can re-trigger a refresh.
    static let notificationsReconnected = Notification.Name("notificationsReconnected")
}

struct CreateProductInput {
    let title: String
    let price: Int
    let conditionTag: String
    let description: String
    let imagesData: [Data]
    let tags: [String]
    let kind: ListingKind

    init(
        title: String,
        price: Int,
        conditionTag: String,
        description: String,
        imagesData: [Data],
        tags: [String],
        kind: ListingKind = .sale
    ) {
        self.title = title
        // Donations always have price 0 — enforce here so we can't accidentally
        // post a paid donation listing from any call site.
        self.price = kind == .donation ? 0 : price
        self.conditionTag = conditionTag
        self.description = description
        self.imagesData = imagesData
        self.tags = tags
        self.kind = kind
    }
}

final class ProductService {
    static let shared = ProductService()

    private let analytics = AnalyticsService.shared
    private let db = Firestore.firestore()
    private let collectionName = "listings"

    private init() {}

    func observeProducts(onChange: @escaping (Result<[Product], Error>) -> Void) -> ListenerRegistration {
        db.collection(collectionName)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    onChange(.success([]))
                    return
                }

                Task { @MainActor in
                    let products = documents.compactMap(Self.makeProduct(from:))
                    onChange(.success(products))
                }
            }
    }

    func createProduct(input: CreateProductInput) async throws -> Product {
        guard let currentUser = Auth.auth().currentUser else {
            throw ProductServiceError.notAuthenticated
        }

        // 1. Reserve the Firestore document ID first
        let document = db.collection(collectionName).document()
        let realListingID = document.documentID

        // 2. Upload images concurrently using the real listing ID. Each image becomes
        //    its own child Task so all uploads run in parallel; we tag each result
        //    with its original index and re-sort to preserve the user's chosen order.
        let imageURLs: [String] = try await withThrowingTaskGroup(of: (Int, String).self) { group in
            for (index, imageData) in input.imagesData.enumerated() {
                guard let uiImage = UIImage(data: imageData) else { continue }
                group.addTask {
                    let url = try await ImageUploadService.uploadListingImage(
                        uiImage,
                        listingId: realListingID,
                        index: index
                    )
                    return (index, url)
                }
            }
            var results: [(Int, String)] = []
            for try await pair in group {
                results.append(pair)
            }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }

        // 3. Write Firestore document with the correct image URLs
        let sellerName = resolvedSellerName(from: currentUser)
        let tags = makeTags(
            from: input.title,
            description: input.description,
            condition: input.conditionTag,
            userTags: input.tags
        )

        let data: [String: Any] = [
            "sellerId": currentUser.uid,
            "title": input.title,
            "price": input.price,
            "sellerName": sellerName,
            "conditionTag": input.conditionTag,
            "tags": tags,
            "rating": 0,
            "description": input.description,
            "createdAt": FieldValue.serverTimestamp(),
            "soldAt": NSNull(),
            "imagePath": imageURLs.first ?? NSNull(),
            "imageURLs": imageURLs,
            "status": ProductStatus.active.firestoreValue,
            // "kind" is read by both Swift and Flutter via the ListingKind enum.
            // Legacy docs without the field decode as .sale.
            "kind": input.kind.rawValue
        ]

        try await document.setData(data)
        let snapshot = try await document.getDocument()

        guard let product = Self.makeProduct(from: snapshot) else {
            throw ProductServiceError.invalidProductData
        }

        analytics.track(.listingSubmitSucceeded(
            productID: product.id,
            sellerID: product.sellerId,
            photoCount: input.imagesData.count,
            priceBucket: priceBucket(for: product.price)
        ))
        
        // Notify that user created a new listing
        NotificationCenter.default.post(name: .userDidCreateListing, object: nil)

        return product
    }

    func updateProduct(_ product: Product) async throws {
        let docRef = db.collection(collectionName).document(product.id)

        // Detect a fresh active -> sold transition *before* overwriting the doc, so
        // `listing_marked_sold` fires exactly once per sale. The incoming product
        // always carries a non-nil `soldAt` (Product.updatingSaleState sets it),
        // so the transition can only be inferred from the doc's previous status.
        var isNewSale = false
        if product.status == .sold {
            let existing = try? await docRef.getDocument()
            let previousStatus = existing?.data()?["status"] as? String
            isNewSale = ProductStatus(firestoreValue: previousStatus) != .sold
        }

        let soldAtValue: Any
        if product.status == .sold {
            soldAtValue = product.soldAt.map { Timestamp(date: $0) } ?? (FieldValue.serverTimestamp() as Any)
        } else {
            soldAtValue = NSNull()
        }

        try await docRef.updateData([
            "title": product.title,
            "price": product.price,
            "status": product.status.firestoreValue,
            "soldAt": soldAtValue
        ])

        if isNewSale {
            analytics.track(.listingMarkedSold(
                productID: product.id,
                sellerID: product.sellerId,
                priceBucket: priceBucket(for: product.price)
            ))
            FavoritesCacheManager.shared.saveLastInteraction()
            // Notify that user sold a listing
            NotificationCenter.default.post(name: .userDidSellListing, object: nil)
        }
    }

    // MARK: - Watchlist support

    /// Fetches only the current price for a single product document.
    /// Used by `WatchlistViewModel.refreshAllPrices()` so we make a minimal
    /// network read (one field) instead of deserialising the full product.
    func fetchCurrentPrice(for productID: String) async throws -> Int {
        let doc = try await db.collection(collectionName).document(productID).getDocument()
        guard let price = doc.data()?["price"] as? Int else {
            throw ProductServiceError.invalidProductData
        }
        return price
    }

    func deleteProduct(_ product: Product) async throws {
        // Delete all images from Storage concurrently. Individual failures are swallowed
        // (orphaned blobs are tolerable) so one bad URL doesn't block the others.
        await withTaskGroup(of: Void.self) { group in
            for rawValue in product.imageURLs {
                let candidate = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !candidate.isEmpty else { continue }
                group.addTask { [self] in
                    do {
                        let ref = try storageReference(from: candidate)
                        try await ref.delete()
                    } catch { }
                }
            }
        }

        // Delete Firestore document
        try await db.collection(collectionName).document(product.id).delete()
    }

    private func resolvedSellerName(from user: FirebaseAuth.User) -> String {
        let trimmedName = user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedName.isEmpty { return trimmedName }

        let emailName = user.email?
            .split(separator: "@")
            .first
            .map(String.init)?
            .replacingOccurrences(of: ".", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return emailName.isEmpty ? "Unknown seller" : emailName.capitalized
    }

    private func makeTags(from title: String, description: String, condition: String, userTags: [String]) -> [String] {
        let source = "\(title) \(description) \(condition)"
        let rawTokens = source
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }

        var seen = Set<String>()
        var tags: [String] = []

        for tag in userTags {
            let normalized = normalizeTag(tag)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { continue }
            tags.append(normalized)
            if tags.count == 8 { return tags }
        }

        for token in rawTokens where seen.insert(token).inserted {
            tags.append(token)
            if tags.count == 8 { break }
        }

        return tags
    }

    private func normalizeTag(_ tag: String) -> String {
        tag
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func priceBucket(for price: Int) -> String {
        switch price {
        case ..<25000:
            return "under_25k"
        case 25000..<50000:
            return "25k_50k"
        case 50000..<100000:
            return "50k_100k"
        default:
            return "100k_plus"
        }
    }

    nonisolated private func storageReference(from downloadURL: String) throws -> StorageReference {
        guard
            let url = URL(string: downloadURL),
            let encodedPath = url.pathComponents
                .drop(while: { $0 != "o" })  // find the "o" segment in the URL
                .dropFirst()                  // drop the "o" itself
                .first,
            let path = encodedPath.removingPercentEncoding
        else {
            throw ProductServiceError.invalidStorageURL(downloadURL)
        }

        return Storage.storage().reference(withPath: path)
    }
    
    private static func makeProduct(from document: DocumentSnapshot) -> Product? {
        let data = document.data() ?? [:]

        guard
            let title = data["title"] as? String,
            let price = data["price"] as? Int
        else { return nil }

        let createdAtTimestamp = data["createdAt"] as? Timestamp
        let soldAtTimestamp = data["soldAt"] as? Timestamp
        let imageURLs = data["imageURLs"] as? [String] ?? []

        return Product(
            id: document.documentID,
            sellerId: data["sellerId"] as? String ?? "",
            title: title,
            price: price,
            sellerName: data["sellerName"] as? String ?? "Unknown seller",
            conditionTag: data["conditionTag"] as? String ?? "Good",
            tags: data["tags"] as? [String] ?? [],
            rating: data["rating"] as? Double ?? 0,
            isFavorite: false,
            description: data["description"] as? String ?? "",
            createdAt: createdAtTimestamp?.dateValue() ?? .now,
            soldAt: soldAtTimestamp?.dateValue(),
            imagePath: data["imagePath"] as? String,
            imageURLs: imageURLs,
            status: ProductStatus(firestoreValue: data["status"] as? String)
        )
    }
}

// MARK: - Errors

enum ProductServiceError: LocalizedError {
    case notAuthenticated
    case invalidProductData
    case invalidStorageURL(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to publish a product."
        case .invalidProductData:
            return "The product could not be loaded after saving."
        case .invalidStorageURL(let value):
            return "One of the listing images has an invalid URL: \(value)"
        }
    }
}
