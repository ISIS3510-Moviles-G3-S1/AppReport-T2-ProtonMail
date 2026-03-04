import SwiftUI

struct ChatInboxView: View {
    @EnvironmentObject private var chatStore: ChatStore

    var body: some View {
        Group {
            if chatStore.conversations.isEmpty {
                emptyState
            } else {
                inboxList
            }
        }
        .background(AppTheme.background)
        .navigationTitle("Inbox")
    }

    private var inboxList: some View {
        List {
            ForEach(chatStore.conversations) { conversation in
                NavigationLink {
                    ChatThreadView(conversationID: conversation.id)
                } label: {
                    HStack(spacing: 10) {
                        Image(conversation.productImageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(conversation.sellerName)
                                .font(.poppinsSemiBold(14))
                                .foregroundStyle(AppTheme.primaryText)
                            Text(conversation.lastMessageText)
                                .font(.poppinsRegular(12))
                                .foregroundStyle(AppTheme.secondaryText)
                                .lineLimit(1)
                        }

                        Spacer()

                        if conversation.unreadCount > 0 {
                            Text("\(conversation.unreadCount)")
                                .font(.poppinsSemiBold(12))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.accent)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(AppTheme.background)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 34))
                .foregroundStyle(AppTheme.secondaryText)
            Text("No messages yet")
                .font(.poppinsSemiBold(16))
                .foregroundStyle(AppTheme.primaryText)
            Text("Tap Message on a product to start chatting.")
                .font(.poppinsRegular(13))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
