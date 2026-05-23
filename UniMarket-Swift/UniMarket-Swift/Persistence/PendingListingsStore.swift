import Foundation

// File-backed queue for offline listing creates. Synchronous I/O — callers
// should dispatch via Task.detached. See EvCon.md §1 for the layout.
final class PendingListingsStore {
    static let shared = PendingListingsStore()

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let indexFilename = "index.json"

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Public API

    @discardableResult
    func enqueue(input: CreateProductInput, userID: String) throws -> PendingListing {
        let pending = PendingListing(
            pendingID: UUID().uuidString,
            userID: userID,
            title: input.title,
            price: input.price,
            conditionTag: input.conditionTag,
            listingDescription: input.description,
            tags: input.tags,
            imageCount: input.imagesData.count,
            queuedAt: Date(),
            lastTriedAt: nil,
            retryCount: 0,
            lastError: nil,
            kindRaw: input.kind.rawValue
        )

        let dir = try userDirectory(for: userID)
        try writeListing(pending, in: dir)
        for (i, data) in input.imagesData.enumerated() {
            let url = dir.appendingPathComponent(imageFilename(for: pending.pendingID, index: i))
            try data.write(to: url, options: .atomic)
        }

        var index = (try? readIndex(in: dir)) ?? []
        index.append(pending)
        try writeIndex(index, in: dir)
        return pending
    }

    func allPending(for userID: String) throws -> [PendingListing] {
        let dir = try userDirectory(for: userID)
        return (try? readIndex(in: dir)) ?? []
    }

    func count(for userID: String) -> Int {
        guard let dir = try? userDirectory(for: userID) else { return 0 }
        return ((try? readIndex(in: dir)) ?? []).count
    }

    /// Reconstructs a CreateProductInput by re-reading the JPEG sidecars.
    func materialize(_ pending: PendingListing) throws -> CreateProductInput {
        let dir = try userDirectory(for: pending.userID)
        var images: [Data] = []
        for i in 0..<pending.imageCount {
            let url = dir.appendingPathComponent(imageFilename(for: pending.pendingID, index: i))
            let data = try Data(contentsOf: url)
            images.append(data)
        }
        return CreateProductInput(
            title: pending.title,
            price: pending.price,
            conditionTag: pending.conditionTag,
            description: pending.listingDescription,
            imagesData: images,
            tags: pending.tags,
            kind: ListingKind(firestoreValue: pending.kindRaw)
        )
    }

    func remove(pendingID: String, userID: String) throws {
        let dir = try userDirectory(for: userID)
        let listingURL = dir.appendingPathComponent("\(pendingID).json")
        try? fileManager.removeItem(at: listingURL)
        // Sweep image sidecars by prefix — we don't have imageCount here.
        if let contents = try? fileManager.contentsOfDirectory(atPath: dir.path) {
            for name in contents where name.hasPrefix("\(pendingID).image.") {
                try? fileManager.removeItem(at: dir.appendingPathComponent(name))
            }
        }

        var index = (try? readIndex(in: dir)) ?? []
        index.removeAll { $0.pendingID == pendingID }
        try writeIndex(index, in: dir)
    }

    /// Removes the entire per-user queue directory. Called at sign-out.
    func clearUserQueue(for userID: String) throws {
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let dir = support
            .appendingPathComponent("UniMarket-Swift", isDirectory: true)
            .appendingPathComponent("PendingListings", isDirectory: true)
            .appendingPathComponent(sanitizedFilename(userID), isDirectory: true)
        guard fileManager.fileExists(atPath: dir.path) else { return }
        try fileManager.removeItem(at: dir)
    }

    func bumpRetry(pendingID: String, userID: String, error: Error) throws {
        let dir = try userDirectory(for: userID)
        var index = (try? readIndex(in: dir)) ?? []
        guard let idx = index.firstIndex(where: { $0.pendingID == pendingID }) else { return }
        index[idx].retryCount += 1
        index[idx].lastTriedAt = Date()
        index[idx].lastError = error.localizedDescription
        try writeListing(index[idx], in: dir)
        try writeIndex(index, in: dir)
    }

    // MARK: - Filesystem helpers

    private func userDirectory(for userID: String) throws -> URL {
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = support
            .appendingPathComponent("UniMarket-Swift", isDirectory: true)
            .appendingPathComponent("PendingListings", isDirectory: true)
            .appendingPathComponent(sanitizedFilename(userID), isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func readIndex(in directory: URL) throws -> [PendingListing] {
        let url = directory.appendingPathComponent(indexFilename)
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try decoder.decode([PendingListing].self, from: data)
    }

    private func writeIndex(_ items: [PendingListing], in directory: URL) throws {
        let url = directory.appendingPathComponent(indexFilename)
        let data = try encoder.encode(items.sorted { $0.queuedAt < $1.queuedAt })
        try data.write(to: url, options: .atomic)
    }

    private func writeListing(_ pending: PendingListing, in directory: URL) throws {
        let url = directory.appendingPathComponent("\(pending.pendingID).json")
        let data = try encoder.encode(pending)
        try data.write(to: url, options: .atomic)
    }

    private func imageFilename(for pendingID: String, index: Int) -> String {
        "\(pendingID).image.\(index).jpg"
    }

    private func sanitizedFilename(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
    }
}
