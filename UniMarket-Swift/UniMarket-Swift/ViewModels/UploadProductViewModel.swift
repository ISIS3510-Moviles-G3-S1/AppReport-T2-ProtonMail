import SwiftUI
import PhotosUI
import Combine
import FirebaseAuth

#if canImport(UIKit)
import UIKit
#endif

enum PostOutcome {
    case published
    case queued
    case failed
}

final class UploadProductViewModel: ObservableObject {
    private let analytics = AnalyticsService.shared
    private var activeDraftID: String?
    @Published var selectedItems: [PhotosPickerItem] = []
    @Published var selectedImages: [Image] = []
    @Published var imagesData: [Data] = []

    @Published var title: String = ""
    @Published var price: String = ""
    @Published var condition: String = "Good"
    @Published var description: String = ""
    @Published var selectedTags: [String] = []
    @Published var tagSearchText: String = ""
    @Published var customTagInput: String = ""
    /// Sale by default. Donations skip the price field and write kind="donation"
    /// to Firestore so the Donations tab/Flutter client can pick them up.
    @Published var kind: ListingKind = .sale

    @Published var isPosting: Bool = false
    @Published var errorMessage: String? = nil
    @Published var infoMessage: String? = nil

    func applyAIDraft(_ draft: AIListingDraft, image: UIImage?) {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            title = draft.title
        }

        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            description = draft.description
        }

        selectedTags = Array(draft.tags.map(normalizeTag).filter { !$0.isEmpty }).prefix(8).map { $0 }
        errorMessage = nil

        if let image, selectedImages.isEmpty, imagesData.isEmpty {
            addImageFromCamera(image)
        }
    }

    func loadSelectedPhotos() async {
        errorMessage = nil

        await MainActor.run {
            selectedImages = []
            imagesData = []
        }

        for item in selectedItems {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    #if canImport(UIKit)
                    if let uiImage = UIImage(data: data) {
                        let swiftUIImage = Image(uiImage: uiImage)
                        await MainActor.run {
                            imagesData.append(data)
                            selectedImages.append(swiftUIImage)
                        }
                    } else {
                        await MainActor.run { errorMessage = "Could not read one of the images." }
                    }
                    #else
                    await MainActor.run { imagesData.append(data) }
                    #endif
                }
            } catch {
                await MainActor.run { errorMessage = "Error loading one of the photos." }
            }
        }
    }

    func addImageFromCamera(_ uiImage: UIImage) {
        guard selectedImages.count < 5 else {
            errorMessage = "Maximum 5 photos."
            return
        }
        if let data = uiImage.jpegData(compressionQuality: 0.85) {
            imagesData.append(data)
            selectedImages.append(Image(uiImage: uiImage))
        } else {
            errorMessage = "Could not process the photo."
        }
    }

    func removeImage(at index: Int) {
        if index < selectedImages.count { selectedImages.remove(at: index) }
        if index < imagesData.count { imagesData.remove(at: index) }
        if index < selectedItems.count { selectedItems.remove(at: index) }
    }

    var canPost: Bool {
        guard !imagesData.isEmpty,
              !title.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        // Donations don't require a price; sales do.
        return kind == .donation || Int(price) != nil
    }

    var hasDraftContent: Bool {
        !imagesData.isEmpty ||
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !price.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        condition != "Good" ||
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !selectedTags.isEmpty ||
        !customTagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func postProduct(using productStore: ProductStore) async -> PostOutcome {
        guard canPost else { return .failed }
        // Donations force price=0 regardless of what the user typed.
        let parsedPrice = kind == .donation ? 0 : (Int(price) ?? 0)
        analytics.track(.listingSubmitAttempt(
            photoCount: imagesData.count,
            hasDescription: !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            condition: condition,
            priceBucket: priceBucket(for: parsedPrice)
        ))

        await MainActor.run {
            isPosting = true
            errorMessage = nil
            infoMessage = nil
        }

        defer {
            Task { @MainActor in self.isPosting = false }
        }

        let input = CreateProductInput(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            price: parsedPrice,
            conditionTag: condition,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            imagesData: imagesData,
            tags: selectedTags,
            kind: kind
        )

        // Offline up front: skip the network attempt, enqueue to disk, surface
        // a "will publish when you're back online" message.
        let isConnected = await MainActor.run { NetworkMonitor.shared.isConnected }
        if !isConnected, let uid = Auth.auth().currentUser?.uid {
            await PendingListingsSyncer.shared.enqueue(input: input, userID: uid)
            analytics.track(.listingSubmitFailed(reason: "queued_offline"))
            await deleteActiveDraftIfNeeded(for: uid)
            await MainActor.run {
                infoMessage = "You're offline — we saved your listing and will publish it as soon as you're back online."
                resetForm()
            }
            return .queued
        }

        do {
            let product = try await productStore.createProduct(input: input)
            await ListingReminderService.shared.recordListing(for: product.sellerId, at: product.createdAt)
            await deleteActiveDraftIfNeeded(for: product.sellerId)
            await MainActor.run { resetForm() }
            return .published
        } catch {
            // Live attempt failed mid-flight. If the failure looks network-shaped
            // (offline / Storage upload error) fall back to the queue so the user
            // doesn't lose their work.
            if Self.isLikelyNetworkError(error), let uid = Auth.auth().currentUser?.uid {
                await PendingListingsSyncer.shared.enqueue(input: input, userID: uid)
                analytics.track(.listingSubmitFailed(reason: "queued_after_network_error"))
                await deleteActiveDraftIfNeeded(for: uid)
                await MainActor.run {
                    infoMessage = "We couldn't reach the server — your listing is saved and we'll retry when you're back online."
                    resetForm()
                }
                return .queued
            }
            analytics.track(.listingSubmitFailed(reason: error.localizedDescription))
            await MainActor.run { errorMessage = error.localizedDescription }
            return .failed
        }
    }

    func saveDraftIfNeeded(for userID: String?, message: String) async {
        guard let userID, hasDraftContent else { return }

        let draftID = activeDraftID
        let draftTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let draftPrice = price.trimmingCharacters(in: .whitespacesAndNewlines)
        let draftCondition = condition
        let draftDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let draftTags = selectedTags
        let draftImagesData = imagesData

        do {
            let savedDraft = try await ListingDraftStore.shared.save(
                draftID: draftID,
                userID: userID,
                title: draftTitle,
                priceText: draftPrice,
                conditionTag: draftCondition,
                listingDescription: draftDescription,
                tags: draftTags,
                imagesData: draftImagesData
            )
            await MainActor.run {
                activeDraftID = savedDraft.draftID
                infoMessage = message
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "Could not save this draft."
            }
        }
    }

    func restoreDraft(_ draft: ListingDraft) async {
        do {
            let payload = try await ListingDraftStore.shared.materialize(draft)
            await MainActor.run {
                applyDraftPayload(payload)
                infoMessage = "Draft loaded."
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "Could not open this draft."
            }
        }
    }

    private func deleteActiveDraftIfNeeded(for userID: String) async {
        guard let activeDraftID else { return }
        let draftID = activeDraftID
        try? await ListingDraftStore.shared.remove(draftID: draftID, userID: userID)
        await MainActor.run {
            if self.activeDraftID == draftID {
                self.activeDraftID = nil
            }
        }
    }

    @MainActor
    private func applyDraftPayload(_ payload: ListingDraftPayload) {
        activeDraftID = payload.draft.draftID
        selectedItems = []
        imagesData = payload.imagesData
        selectedImages = payload.imagesData.compactMap { data in
            guard let uiImage = UIImage(data: data) else { return nil }
            return Image(uiImage: uiImage)
        }
        title = payload.draft.title
        price = payload.draft.priceText
        condition = payload.draft.conditionTag
        description = payload.draft.listingDescription
        selectedTags = payload.draft.tags
        tagSearchText = ""
        customTagInput = ""
    }

    private static func isLikelyNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain { return true }
        let networkCodes: Set<Int> = [
            NSURLErrorNotConnectedToInternet,
            NSURLErrorTimedOut,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorCannotFindHost,
            NSURLErrorCannotConnectToHost,
            NSURLErrorDataNotAllowed
        ]
        return networkCodes.contains(nsError.code)
    }

    @MainActor
    private func resetForm() {
        selectedItems = []
        selectedImages = []
        imagesData = []
        title = ""
        price = ""
        condition = "Good"
        description = ""
        selectedTags = []
        tagSearchText = ""
        customTagInput = ""
        kind = .sale
        activeDraftID = nil
        errorMessage = nil
        // Note: we deliberately don't clear infoMessage here — the post-publish
        // confirmation is shown by the upload view based on the PostOutcome.
    }

    var normalizedCustomTag: String {
        normalizeTag(customTagInput)
    }

    func toggleTag(_ tag: String) {
        let normalized = normalizeTag(tag)
        guard !normalized.isEmpty else { return }

        if let index = selectedTags.firstIndex(of: normalized) {
            selectedTags.remove(at: index)
        } else if selectedTags.count < 8 {
            selectedTags.append(normalized)
        } else {
            errorMessage = "Maximum 8 tags."
        }
    }

    func addCustomTag() {
        let normalized = normalizedCustomTag
        guard !normalized.isEmpty else { return }

        if selectedTags.contains(normalized) {
            customTagInput = ""
            return
        }

        guard selectedTags.count < 8 else {
            errorMessage = "Maximum 8 tags."
            return
        }

        selectedTags.append(normalized)
        customTagInput = ""
        errorMessage = nil
    }

    func filteredAvailableTags(from tags: [String]) -> [String] {
        let query = tagSearchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return tags
            .map(normalizeTag)
            .filter { !selectedTags.contains($0) }
            .filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
            .sorted()
    }

    private func normalizeTag(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .first
            .map(String.init)?
            .lowercased()
            ?? ""
    }

    private func priceBucket(for price: Int) -> String {
        switch price {
        case ..<25000:
            return "under_25k"
        case 25000..<50000:
            return "25k_50k"
        case 50000..<100000:
            return "50k_100k"
        default:
            return "100k_plus"
        }
    }
}

// MARK: - Fix onChange iOS 17

private struct ItemsOnChangeFix: ViewModifier {
    let items: [PhotosPickerItem]
    let action: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onChange(of: items) { _, _ in action() }
        } else {
            content.onChange(of: items) { _ in action() }
        }
    }
}
