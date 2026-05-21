import Foundation

final class CartContentsCache {
    static let shared = CartContentsCache()

    private let cache = NSCache<NSString, CartItemsBox>()

    private init() {
        cache.countLimit = 20
    }

    func items(for key: String) -> [CartItem]? {
        cache.object(forKey: key as NSString)?.items
    }

    func store(_ items: [CartItem], for key: String) {
        cache.setObject(CartItemsBox(items: items), forKey: key as NSString, cost: max(items.count, 1))
    }

    func remove(for key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    func clear() {
        cache.removeAllObjects()
    }
}

private final class CartItemsBox {
    let items: [CartItem]

    init(items: [CartItem]) {
        self.items = items
    }
}
