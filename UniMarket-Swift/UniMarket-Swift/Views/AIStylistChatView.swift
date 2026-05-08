import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AIStylistChatView: View {
    @EnvironmentObject private var productStore: ProductStore
    @EnvironmentObject private var session: SessionManager
    @Environment(\.hideTabBar) private var hideTabBar
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AIStylistChatViewModel
    @StateObject private var networkMonitor = NetworkMonitor()
    @State private var draftMessage = ""
    @State private var selectedReferenceImage: UIImage?
    @State private var showPhotoLibrary = false

    private let promptSuggestions = [
        "Give me a casual campus outfit",
        "Build a streetwear outfit under $80",
        "I need a neutral outfit for class",
        "Build an outfit around this piece"
    ]

    init(conversationID: String? = nil) {
        _viewModel = StateObject(wrappedValue: AIStylistChatViewModel(conversationID: conversationID))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if !networkMonitor.isConnected {
                            offlineBanner
                        }

                        promptStrip

                        ForEach(viewModel.messages) { message in
                            stylistBubble(message)
                                .id(message.id)
                        }

                        if viewModel.isSending {
                            ProgressView("Stylist is thinking...")
                                .font(.poppinsRegular(13))
                                .foregroundStyle(AppTheme.secondaryText)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) {
                    if let last = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.poppinsRegular(12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.9))
            }

            inputBar
        }
        .background(AppTheme.background)
        .safeAreaInset(edge: .top, spacing: 0) {
            headerBar
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation {
                hideTabBar.wrappedValue = true
            }
        }
        .sheet(isPresented: $showPhotoLibrary) {
            ImagePicker(source: .photoLibrary) { image in
                selectedReferenceImage = image
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            Text(viewModel.conversationTitle)
                .font(.poppinsSemiBold(18))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 6)
        .padding(.bottom, 12)
        .background(AppTheme.background)
    }

    private var promptStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(promptSuggestions, id: \.self) { prompt in
                    Button(prompt) {
                        draftMessage = prompt
                    }
                    .font(.poppinsRegular(12))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.cardBackground)
                    .clipShape(Capsule())
                }
            }
        }
    }

    private var offlineBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.orange)

            Text("No connection. Your saved chat history is available, and new replies will use the local stylist.")
                .font(.poppinsRegular(12))
                .foregroundStyle(AppTheme.primaryText)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func stylistBubble(_ message: AIStylistMessage) -> some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
            HStack {
                if message.role == .user {
                    Spacer(minLength: 40)
                }

                VStack(alignment: .leading, spacing: 8) {
                    if let attachedImage = message.attachedImage {
                        Image(uiImage: attachedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Text(message.text)
                        .font(.poppinsRegular(14))
                        .foregroundStyle(message.role == .user ? .white : AppTheme.primaryText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.role == .user ? AppTheme.accent : AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if message.role == .assistant {
                    Spacer(minLength: 40)
                }
            }

            if message.role == .assistant && !message.suggestedProducts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Suggested items")
                        .font(.poppinsSemiBold(12))
                        .foregroundStyle(AppTheme.secondaryText)

                    ForEach(message.suggestedProducts, id: \.id) { product in
                        NavigationLink {
                            ProductDetailView(product: product)
                        } label: {
                            HStack(spacing: 12) {
                                CachedRemoteImageView(urlString: product.primaryImageURL ?? "")
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.title)
                                        .font(.poppinsSemiBold(13))
                                        .foregroundStyle(AppTheme.primaryText)
                                        .lineLimit(1)
                                    Text("$\(product.price)")
                                        .font(.poppinsRegular(12))
                                        .foregroundStyle(AppTheme.secondaryText)
                                }

                                Spacer()
                            }
                            .padding(10)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var inputBar: some View {
        VStack(spacing: 10) {
            if let selectedReferenceImage {
                HStack(spacing: 12) {
                    Image(uiImage: selectedReferenceImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Text("Photo ready for outfit matching")
                        .font(.poppinsRegular(13))
                        .foregroundStyle(AppTheme.secondaryText)

                    Spacer()

                    Button {
                        self.selectedReferenceImage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            HStack(spacing: 10) {
                Button {
                    showPhotoLibrary = true
                } label: {
                    Image(systemName: "photo")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                TextField("Ask for an outfit...", text: $draftMessage)
                    .font(.poppinsRegular(14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button {
                    let prompt = draftMessage
                    let referenceImage = selectedReferenceImage
                    draftMessage = ""
                    selectedReferenceImage = nil
                    Task {
                        let catalog = productStore.browseProducts(excludingUserID: session.uid)
                        await viewModel.send(
                            prompt: prompt,
                            catalog: catalog,
                            referenceImage: referenceImage,
                            prefersOfflineMode: !networkMonitor.isConnected
                        )
                    }
                } label: {
                    if viewModel.isSending {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 44, height: 38)
                            .background(AppTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 38)
                            .background(AppTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .disabled(
                    viewModel.isSending ||
                    (
                        draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                        selectedReferenceImage == nil
                    )
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(AppTheme.background)
    }
}
