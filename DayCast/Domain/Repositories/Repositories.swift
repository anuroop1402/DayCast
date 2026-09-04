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

    /// Sea state, keyed by forecast day.
    ///
    /// Throws for inland coordinates, and that is expected rather than exceptional — the
    /// caller is required to degrade surfing instead of failing the whole forecast.
    func marineForecast(for city: City, days: Int) async throws -> [Date: MarineConditions]
}

protocol RecentSearchesRepository: Sendable {
    func recentSearches() async throws -> [City]
    func save(_ city: City) async throws
    func clear() async throws
}
