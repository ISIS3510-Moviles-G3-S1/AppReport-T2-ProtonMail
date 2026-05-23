import Foundation

enum ListingKind: String, CaseIterable, Codable {
    case sale = "sale"
    case donation = "donation"
    case barter = "barter"

    var firestoreValue: String { rawValue }

    init(firestoreValue raw: String?) {
        switch raw?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "donation": self = .donation
        case "barter": self = .barter
        default: self = .sale
        }
    }
}
