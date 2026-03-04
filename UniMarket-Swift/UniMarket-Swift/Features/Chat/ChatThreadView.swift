import SwiftUI

struct ChatThreadView: View {
    @EnvironmentObject private var chatStore: ChatStore

    let conversationID: String

    @State private var draftMessage: String = ""

    private var conversation: ChatConversation? {
        chatStore.conversations.first(where: { $0.id == conversationID })
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(conversation?.messages ?? []) { message in
                        HStack {
                            if message.isFromCurrentUser {
                                Spacer(minLength: 40)
                            }

                            Text(message.text)
                                .font(.poppinsRegular(14))
                                .foregroundStyle(message.isFromCurrentUser ? .white : AppTheme.primaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(message.isFromCurrentUser ? AppTheme.accent : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            if !message.isFromCurrentUser {
                                Spacer(minLength: 40)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }

            HStack(spacing: 10) {
                TextField("Write a message...", text: $draftMessage)
                    .font(.poppinsRegular(14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button("Send") {
                    sendDraft()
                }
                .font(.poppinsSemiBold(14))
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(AppTheme.background)
        }
        .background(AppTheme.background)
        .navigationTitle(conversation?.sellerName ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            chatStore.markConversationAsRead(conversationID)
        }
    }

    private func sendDraft() {
        let trimmed = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        chatStore.sendMessage(trimmed, in: conversationID, fromCurrentUser: true)
        draftMessage = ""
    }
}
