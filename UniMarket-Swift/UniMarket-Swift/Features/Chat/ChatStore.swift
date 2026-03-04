import Foundation
import SwiftUI
import Combine

struct ChatMessage: Identifiable, Hashable {
    let id: UUID
    let text: String
    let isFromCurrentUser: Bool
    let date: Date

    init(id: UUID = UUID(), text: String, isFromCurrentUser: Bool, date: Date = Date()) {
        self.id = id
        self.text = text
        self.isFromCurrentUser = isFromCurrentUser
        self.date = date
    }
}

struct ChatConversation: Identifiable, Hashable {
    let id: String
    let sellerName: String
    let productID: String
    let productTitle: String
    let productImageName: String
    var unreadCount: Int
    var messages: [ChatMessage]

    var lastMessageText: String {
        messages.last?.text ?? "No messages yet"
    }
}

final class ChatStore: ObservableObject {
    @Published private(set) var conversations: [ChatConversation] = []

    var totalUnreadCount: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }

    @discardableResult
    func startConversation(productID: String, productTitle: String, sellerName: String, productImageName: String) -> String {
        if let existing = conversations.first(where: { $0.productID == productID && $0.sellerName == sellerName }) {
            return existing.id
        }

        let conversationID = UUID().uuidString
        let initialMessage = ChatMessage(text: "Hi! Is this still available?", isFromCurrentUser: true)

        conversations.insert(
            ChatConversation(
                id: conversationID,
                sellerName: sellerName,
                productID: productID,
                productTitle: productTitle,
                productImageName: productImageName,
                unreadCount: 0,
                messages: [initialMessage]
            ),
            at: 0
        )

        return conversationID
    }

    func sendMessage(_ text: String, in conversationID: String, fromCurrentUser: Bool = true) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }

        conversations[index].messages.append(
            ChatMessage(text: text, isFromCurrentUser: fromCurrentUser)
        )

        if !fromCurrentUser {
            conversations[index].unreadCount += 1
        }

        let updated = conversations.remove(at: index)
        conversations.insert(updated, at: 0)
    }

    func markConversationAsRead(_ conversationID: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }

        conversations[index].unreadCount = 0
    }
}
