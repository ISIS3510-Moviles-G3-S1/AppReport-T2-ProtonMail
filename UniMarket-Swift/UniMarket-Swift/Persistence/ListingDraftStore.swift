import Foundation

actor ListingDraftStore {
    static let shared = ListingDraftStore()

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

    @discardableResult
    func save(
        draftID: String?,
        userID: String,
        title: String,
        priceText: String,
        conditionTag: String,
        listingDescription: String,
        tags: [String],
        imagesData: [Data]
    ) throws -> ListingDraft {
        let dir = try userDirectory(for: userID)
        let resolvedDraftID = draftID ?? UUID().uuidString
        let draft = ListingDraft(
            draftID: resolvedDraftID,
            userID: userID,
            title: title,
            priceText: priceText,
            conditionTag: conditionTag,
            listingDescription: listingDescription,
            tags: tags,
            imageCount: imagesData.count,
            savedAt: Date()
        )

        try removeImageSidecars(for: resolvedDraftID, in: dir)
        try writeDraft(draft, in: dir)
        for (index, data) in imagesData.enumerated() {
            let url = dir.appendingPathComponent(imageFilename(for: resolvedDraftID, index: index))
            try data.write(to: url, options: .atomic)
        }

        var index = (try? readIndex(in: dir)) ?? []
        if let existingIndex = index.firstIndex(where: { $0.draftID == resolvedDraftID }) {
            index[existingIndex] = draft
        } else {
            index.append(draft)
        }
        try writeIndex(index, in: dir)
        return draft
    }

    func allDrafts(for userID: String) throws -> [ListingDraft] {
        let dir = try userDirectory(for: userID)
        return (try? readIndex(in: dir)) ?? []
    }

    func materialize(_ draft: ListingDraft) throws -> ListingDraftPayload {
        let dir = try userDirectory(for: draft.userID)
        var images: [Data] = []
        for index in 0..<draft.imageCount {
            let url = dir.appendingPathComponent(imageFilename(for: draft.draftID, index: index))
            if let data = try? Data(contentsOf: url) {
                images.append(data)
            }
        }
        return ListingDraftPayload(draft: draft, imagesData: images)
    }

    func remove(draftID: String, userID: String) throws {
        let dir = try userDirectory(for: userID)
        try? fileManager.removeItem(at: dir.appendingPathComponent("\(draftID).json"))
        try removeImageSidecars(for: draftID, in: dir)

        var index = (try? readIndex(in: dir)) ?? []
        index.removeAll { $0.draftID == draftID }
        try writeIndex(index, in: dir)
    }

    func count(for userID: String) -> Int {
        guard let dir = try? userDirectory(for: userID) else { return 0 }
        return ((try? readIndex(in: dir)) ?? []).count
    }

    private func userDirectory(for userID: String) throws -> URL {
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = support
            .appendingPathComponent("UniMarket-Swift", isDirectory: true)
            .appendingPathComponent("ListingDrafts", isDirectory: true)
            .appendingPathComponent(sanitizedFilename(userID), isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func readIndex(in directory: URL) throws -> [ListingDraft] {
        let url = directory.appendingPathComponent(indexFilename)
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try decoder.decode([ListingDraft].self, from: data)
    }

    private func writeIndex(_ items: [ListingDraft], in directory: URL) throws {
        let url = directory.appendingPathComponent(indexFilename)
        let data = try encoder.encode(items.sorted { $0.savedAt > $1.savedAt })
        try data.write(to: url, options: .atomic)
    }

    private func writeDraft(_ draft: ListingDraft, in directory: URL) throws {
        let url = directory.appendingPathComponent("\(draft.draftID).json")
        let data = try encoder.encode(draft)
        try data.write(to: url, options: .atomic)
    }

    private func removeImageSidecars(for draftID: String, in directory: URL) throws {
        let contents = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in contents where name.hasPrefix("\(draftID).image.") {
            try? fileManager.removeItem(at: directory.appendingPathComponent(name))
        }
    }

    private func imageFilename(for draftID: String, index: Int) -> String {
        "\(draftID).image.\(index).jpg"
    }

    private func sanitizedFilename(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
    }
}
