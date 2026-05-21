import Combine
import Foundation

enum CartAddResult: Equatable {
    case added
    case alreadyInCart
    case ownListing
    case unavailable

    var message: String {
        switch self {
        case .added:
            return "Added to cart."
        case .alreadyInCart:
            return "This item is already in your cart."
        case .ownListing:
            return "You cannot add your own listing to the cart."
        case .unavailable:
            return "This item is no longer available."
        }
    }
}

@MainActor
final class CartStore: ObservableObject {
    @Published private(set) var items: [CartItem] = []

    private let defaults: UserDefaults
    private let storageKeyPrefix = "unimarket.cart.items"
    private var activeUserID: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load(for: nil)
    }

    var itemCount: Int {
        items.count
    }

    var subtotal: Int {
        items.reduce(0) { $0 + $1.product.price }
    }

    var hasUnavailableItems: Bool {
        items.contains { $0.product.status != .active }
    }

    func load(for userID: String?) {
        activeUserID = normalizedUserID(userID)
        loadFromStorage()
    }

    func add(_ product: Product, currentUserID: String?) -> CartAddResult {
        if let currentUserID = normalizedUserID(currentUserID), product.sellerId == currentUserID {
            return .ownListing
        }

        guard product.status == .active else {
            return .unavailable
        }

        guard !contains(productID: product.id) else {
            return .alreadyInCart
        }

        items.insert(CartItem(product: product), at: 0)
        saveToStorage()
        return .added
    }

    func remove(productID: String) {
        let previousCount = items.count
        items.removeAll { $0.product.id == productID }
        if items.count != previousCount {
            saveToStorage()
        }
    }

    func clear() {
        guard !items.isEmpty else { return }
        items.removeAll()
        saveToStorage()
    }

    func contains(productID: String) -> Bool {
        items.contains { $0.product.id == productID }
    }

    func reconcile(with products: [Product]) {
        guard !items.isEmpty else { return }

        var productsByID: [String: Product] = [:]
        for product in products {
            productsByID[product.id] = product
        }

        var didChange = false
        let updatedItems = items.map { item in
            guard let latestProduct = productsByID[item.product.id] else {
                return item
            }

            guard latestProduct != item.product else {
                return item
            }

            didChange = true
            return CartItem(product: latestProduct, addedAt: item.addedAt)
        }

        guard didChange else { return }
        items = updatedItems
        saveToStorage()
    }

    private var storageKey: String {
        if let activeUserID, !activeUserID.isEmpty {
            return "\(storageKeyPrefix).\(activeUserID)"
        }

        return "\(storageKeyPrefix).guest"
    }

    private func loadFromStorage() {
        guard let data = defaults.data(forKey: storageKey),
              let decodedItems = try? JSONDecoder().decode([CartItem].self, from: data)
        else {
            items = []
            return
        }

        items = decodedItems
    }

    private func saveToStorage() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func normalizedUserID(_ userID: String?) -> String? {
        let trimmed = userID?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
