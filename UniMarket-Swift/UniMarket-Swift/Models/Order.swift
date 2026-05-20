import Foundation

struct Order: Identifiable, Codable, Hashable {
    let id: String
    let orderNumber: String
    let userID: String
    let createdAt: Date
    let subtotal: Int
    let status: String
    let buyerName: String
    let buyerEmail: String
    let pickupLocation: String
    let paymentLastFour: String
    let paymentToken: String
    let items: [OrderItem]
}
