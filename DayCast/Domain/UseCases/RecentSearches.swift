import Foundation

/// Reads the stored list. Thin by design — see the note in `UseCases.swift`.
nonisolated struct GetRecentSearches: GetRecentSearchesUseCase {

    private let repository: any RecentSearchesRepository

    init(repository: any RecentSearchesRepository) {
        self.repository = repository
    }

    func callAsFunction() async throws -> [City] {
        try await repository.recentSearches()
    }
}

/// Records a search, applying the two rules that make the list useful.
///
/// This is where `RecentSearchesRepository.replace(with:)` pays for itself. De-duplication
/// and the cap are business rules: searching Oslo twice should move it to the top rather
/// than list it twice, and the list should stay short enough to scan. A `save(_ city:)`
/// signature would push both decisions into `UserDefaults` code, where they are neither
/// visible nor testable without a persistence layer.
nonisolated struct SaveRecentSearch: SaveRecentSearchUseCase {

    /// Long enough to be useful, short enough to scan without scrolling.
    static let maximumCount = 10

    private let repository: any RecentSearchesRepository

    init(repository: any RecentSearchesRepository) {
        self.repository = repository
    }

    func callAsFunction(city: City) async throws {
        let existing = try await repository.recentSearches()

        // Most recent first, and a re-search promotes rather than duplicates. Matched on
        // `id` — Open-Meteo's geocoding identifier — because two genuinely different
        // places share a name often enough that name matching would silently merge them.
        let promoted = [city] + existing.filter { $0.id != city.id }

        try await repository.replace(with: Array(promoted.prefix(Self.maximumCount)))
    }
}

nonisolated struct ClearRecentSearches: ClearRecentSearchesUseCase {

    private let repository: any RecentSearchesRepository

    init(repository: any RecentSearchesRepository) {
        self.repository = repository
    }

    func callAsFunction() async throws {
        try await repository.clear()
    }
}
