import Foundation

/// City search, with the "don't bother" rule applied before the network is touched.
///
/// The trimming and the length floor live here rather than in the ViewModel because they
/// are policy, not presentation: any caller searching for cities wants them, and a second
/// caller should not have to remember to re-implement them.
nonisolated struct SearchCities: SearchCitiesUseCase {

    /// A one-character query matches thousands of places and tells the user nothing. The
    /// floor exists to stop the first keystroke of every search from becoming a request —
    /// debouncing in the ViewModel reduces *how often* we ask, this decides *whether* to.
    static let minimumQueryLength = 2

    private let repository: any CitySearchRepository

    init(repository: any CitySearchRepository) {
        self.repository = repository
    }

    func callAsFunction(query: String) async throws -> [City] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty and too-short queries return empty rather than throwing. "You have not
        // typed enough yet" is an idle state, not an error, and the UI should not show a
        // failure for it.
        guard trimmed.count >= Self.minimumQueryLength else { return [] }

        return try await repository.searchCities(matching: trimmed)
    }
}
