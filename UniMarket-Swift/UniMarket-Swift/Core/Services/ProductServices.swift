import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

struct CreateProductInput {
    let title: String
    let price: Int
    let conditionTag: String
    let description: String
    let imageURLs: [String]
}

final class ProductService {
    static let shared = ProductService()

    private let db = Firestore.firestore()
    private let collectionName = "products"

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

        let document = db.collection(collectionName).document()
        let sellerName = resolvedSellerName(from: currentUser)
        let tags = makeTags(from: input.title, description: input.description, condition: input.conditionTag)
        let primaryImageURL = input.imageURLs.first

        let data: [String: Any] = [
            "sellerId": currentUser.uid,
            "title": input.title,
            "price": input.price,
            "sellerName": sellerName,
            "conditionTag": input.conditionTag,
            "tags": tags,
            "rating": 0,
            "imageName": "",
            "description": input.description,
            "createdAt": FieldValue.serverTimestamp(),
            "soldAt": NSNull(),
            "imagePath": primaryImageURL as Any,
            "imageURLs": input.imageURLs,
            "status": ProductStatus.active.rawValue
        ]

        try await document.setData(data)
        let snapshot = try await document.getDocument()

        guard let product = Self.makeProduct(from: snapshot) else {
            throw ProductServiceError.invalidProductData
        }

        return product
    }

    func updateProduct(_ product: Product) async throws {
        try await db.collection(collectionName).document(product.id).updateData([
            "title": product.title,
            "price": product.price,
            "status": product.status.rawValue
        ])
    }

    func deleteProduct(_ product: Product) async throws {
        for imageURL in product.imageURLs where !imageURL.isEmpty {
            try? await ImageUploadService.deleteImage(at: imageURL)
        }

        try await db.collection(collectionName).document(product.id).delete()
    }

    private func resolvedSellerName(from user: FirebaseAuth.User) -> String {
        let trimmedName = user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedName.isEmpty {
            return trimmedName
        }

        let emailName = user.email?
            .split(separator: "@")
            .first
            .map(String.init)?
            .replacingOccurrences(of: ".", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return emailName.isEmpty ? "Unknown seller" : emailName.capitalized
    }

    private func makeTags(from title: String, description: String, condition: String) -> [String] {
        let source = "\(title) \(description) \(condition)"
        let rawTokens = source
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }

        var seen = Set<String>()
        var tags: [String] = []

        for token in rawTokens where seen.insert(token).inserted {
            tags.append(token)
            if tags.count == 8 {
                break
            }
        }

        return tags
    }

    private static func makeProduct(from document: DocumentSnapshot) -> Product? {
        let data = document.data() ?? [:]

        guard
            let title = data["title"] as? String,
            let price = data["price"] as? Int
        else {
            return nil
        }

        let createdAtTimestamp = data["createdAt"] as? Timestamp
        let soldAtTimestamp = data["soldAt"] as? Timestamp
        let imageURLs = data["imageURLs"] as? [String] ?? []
        let statusRawValue = data["status"] as? String ?? ProductStatus.active.rawValue

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
            imageName: data["imageName"] as? String ?? "",
            description: data["description"] as? String ?? "",
            createdAt: createdAtTimestamp?.dateValue() ?? .now,
            soldAt: soldAtTimestamp?.dateValue(),
            imagePath: data["imagePath"] as? String,
            imageURLs: imageURLs,
            status: ProductStatus(rawValue: statusRawValue) ?? .active
        )
    }
}

@MainActor
final class ProductStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service: ProductService
    private var listener: ListenerRegistration?

    init(service: ProductService? = nil) {
        self.service = service ?? ProductService.shared
        startListening()
    }

    deinit {
        listener?.remove()
    }

    var activeProducts: [Product] {
        products
            .filter { $0.status == .active }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func myListings(for userID: String?) -> [Product] {
        guard let userID else { return [] }
        return products
            .filter { $0.sellerId == userID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func toggleFavorite(for product: Product) {
        guard let index = products.firstIndex(where: { $0.id == product.id }) else { return }
        products[index].isFavorite.toggle()
    }

    func createProduct(input: CreateProductInput) async throws -> Product {
        try await service.createProduct(input: input)
    }

    func updateProduct(_ product: Product) async throws {
        try await service.updateProduct(product)
    }

    func deleteProduct(_ product: Product) async throws {
        try await service.deleteProduct(product)
    }

    private func startListening() {
        isLoading = true
        listener?.remove()
        listener = service.observeProducts { [weak self] result in
            Task { @MainActor in
                guard let self else { return }

                switch result {
                case .success(let products):
                    self.products = products
                    self.errorMessage = nil
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }

                self.isLoading = false
            }
        }
    }
}

enum ProductServiceError: LocalizedError {
    case notAuthenticated
    case invalidProductData

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to publish a product."
        case .invalidProductData:
            return "The product could not be loaded after saving."
        }
    }
}
