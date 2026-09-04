import Testing
import Foundation
@testable import DayCast

/// Repositories are tested through the `HTTPClient` seam, so each test exercises the real
/// URL construction, the real JSON decoding and the real mapping — not a stub of them.
struct CitySearchRepositoryTests {

    @Test("A successful search returns mapped cities")
    func returnsCities() async throws {
        let client = StubHTTPClient()
        try client.stub(host: client.geocodingHost, fixture: "geocoding-oslo.json")

        let cities = try await OpenMeteoCitySearchRepository(client: client)
            .searchCities(matching: "Oslo")

        #expect(cities.count == 5)
        #expect(cities.first?.name == "Oslo")
    }

    @Test("No matches returns an empty array rather than throwing")
    func noMatchesIsEmptyNotAnError() async throws {
        let client = StubHTTPClient()
        try client.stub(host: client.geocodingHost, fixture: "geocoding-no-results.json")

        let cities = try await OpenMeteoCitySearchRepository(client: client)
            .searchCities(matching: "zzzqqqxyz")

        #expect(cities.isEmpty)
    }

    @Test("The query reaches the request unmodified")
    func queryIsForwarded() async throws {
        let client = StubHTTPClient()
        try client.stub(host: client.geocodingHost, fixture: "geocoding-oslo.json")

        _ = try await OpenMeteoCitySearchRepository(client: client).searchCities(matching: "Bergen")

        let sent = try #require(client.requested.first)
        #expect(sent.queryItems.contains { $0.name == "name" && $0.value == "Bergen" })
    }

    @Test("Transport failures surface as AppError")
    func transportFailurePropagates() async throws {
        let client = StubHTTPClient()
        client.stub(host: client.geocodingHost, with: .failure(.offline))

        await #expect(throws: AppError.offline) {
            try await OpenMeteoCitySearchRepository(client: client).searchCities(matching: "Oslo")
        }
    }

    @Test("Malformed JSON becomes AppError.decoding, not a raw DecodingError")
    func malformedJSONIsMapped() async throws {
        let client = StubHTTPClient()
        client.stub(host: client.geocodingHost, with: .success(Data("not json".utf8)))

        await #expect(throws: AppError.decoding) {
            try await OpenMeteoCitySearchRepository(client: client).searchCities(matching: "Oslo")
        }
    }
}

struct ForecastRepositoryTests {

    private func repository(
        forecast: String? = "forecast-oslo.json",
        marine: String? = nil,
        marineFailure: AppError? = nil
    ) throws -> (OpenMeteoForecastRepository, StubHTTPClient) {
        let client = StubHTTPClient()
        if let forecast { try client.stub(host: client.forecastHost, fixture: forecast) }
        if let marine { try client.stub(host: client.marineHost, fixture: marine) }
        if let marineFailure { client.stub(host: client.marineHost, with: .failure(marineFailure)) }
        return (OpenMeteoForecastRepository(client: client), client)
    }

    private let oslo = City(
        id: 3143244, name: "Oslo", country: "Norway", admin1: "Oslo",
        latitude: 59.9127, longitude: 10.7461, timezone: "Europe/Oslo"
    )

    @Test("Daily forecast maps a full week")
    func dailyForecast() async throws {
        let (repo, _) = try repository()
        let days = try await repo.dailyForecast(for: oslo, days: 7)

        #expect(days.count == 7)
        #expect(days.first?.temperatureMaxCelsius == 16.4)
    }

    @Test("The city's coordinates reach the request")
    func coordinatesAreForwarded() async throws {
        let (repo, client) = try repository()
        _ = try await repo.dailyForecast(for: oslo, days: 7)

        let sent = try #require(client.requested.first)
        #expect(sent.queryItems.contains { $0.name == "latitude" && $0.value == "59.9127" })
    }

    @Test("A coastal city yields marine data for every day")
    func coastalMarine() async throws {
        let (repo, _) = try repository(marine: "marine-biarritz-coastal.json")
        #expect(try await repo.marineForecast(for: oslo, days: 7).count == 7)
    }

    @Test("An inland city yields an empty dictionary, not an error")
    func inlandMarineIsEmpty() async throws {
        let (repo, _) = try repository(marine: "marine-prague-inland.json")
        #expect(try await repo.marineForecast(for: oslo, days: 7).isEmpty)
    }

    @Test("Marine transport failures still throw — the use case decides what to do")
    func marineFailureThrows() async throws {
        let (repo, _) = try repository(marineFailure: .offline)
        await #expect(throws: AppError.offline) {
            try await repo.marineForecast(for: oslo, days: 7)
        }
    }

    @Test("Forecast and marine dates align so the merge can key on them")
    func datesAlign() async throws {
        let client = StubHTTPClient()
        try client.stub(host: client.forecastHost, fixture: "forecast-oslo.json")
        try client.stub(host: client.marineHost, fixture: "marine-biarritz-coastal.json")
        let repo = OpenMeteoForecastRepository(client: client)

        let days = try await repo.dailyForecast(for: oslo, days: 7)
        let marine = try await repo.marineForecast(for: oslo, days: 7)

        // Both fixtures cover the same calendar week. If date parsing were timezone
        // sensitive, these sets would diverge and every marine lookup would silently miss.
        #expect(Set(days.map(\.date)) == Set(marine.keys))
    }

    @Test("A response with no usable days is AppError.noResults")
    func emptyForecastIsNoResults() async throws {
        let client = StubHTTPClient()
        let empty = Data(#"{"utc_offset_seconds":0,"daily":{"time":[]}}"#.utf8)
        client.stub(host: client.forecastHost, with: .success(empty))

        await #expect(throws: AppError.noResults) {
            try await OpenMeteoForecastRepository(client: client).dailyForecast(for: oslo, days: 7)
        }
    }
}

struct RecentSearchesRepositoryTests {

    /// Isolated suite per test so nothing touches the real user defaults.
    private func makeRepository() -> UserDefaultsRecentSearchesRepository {
        let suite = "test.\(UUID().uuidString)"
        return UserDefaultsRecentSearchesRepository(
            defaults: UserDefaults(suiteName: suite)!, key: "recent"
        )
    }

    private func city(_ id: Int, _ name: String) -> City {
        City(id: id, name: name, country: "Norway", admin1: nil,
             latitude: 0, longitude: 0, timezone: "Europe/Oslo")
    }

    @Test("Starts empty")
    func startsEmpty() async throws {
        #expect(try await makeRepository().recentSearches().isEmpty)
    }

    @Test("Round-trips through storage in order")
    func roundTrips() async throws {
        let repo = makeRepository()
        let cities = [city(1, "Oslo"), city(2, "Bergen")]

        try await repo.replace(with: cities)
        #expect(try await repo.recentSearches() == cities)
    }

    @Test("Replace overwrites rather than appending")
    func replaceOverwrites() async throws {
        let repo = makeRepository()
        try await repo.replace(with: [city(1, "Oslo")])
        try await repo.replace(with: [city(2, "Bergen")])

        #expect(try await repo.recentSearches() == [city(2, "Bergen")])
    }

    @Test("Clear empties the list")
    func clearEmpties() async throws {
        let repo = makeRepository()
        try await repo.replace(with: [city(1, "Oslo")])
        try await repo.clear()

        #expect(try await repo.recentSearches().isEmpty)
    }

    @Test("Corrupt stored data degrades to empty rather than throwing")
    func corruptDataIsSurvivable() async throws {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(Data("garbage".utf8), forKey: "recent")

        let repo = UserDefaultsRecentSearchesRepository(defaults: defaults, key: "recent")
        // Losing ten search shortcuts is not worth an error state or a migration.
        #expect(try await repo.recentSearches().isEmpty)
    }
}

struct URLErrorMappingTests {

    @Test("Connectivity failures map to .offline", arguments: [
        URLError.Code.notConnectedToInternet, .networkConnectionLost,
        .dataNotAllowed, .cannotConnectToHost, .cannotFindHost
    ])
    func offlineMapping(code: URLError.Code) {
        #expect(URLSessionHTTPClient.mapped(URLError(code)) == .offline)
    }

    @Test("Timeouts map to .timedOut")
    func timeoutMapping() {
        #expect(URLSessionHTTPClient.mapped(URLError(.timedOut)) == .timedOut)
    }

    @Test("Cancellation is distinct so debounced searches never show an error")
    func cancellationMapping() {
        // A superseded search is routine while typing; surfacing it would flash an error
        // banner on every keystroke.
        #expect(URLSessionHTTPClient.mapped(URLError(.cancelled)) == .cancelled)
        #expect(AppError.cancelled.isRetryable == false)
    }

    @Test("Unknown failures fall back to .unexpected")
    func unknownMapping() {
        #expect(URLSessionHTTPClient.mapped(URLError(.badServerResponse)) == .unexpected)
    }

    @Test("Retryability drives whether the UI offers a retry button")
    func retryability() {
        #expect(AppError.offline.isRetryable)
        #expect(AppError.timedOut.isRetryable)
        #expect(AppError.server(statusCode: 500).isRetryable)
        #expect(!AppError.decoding.isRetryable)
        #expect(!AppError.noResults.isRetryable)
    }
}
