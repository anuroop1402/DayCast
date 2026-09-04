import Testing
import Foundation
@testable import DayCast

// MARK: - Search

struct SearchCitiesTests {

    @Test("A query long enough to be useful reaches the repository, trimmed")
    func trimsAndForwards() async throws {
        let repository = StubCitySearchRepository()
        repository.result = .success([.fixture()])

        let cities = try await SearchCities(repository: repository)(query: "  Oslo \n")

        #expect(repository.queries == ["Oslo"])
        #expect(cities.count == 1)
    }

    @Test("A query below the length floor returns empty without a request")
    func shortQueryDoesNotHitTheNetwork() async throws {
        let repository = StubCitySearchRepository()
        repository.result = .failure(.offline)   // would throw if it were ever called

        let cities = try await SearchCities(repository: repository)(query: "O")

        #expect(cities.isEmpty)
        #expect(repository.queries.isEmpty)
    }

    @Test("Whitespace alone is not a query")
    func whitespaceOnlyDoesNotHitTheNetwork() async throws {
        let repository = StubCitySearchRepository()
        repository.result = .failure(.offline)

        let cities = try await SearchCities(repository: repository)(query: "     ")

        #expect(cities.isEmpty)
        #expect(repository.queries.isEmpty)
    }

    @Test("No matches is an empty result, not an error")
    func noMatchesIsEmpty() async throws {
        let repository = StubCitySearchRepository()
        repository.result = .success([])

        let cities = try await SearchCities(repository: repository)(query: "zzzqqq")

        #expect(cities.isEmpty)
    }

    @Test("Repository failures propagate")
    func failurePropagates() async throws {
        let repository = StubCitySearchRepository()
        repository.result = .failure(.offline)

        await #expect(throws: AppError.offline) {
            try await SearchCities(repository: repository)(query: "Oslo")
        }
    }
}

// MARK: - Forecast orchestration

struct GetActivityForecastTests {

    /// A coastal city's week: three days, only the middle one carrying real swell.
    private func coastalWeek() -> [DailyWeather] {
        (0..<3).map { offset in
            DailyWeather.fixture(
                date: .forecastDay(offset),
                temperatureMax: 21, apparentTemperatureMax: 20,
                windSpeedMax: 8, windGustsMax: 14,
                sunshineDuration: 8 * 3600, daylightDuration: 13 * 3600, uvIndexMax: 6
            )
        }
    }

    private let goodSwell = MarineConditions(
        swellWaveHeightMax: 1.6, swellWavePeriodMax: 13, waveHeightMax: 1.9
    )

    @Test("Both endpoints are asked for the same 7-day window")
    func requestsBothEndpointsForTheSameWindow() async throws {
        let repository = StubForecastRepository()
        repository.landResult = .success(coastalWeek())
        let city = City.fixture()

        _ = try await GetActivityForecast(repository: repository)(city: city)

        #expect(repository.landRequests.count == 1)
        #expect(repository.marineRequests.count == 1)
        #expect(repository.landRequests.first?.days == GetActivityForecast.forecastDays)
        #expect(repository.marineRequests.first?.days == GetActivityForecast.forecastDays)
    }

    @Test("Marine data merges onto the matching day and surfing scores")
    func mergesMarineOntoTheMatchingDay() async throws {
        let repository = StubForecastRepository()
        repository.landResult = .success(coastalWeek())
        repository.marineResult = .success([.forecastDay(1): goodSwell])

        let forecast = try await GetActivityForecast(repository: repository)(city: .fixture())

        let scored = try #require(forecast.days.first { $0.date == .forecastDay(1) })
        #expect(scored.weather.marine == goodSwell)
        #expect(scored.score(for: .surfing)?.value != nil)
    }

    // MARK: The partial-failure policy

    @Test("A marine failure degrades surfing alone — every other activity still scores")
    func marineFailureDegradesSurfingOnly() async throws {
        let repository = StubForecastRepository()
        repository.landResult = .success(coastalWeek())
        repository.marineResult = .failure(AppError.server(statusCode: 503))

        let forecast = try await GetActivityForecast(repository: repository)(city: .fixture())

        #expect(forecast.days.count == 3)
        for day in forecast.days {
            #expect(day.score(for: .surfing)?.outcome == .insufficientData)
            for activity in [Activity.skiing, .outdoorSightseeing, .indoorSightseeing] {
                #expect(day.score(for: activity)?.value != nil, "\(activity) lost its score")
            }
        }
    }

    @Test("An inland city — HTTP 200 with no usable days — behaves the same as a failure")
    func inlandCityDegradesSurfingOnly() async throws {
        let repository = StubForecastRepository()
        repository.landResult = .success(coastalWeek())
        repository.marineResult = .success([:])

        let forecast = try await GetActivityForecast(repository: repository)(city: .fixture())

        #expect(forecast.days.allSatisfy { $0.score(for: .surfing)?.outcome == .insufficientData })
        #expect(forecast.days.allSatisfy { $0.score(for: .outdoorSightseeing)?.value != nil })
        // And no day is nominated as the best surf day, rather than an arbitrary one.
        #expect(forecast.bestDay(for: .surfing) == nil)
        #expect(forecast.bestDay(for: .outdoorSightseeing) != nil)
    }

    @Test("Degradation is per-day: a gap in the marine grid loses only the days it covers")
    func degradationIsPerDay() async throws {
        let repository = StubForecastRepository()
        repository.landResult = .success(coastalWeek())
        repository.marineResult = .success([
            .forecastDay(0): goodSwell,
            .forecastDay(2): goodSwell
        ])

        let forecast = try await GetActivityForecast(repository: repository)(city: .fixture())

        #expect(forecast.days[0].score(for: .surfing)?.value != nil)
        #expect(forecast.days[1].score(for: .surfing)?.outcome == .insufficientData)
        #expect(forecast.days[2].score(for: .surfing)?.value != nil)
    }

    @Test("Surfing's missing-data reason names the cause, so the UI need not invent copy")
    func insufficientDataCarriesAReason() async throws {
        let repository = StubForecastRepository()
        repository.landResult = .success(coastalWeek())
        repository.marineResult = .success([:])

        let forecast = try await GetActivityForecast(repository: repository)(city: .fixture())

        let surfing = try #require(forecast.days.first?.score(for: .surfing))
        #expect(surfing.rating == .unknown)
        #expect(surfing.reasons.contains { $0.factor == .dataAvailability })
    }

    // MARK: Land is not optional

    @Test("A land-forecast failure fails the whole request — there is nothing to score")
    func landFailurePropagates() async throws {
        let repository = StubForecastRepository()
        repository.landResult = .failure(AppError.offline)
        repository.marineResult = .success([:])

        await #expect(throws: AppError.offline) {
            try await GetActivityForecast(repository: repository)(city: .fixture())
        }
    }

    @Test("Cancellation is not mistaken for missing sea data")
    func marineCancellationPropagates() async throws {
        let repository = StubForecastRepository()
        repository.landResult = .success(coastalWeek())
        repository.marineResult = .failure(AppError.cancelled)

        await #expect(throws: AppError.cancelled) {
            try await GetActivityForecast(repository: repository)(city: .fixture())
        }
    }

    @Test("The city travels through to the finished forecast")
    func carriesTheCity() async throws {
        let repository = StubForecastRepository()
        repository.landResult = .success(coastalWeek())
        let city = City.fixture(id: 42, name: "Biarritz")

        let forecast = try await GetActivityForecast(repository: repository)(city: city)

        #expect(forecast.city == city)
    }
}

// MARK: - Recent searches

struct RecentSearchesUseCaseTests {

    private func city(_ id: Int) -> City { .fixture(id: id, name: "City \(id)") }

    @Test("A new search goes to the front")
    func newSearchIsPrepended() async throws {
        let repository = StubRecentSearchesRepository()
        repository.stored = [city(1), city(2)]

        try await SaveRecentSearch(repository: repository)(city: city(3))

        #expect(repository.stored.map(\.id) == [3, 1, 2])
    }

    @Test("Re-searching a city promotes it instead of duplicating it")
    func reSearchPromotesRatherThanDuplicates() async throws {
        let repository = StubRecentSearchesRepository()
        repository.stored = [city(1), city(2), city(3)]

        try await SaveRecentSearch(repository: repository)(city: city(3))

        #expect(repository.stored.map(\.id) == [3, 1, 2])
        #expect(repository.stored.count == 3)
    }

    @Test("The list is capped, dropping the oldest")
    func listIsCapped() async throws {
        let repository = StubRecentSearchesRepository()
        repository.stored = (1...SaveRecentSearch.maximumCount).map(city)

        try await SaveRecentSearch(repository: repository)(city: city(99))

        #expect(repository.stored.count == SaveRecentSearch.maximumCount)
        #expect(repository.stored.first?.id == 99)
        #expect(!repository.stored.contains { $0.id == SaveRecentSearch.maximumCount })
    }

    @Test("Saving into empty storage works")
    func savesIntoEmptyStorage() async throws {
        let repository = StubRecentSearchesRepository()

        try await SaveRecentSearch(repository: repository)(city: city(1))

        #expect(repository.stored.map(\.id) == [1])
    }

    @Test("Reading returns what storage holds")
    func readsStoredList() async throws {
        let repository = StubRecentSearchesRepository()
        repository.stored = [city(1), city(2)]

        let cities = try await GetRecentSearches(repository: repository)()

        #expect(cities.map(\.id) == [1, 2])
    }

    @Test("Clearing empties the list")
    func clearEmptiesTheList() async throws {
        let repository = StubRecentSearchesRepository()
        repository.stored = [city(1)]

        try await ClearRecentSearches(repository: repository)()

        #expect(repository.stored.isEmpty)
        #expect(repository.clearCallCount == 1)
    }

    @Test("A failed read does not overwrite storage with a truncated list")
    func failedReadDoesNotWrite() async throws {
        let repository = StubRecentSearchesRepository()
        repository.stored = [city(1), city(2)]
        repository.readError = .unexpected

        await #expect(throws: AppError.unexpected) {
            try await SaveRecentSearch(repository: repository)(city: city(3))
        }
        #expect(repository.replaceCallCount == 0)
        #expect(repository.stored.map(\.id) == [1, 2])
    }
}
