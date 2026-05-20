import Foundation
import UIKit
import Combine
import FirebaseAuth

@MainActor
final class AIStylistChatViewModel: ObservableObject {
    @Published private(set) var conversationID: String?
    @Published private(set) var conversationTitle: String
    @Published private(set) var messages: [AIStylistMessage]
    @Published var isSending = false
    @Published var errorMessage: String?

    static let defaultConversationTitle = "New Chat"
    static let defaultMessages = [
        AIStylistMessage(
            role: .assistant,
            text: "Ask for a full outfit, a vibe, or a budget. Example: \"Give me a casual campus outfit under $60.\"",
            suggestedProducts: [],
            attachedImage: nil
        )
    ]

    private let chatbot: StylistChatbot
    private let fallbackChatbot: StylistChatbot = MockStylistChatbotCreator().makeChatbot()
    private let conversationStore = AIStylistConversationFileStore()
    private let analytics = AnalyticsService.shared
    private var createdAt = Date()

    init(conversationID: String? = nil, creator: StylistChatbotCreator? = nil) {
        self.conversationID = conversationID
        self.conversationTitle = Self.defaultConversationTitle
        self.messages = Self.defaultMessages
        self.chatbot = (creator ?? StylistChatbotFactory.makeCreator()).makeChatbot()

        if let conversationID {
            Task {
                await loadConversation(id: conversationID)
            }
        }
    }

    func send(prompt: String, catalog: [Product], referenceImage: UIImage?, prefersOfflineMode: Bool = false) async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || referenceImage != nil else { return }

        let userMessage = trimmed.isEmpty ? "Help me build an outfit that complements this photo." : trimmed
        ensureConversationIdentity(for: userMessage, hasReferenceImage: referenceImage != nil)

        messages.append(AIStylistMessage(
            role: .user,
            text: userMessage,
            suggestedProducts: [],
            attachedImage: referenceImage
        ))
        persistConversation()
        isSending = true
        errorMessage = nil

        let request = StylistChatRequest(prompt: userMessage, catalog: catalog, referenceImage: referenceImage)
        let startedAt = Date()
        analytics.track(.aiStylistPromptSent(
            conversationID: conversationID,
            promptLength: userMessage.count,
            hasReferenceImage: referenceImage != nil,
            catalogCount: catalog.count,
            mode: prefersOfflineMode ? "offline" : "live"
        ))

        if prefersOfflineMode {
            await sendOfflineResponse(for: request, startedAt: startedAt)
            return
        }

        do {
            let response = try await chatbot.respond(to: request)
            messages.append(AIStylistMessage(
                role: .assistant,
                text: response.message,
                suggestedProducts: response.suggestedProducts,
                attachedImage: nil
            ))
            trackResponse(
                source: "live",
                suggestedProductCount: response.suggestedProducts.count,
                startedAt: startedAt
            )
            persistConversation()
        } catch {
            if let response = try? await fallbackChatbot.respond(to: request) {
                messages.append(AIStylistMessage(
                    role: .assistant,
                    text: response.message,
                    suggestedProducts: response.suggestedProducts,
                    attachedImage: nil
                ))
                trackResponse(
                    source: "demo_fallback",
                    suggestedProductCount: response.suggestedProducts.count,
                    startedAt: startedAt
                )
                persistConversation()
            }
            errorMessage = "Live AI was unavailable, so the stylist used demo mode."
        }

        isSending = false
    }

    private func sendOfflineResponse(for request: StylistChatRequest, startedAt: Date) async {
        if let response = try? await fallbackChatbot.respond(to: request) {
            messages.append(AIStylistMessage(
                role: .assistant,
                text: response.message,
                suggestedProducts: response.suggestedProducts,
                attachedImage: nil
            ))
            trackResponse(
                source: "offline_demo",
                suggestedProductCount: response.suggestedProducts.count,
                startedAt: startedAt
            )
            persistConversation()
        }
        errorMessage = "You're offline, so the stylist is using local demo mode."
        isSending = false
    }

    private func trackResponse(source: String, suggestedProductCount: Int, startedAt: Date) {
        analytics.track(.aiStylistResponseReceived(
            conversationID: conversationID,
            responseSource: source,
            suggestedProductCount: suggestedProductCount,
            durationMs: Int(Date().timeIntervalSince(startedAt) * 1_000)
        ))
    }

    private func loadConversation(id: String) async {
        do {
            guard let conversation = try conversationStore.loadConversation(id: id, for: storageKey) else {
                return
            }
            conversationID = conversation.id
            conversationTitle = conversation.title
            createdAt = conversation.createdAt
            messages = conversation.messages
        } catch {
            errorMessage = "Couldn't load this saved stylist chat."
        }
    }

    private func ensureConversationIdentity(for prompt: String, hasReferenceImage: Bool) {
        if conversationID == nil {
            conversationID = UUID().uuidString
            createdAt = Date()
        }

        if conversationTitle == Self.defaultConversationTitle {
            conversationTitle = makeConversationTitle(from: prompt, hasReferenceImage: hasReferenceImage)
        }
    }

    private func makeConversationTitle(from prompt: String, hasReferenceImage: Bool) -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return String(trimmed.prefix(36))
        }

        return hasReferenceImage ? "Photo Outfit Match" : Self.defaultConversationTitle
    }

    private func persistConversation() {
        guard let conversationID else { return }

        let snapshot = AIStylistConversation(
            id: conversationID,
            createdAt: createdAt,
            title: conversationTitle,
            updatedAt: messages.last?.sentAt ?? .now,
            messages: messages
        )
        try? conversationStore.saveConversation(snapshot, for: storageKey)
    }

    private var storageKey: String {
        Auth.auth().currentUser?.uid ?? "guest"
    }
}
