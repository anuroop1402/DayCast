import Foundation

/// Recent searches, persisted as JSON in `UserDefaults`.
///
/// `@unchecked Sendable`: `UserDefaults` is documented as thread-safe but is not annotated
/// `Sendable` in the SDK. The unchecked conformance is confined to this one type rather
/// than being worked around with an actor, which would make every call site `await` for no
/// real concurrency benefit.
nonisolated struct UserDefaultsRecentSearchesRepository: RecentSearchesRepository, @unchecked Sendable {

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "recent_searches") {
        self.defaults = defaults
        self.key = key
    }

    func recentSearches() async throws -> [City] {
        guard let data = defaults.data(forKey: key) else { return [] }
        // Stored data written by an older version of `City` will fail to decode. Treat that
        // as an empty list rather than an error: the worst case is a user losing ten
        // search shortcuts, which is not worth an error state or a migration.
        return (try? JSONDecoder().decode([City].self, from: data)) ?? []
    }

    func replace(with cities: [City]) async throws {
        guard let data = try? JSONEncoder().encode(cities) else { throw AppError.unexpected }
        defaults.set(data, forKey: key)
    }

    func clear() async throws {
        defaults.removeObject(forKey: key)
    }
}
