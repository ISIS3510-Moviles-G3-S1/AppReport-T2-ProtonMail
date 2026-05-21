import Foundation

struct CartItem: Identifiable, Codable, Hashable {
    var id: String { product.id }
    var product: Product
    let addedAt: Date
    let source: String

    init(product: Product, addedAt: Date = .now, source: String = AnalyticsSurface.unknown.rawValue) {
        self.product = product
        self.addedAt = addedAt
        self.source = source
    }

    private enum CodingKeys: String, CodingKey {
        case product
        case addedAt
        case source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        product = try container.decode(Product.self, forKey: .product)
        addedAt = try container.decode(Date.self, forKey: .addedAt)
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? AnalyticsSurface.unknown.rawValue
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(product, forKey: .product)
        try container.encode(addedAt, forKey: .addedAt)
        try container.encode(source, forKey: .source)
    }
}
