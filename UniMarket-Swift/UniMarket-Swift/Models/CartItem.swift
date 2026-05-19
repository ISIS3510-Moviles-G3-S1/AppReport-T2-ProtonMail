import Foundation

struct CartItem: Identifiable, Codable, Hashable {
    var id: String { product.id }
    var product: Product
    let addedAt: Date

    init(product: Product, addedAt: Date = .now) {
        self.product = product
        self.addedAt = addedAt
    }
}
