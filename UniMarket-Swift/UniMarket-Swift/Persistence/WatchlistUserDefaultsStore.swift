// Persistence/WatchlistUserDefaultsStore.swift
// UniMarket-Swift
//
// UserDefaults-backed store for the user's watchlist.
// Persists WatchlistEntry objects (including display metadata) so the list renders
// without a network round-trip even on cold launch.
//
// Storage key: "unimarket.watchlist.<userID>"
// Encoded value: [WatchlistEntry] → JSON (each entry carries the product ID, title,
//   imageURL, originalPrice, and addedAt date — all needed for offline display).

import Foundation

final class WatchlistUserDefaultsStore {
    static let shared = WatchlistUserDefaultsStore()

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Key

    /// Per-spec storage key. Scoped to userID so multiple accounts on the same
    /// device never share watchlist data.
    private func key(for userID: String) -> String {
        "unimarket.watchlist.\(userID)"
    }

    // MARK: - Public API

    /// Returns all watched product IDs for the given user (spec-primary accessor).
    func loadIDs(for userID: String) -> [String] {
        loadEntries(for: userID).map(\.id)
    }

    /// Returns the full WatchlistEntry list for the given user.
    func loadEntries(for userID: String) -> [WatchlistEntry] {
        guard
            let data = defaults.data(forKey: key(for: userID)),
            let entries = try? JSONDecoder().decode([WatchlistEntry].self, from: data)
        else { return [] }
        return entries
    }

    /// Replaces the entire watched-entry list for the given user.
    func save(entries: [WatchlistEntry], for userID: String) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key(for: userID))
    }

    /// Appends an entry if a product with the same ID is not already present.
    func add(entry: WatchlistEntry, for userID: String) {
        var entries = loadEntries(for: userID)
        guard !entries.contains(where: { $0.id == entry.id }) else { return }
        entries.append(entry)
        save(entries: entries, for: userID)
    }

    /// Removes the entry whose `id` matches the given product ID.
    func remove(id: String, for userID: String) {
        save(
            entries: loadEntries(for: userID).filter { $0.id != id },
            for: userID
        )
    }

    /// Returns `true` when the given product ID is already being watched.
    func isWatched(id: String, for userID: String) -> Bool {
        loadEntries(for: userID).contains { $0.id == id }
    }

    /// Removes the watchlist for the given user (call on sign-out).
    func clear(for userID: String) {
        defaults.removeObject(forKey: key(for: userID))
    }
}
