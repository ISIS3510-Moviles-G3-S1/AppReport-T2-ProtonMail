import Foundation

struct OrderItem: Identifiable, Codable, Hashable {
    let id: String
    let orderID: String
    let productID: String
    let sellerID: String
    let titleSnapshot: String
    let priceSnapshot: Int
    let imageURLSnapshot: String?
}
