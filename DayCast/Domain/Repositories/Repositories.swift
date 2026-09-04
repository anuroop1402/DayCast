import Foundation

/// Data access, declared by the domain and implemented in `Data` — this inversion is what
/// keeps `Domain` free of `URLSession` and `UserDefaults`.
///
/// Split by concern rather than gathered into one `WeatherRepository`: geocoding, forecasts
/// and recent searches are three different aggregates with three different failure modes,
/// and a use case should not have to depend on methods it never calls.

protocol CitySearchRepository: Sendable {
    /// Throws `AppError`. Returns an empty array for a valid query with no matches;
    /// callers distinguish "nothing found" from "request failed".
    func searchCities(matching query: String) async throws -> [City]
}

protocol ForecastRepository: Sendable {
    /// Land forecast. Always returns `DailyWeather` with `marine == nil`; merging is the
    /// use case's job, not the repository's.
    func dailyForecast(for city: City, days: Int) async throws -> [DailyWeather]

    /// Sea state, keyed by forecast day. **Absence is normal, not an error.**
    ///
    /// I assumed inland coordinates would fail this request. They do not: Open-Meteo's
    /// Marine API returns `HTTP 200` with every value `null` for Prague. Verified against
    /// a captured fixture — see `marine-prague-inland.json`.
    ///
    /// So implementations return only the days that carry real data: an empty dictionary
    /// for an inland city, a partial one where the grid has gaps. Callers must degrade
    /// surfing for the missing days rather than treating absence as flat seas.
    func marineForecast(for city: City, days: Int) async throws -> [Date: MarineConditions]
}

protocol RecentSearchesRepository: Sendable {
    func recentSearches() async throws -> [City]

    /// Replaces the whole list.
    ///
    /// Deliberately not `save(_ city:)`. De-duplication and the ten-item cap are business
    /// rules, so they belong in `SaveRecentSearchUseCase`, which reads, applies them, and
    /// writes back. A `save(_ city:)` signature would force those rules down into storage —
    /// the repository would have to decide where the city goes and what falls off the end.
    /// Storage stays dumb; the domain keeps the policy.
    func replace(with cities: [City]) async throws

    func clear() async throws
}
