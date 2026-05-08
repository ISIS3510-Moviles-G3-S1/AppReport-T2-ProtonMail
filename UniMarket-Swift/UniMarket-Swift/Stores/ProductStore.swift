import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import Kingfisher

@MainActor
final class ProductStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service: ProductService
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var imagePrefetcher: ImagePrefetcher?
    private var savedProductIDs: Set<String> = []

    private let productCacheKey = "unimarket.cached_products"

    init(service: ProductService? = nil) {
        self.service = service ?? ProductService.shared
        loadFromCache()
        Task { await loadSavedItems() }
        startListening()
    }

    deinit {
        listener?.remove()
        imagePrefetcher?.stop()
    }

    var activeProducts: [Product] {
        products
            .filter { $0.status == .active }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func myListings(for userID: String?) -> [Product] {
        guard let userID else { return [] }
        return products
            .filter { $0.sellerId == userID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func browseProducts(excludingUserID userID: String?) -> [Product] {
        guard let userID, !userID.isEmpty else { return activeProducts }
        return activeProducts.filter { $0.sellerId != userID }
    }

    func prefetchImages(for products: [Product]) {
        let urls = products
            .flatMap { $0.imageURLs }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(12)
            .compactMap { URL(string: $0) }

        guard !urls.isEmpty else { return }

        imagePrefetcher?.stop()
        imagePrefetcher = ImagePrefetcher(urls: Array(urls))
        imagePrefetcher?.start()
    }

    func toggleFavorite(for product: Product) {
        guard let index = products.firstIndex(where: { $0.id == product.id }) else { return }
        products[index].isFavorite.toggle()

        let isSaved = products[index].isFavorite
        if isSaved {
            savedProductIDs.insert(product.id)
        } else {
            savedProductIDs.remove(product.id)
        }

        let saved = products[index]
        let favoriteItem = FavoriteItem(
            id: saved.id,
            title: saved.title,
            price: saved.price,
            imageURL: saved.primaryImageURL,
            sellerName: saved.sellerName
        )
        if isSaved {
            FavoritesCacheManager.shared.addFavorite(favoriteItem)
        } else {
            FavoritesCacheManager.shared.removeFavorite(itemId: product.id)
        }

        guard let uid = Auth.auth().currentUser?.uid else { return }

        // Offline: enqueue rather than letting Firestore's offline cache buffer
        // the write opaquely — we need our own "pending" UI state.
        if !NetworkMonitor.shared.isConnected {
            Task {
                await PendingFavoritesSyncer.shared.enqueue(
                    productID: product.id,
                    kind: isSaved ? .save : .unsave
                )
            }
            return
        }

        let ref = db.collection("users").document(uid)
        Task {
            do {
                if isSaved {
                    try await ref.updateData(["savedItems": FieldValue.arrayUnion([product.id])])
                } else {
                    try await ref.updateData(["savedItems": FieldValue.arrayRemove([product.id])])
                }
            } catch {
                // Mid-write network drop: hand the op to the syncer.
                await PendingFavoritesSyncer.shared.enqueue(
                    productID: product.id,
                    kind: isSaved ? .save : .unsave
                )
            }
        }
    }

    func createProduct(input: CreateProductInput) async throws -> Product {
        try await service.createProduct(input: input)
    }

    func updateProduct(_ product: Product) async throws {
        if !NetworkMonitor.shared.isConnected {
            applyLocalMutation(product)
            await PendingListingMutationsSyncer.shared.enqueueUpdate(product: product)
            return
        }
        do {
            try await service.updateProduct(product)
        } catch {
            if Self.isLikelyNetworkError(error) {
                applyLocalMutation(product)
                await PendingListingMutationsSyncer.shared.enqueueUpdate(product: product)
                return
            }
            throw error
        }
    }

    func deleteProduct(_ product: Product) async throws {
        if !NetworkMonitor.shared.isConnected {
            applyLocalDelete(productID: product.id)
            await PendingListingMutationsSyncer.shared.enqueueDelete(product: product)
            return
        }
        do {
            try await service.deleteProduct(product)
        } catch {
            if Self.isLikelyNetworkError(error) {
                applyLocalDelete(productID: product.id)
                await PendingListingMutationsSyncer.shared.enqueueDelete(product: product)
                return
            }
            throw error
        }
    }

    private func applyLocalMutation(_ product: Product) {
        guard let idx = products.firstIndex(where: { $0.id == product.id }) else { return }
        var existing = products[idx]
        existing.title = product.title
        existing.price = product.price
        existing.status = product.status
        existing.soldAt = product.soldAt
        products[idx] = existing
    }

    private func applyLocalDelete(productID: String) {
        products.removeAll { $0.id == productID }
        savedProductIDs.remove(productID)
    }

    private static func isLikelyNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain { return true }
        let networkCodes: Set<Int> = [
            NSURLErrorNotConnectedToInternet,
            NSURLErrorTimedOut,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorCannotConnectToHost,
            NSURLErrorCannotFindHost
        ]
        return networkCodes.contains(nsError.code)
    }

    func loadSavedItems() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            let ids = doc.data()?["savedItems"] as? [String] ?? []
            savedProductIDs = Set(ids)
            mergePendingFavorites(for: uid)
            applySavedState()
        } catch { }
    }

    /// Applies pre-fetched saved item IDs (typically from LoginBootstrapper) so
    /// the favorites state lights up without a second Firestore round-trip.
    func applySavedItemIDs(_ ids: [String]) {
        savedProductIDs = Set(ids)
        if let uid = Auth.auth().currentUser?.uid {
            mergePendingFavorites(for: uid)
        }
        applySavedState()
    }

    /// Overlays queued ops on top of Firestore's savedItems so the heart
    /// icon reflects user intent before the syncer drains.
    private func mergePendingFavorites(for userID: String) {
        let ops = (try? PendingFavoritesStore.shared.allPending(for: userID)) ?? []
        for op in ops {
            switch op.kind {
            case .save: savedProductIDs.insert(op.productID)
            case .unsave: savedProductIDs.remove(op.productID)
            }
        }
    }

    private func applySavedState() {
        for index in products.indices {
            products[index].isFavorite = savedProductIDs.contains(products[index].id)
        }
    }

    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: productCacheKey),
              let cached = try? JSONDecoder().decode([Product].self, from: data)
        else { return }
        products = cached
    }

    private func saveToCache(_ products: [Product]) {
        guard let data = try? JSONEncoder().encode(products) else { return }
        UserDefaults.standard.set(data, forKey: productCacheKey)
    }

    private func startListening() {
        isLoading = true
        listener?.remove()
        listener = service.observeProducts { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let products):
                    self.products = products
                    self.applySavedState()
                    self.errorMessage = nil
                    self.prefetchImages(for: products)
                    self.saveToCache(products)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
                self.isLoading = false
            }
        }
    }
}
