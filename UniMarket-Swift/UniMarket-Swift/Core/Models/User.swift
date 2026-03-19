import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    let id: String
    let displayName: String
    let email: String
    let createdAt: Date
    let isVerified: Bool
    let numTransactions: Int
    var profilePic: String
    let ratingStars: Double
    let xpPoints: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "uid"
        case displayName
        case email
        case createdAt
        case isVerified
        case numTransactions
        case profilePic
        case ratingStars
        case xpPoints
    }
}
