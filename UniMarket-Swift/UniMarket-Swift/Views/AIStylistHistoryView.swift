import SwiftUI

struct AIStylistHistoryView: View {
    @Environment(\.hideTabBar) private var hideTabBar
    @StateObject private var viewModel = AIStylistHistoryViewModel()
    @StateObject private var networkMonitor = NetworkMonitor()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.conversations.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.background)
            } else {
                content
            }
        }
        .background(AppTheme.background)
        .navigationTitle("AI Stylist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    AIStylistChatView()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .onAppear {
            withAnimation {
                hideTabBar.wrappedValue = true
            }
            Task {
                await viewModel.loadConversations()
            }
        }
        .onChange(of: viewModel.searchText) {
            Task {
                await viewModel.refreshSearch()
            }
        }
    }

    private var content: some View {
        List {
            Section {
                searchBar
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(AppTheme.background)

                if !networkMonitor.isConnected {
                    offlineBanner
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(AppTheme.background)
                }

                NavigationLink {
                    AIStylistChatView()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.accent)
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Start new stylist chat")
                                .font(.poppinsSemiBold(14))
                                .foregroundStyle(AppTheme.primaryText)
                            Text("Open a fresh outfit conversation and keep it saved locally.")
                                .font(.poppinsRegular(12))
                                .foregroundStyle(AppTheme.secondaryText)
                                .lineLimit(2)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(AppTheme.background)
            }

            if viewModel.conversations.isEmpty {
                Section {
                    emptyState
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets(top: 28, leading: 16, bottom: 28, trailing: 16))
                        .listRowBackground(AppTheme.background)
                }
            } else {
                Section("Saved Conversations") {
                    ForEach(viewModel.conversations) { conversation in
                        NavigationLink {
                            AIStylistChatView(conversationID: conversation.id)
                        } label: {
                            conversationRow(conversation)
                        }
                        .listRowBackground(AppTheme.background)
                    }
                    .onDelete { indexSet in
                        Task {
                            for index in indexSet {
                                let conversation = viewModel.conversations[index]
                                await viewModel.deleteConversation(id: conversation.id)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.secondaryText)

            TextField("Search saved stylist chats", text: $viewModel.searchText)
                .font(.poppinsRegular(14))
                .foregroundStyle(AppTheme.primaryText)
                .focused($isSearchFocused)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                    isSearchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var offlineBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.orange)

            Text("Offline mode is active. Saved stylist conversations and search still work locally.")
                .font(.poppinsRegular(12))
                .foregroundStyle(AppTheme.primaryText)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func conversationRow(_ conversation: AIStylistConversationSummary) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.accent.opacity(0.18))
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.title)
                    .font(.poppinsSemiBold(14))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)

                Text(conversation.lastMessagePreview)
                    .font(.poppinsRegular(12))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)

                Text("\(conversation.messageCount) messages")
                    .font(.poppinsRegular(11))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            Text(conversation.updatedAt.historyTimestamp)
                .font(.poppinsRegular(11))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.vertical, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.system(size: 34))
                .foregroundStyle(AppTheme.secondaryText)
            Text(viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No saved stylist chats yet" : "No matching stylist chats")
                .font(.poppinsSemiBold(16))
                .foregroundStyle(AppTheme.primaryText)
            Text(viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Start a new conversation and it will be stored locally for offline access." : "Try a different search term from the conversation title or message text.")
                .font(.poppinsRegular(13))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension Date {
    var historyTimestamp: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        if calendar.isDateInToday(self) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d"
        }

        return formatter.string(from: self)
    }
}
