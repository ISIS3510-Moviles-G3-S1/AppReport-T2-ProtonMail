import Foundation

// MARK: - NotificationItemType

enum NotificationItemType: String, Codable, Hashable {
    case unreadMessage
    case priceDrop
    case syncStatus
    case recentActivity

    var systemIconName: String {
        switch self {
        case .unreadMessage:  return "tray.fill"
        case .priceDrop:      return "arrow.down.circle.fill"
        case .syncStatus:     return "arrow.triangle.2.circlepath"
        case .recentActivity: return "clock.fill"
        }
    }
}

// MARK: - DeepLinkTarget

/// Typed navigation destination carried by every NotificationItem.
/// Codable so it survives the UserDefaults cold-launch snapshot.
enum DeepLinkTarget: Hashable, Codable {
    case chatThread(conversationID: String)
    case productDetail(productID: String)
    case activity
    case syncQueue

    // MARK: Manual Codable (associated-value enums need it)

    private enum CodingKeys: String, CodingKey { case kind, id }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .chatThread(let id):
            try c.encode("chat",     forKey: .kind)
            try c.encode(id,         forKey: .id)
        case .productDetail(let id):
            try c.encode("product",  forKey: .kind)
            try c.encode(id,         forKey: .id)
        case .activity:
            try c.encode("activity", forKey: .kind)
        case .syncQueue:
            try c.encode("sync",     forKey: .kind)
        }
    }

    init(from decoder: Decoder) throws {
        let c    = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        switch kind {
        case "chat":
            self = .chatThread(conversationID: try c.decode(String.self, forKey: .id))
        case "product":
            self = .productDetail(productID: try c.decode(String.self, forKey: .id))
        case "activity":
            self = .activity
        default:
            self = .syncQueue
        }
    }
}

// MARK: - NotificationItem

struct NotificationItem: Identifiable, Codable, Hashable {
    let id:             String
    let type:           NotificationItemType
    let title:          String
    let subtitle:       String
    let timestamp:      Date
    let deepLinkTarget: DeepLinkTarget
}

// MARK: - NotificationSections

struct NotificationSections {
    var unreadMessages: [NotificationItem] = []
    var priceDrops:     [NotificationItem] = []
    var syncStatus:     [NotificationItem] = []
    var recentActivity: [NotificationItem] = []

    static let empty = NotificationSections()

    var isEmpty: Bool {
        unreadMessages.isEmpty && priceDrops.isEmpty
            && syncStatus.isEmpty && recentActivity.isEmpty
    }
}

// MARK: - NotificationBatch
//
// Discriminated union used as the `of:` result type in withTaskGroup.
// Each of the four aggregator sources produces one batch; the ViewModel
// applies it to the correct section immediately (progressive rendering).

enum NotificationBatch {
    case messages([NotificationItem])
    case priceDrops([NotificationItem])
    case syncStatus([NotificationItem])
    case recentActivity([NotificationItem])
}
