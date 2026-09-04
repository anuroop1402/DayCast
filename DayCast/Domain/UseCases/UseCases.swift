import Foundation

/// Application business rules. **ViewModels depend on these, never on repositories.**
///
/// Declared as protocols with a `callAsFunction` requirement so call sites read as the verb
/// they are — `try await searchCities(query: "Oslo")` — and so tests can substitute a stub
/// without a mocking framework.
///
/// Some of these are thin. That is deliberate: a uniform rule ("every operation is a use
/// case") is easier to defend and review than a per-operation judgement about whether an
/// operation has *enough* orchestration to deserve one. See `docs/02-Architecture-Decisions.md`.

protocol SearchCitiesUseCase: Sendable {
    /// Trims and validates the query; short queries return empty rather than hitting the network.
    func callAsFunction(query: String) async throws -> [City]
}

/// The one with real orchestration: two endpoints fetched concurrently, merged, scored,
/// with a partial-failure policy for missing marine data.
protocol GetActivityForecastUseCase: Sendable {
    func callAsFunction(city: City) async throws -> ActivityForecast
}

protocol GetRecentSearchesUseCase: Sendable {
    func callAsFunction() async throws -> [City]
}

protocol SaveRecentSearchUseCase: Sendable {
    /// De-duplicates and caps the list, most recent first.
    func callAsFunction(city: City) async throws
}

protocol ClearRecentSearchesUseCase: Sendable {
    func callAsFunction() async throws
}
