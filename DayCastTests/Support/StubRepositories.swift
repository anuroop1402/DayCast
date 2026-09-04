import Foundation
@testable import DayCast

/// Stubs at the repository seam, so use-case tests exercise real orchestration, real
/// merging and the real scoring engine — everything except the network.
///
/// `@unchecked Sendable` throughout: each is mutated only from the single task its test
/// runs, and an actor would force every assertion to `await` for no real concurrency.

final class StubCitySearchRepository: CitySearchRepository, @unchecked Sendable {

    var result: Result<[City], AppError> = .success([])
    private(set) var queries: [String] = []

    func searchCities(matching query: String) async throws -> [City] {
        queries.append(query)
        return try result.get()
    }
}

final class StubForecastRepository: ForecastRepository, @unchecked Sendable {

    var landResult: Result<[DailyWeather], any Error> = .success([])
    var marineResult: Result<[Date: MarineConditions], any Error> = .success([:])

    private(set) var landRequests: [(city: City, days: Int)] = []
    private(set) var marineRequests: [(city: City, days: Int)] = []

    func dailyForecast(for city: City, days: Int) async throws -> [DailyWeather] {
        landRequests.append((city, days))
        return try landResult.get()
    }

    func marineForecast(for city: City, days: Int) async throws -> [Date: MarineConditions] {
        marineRequests.append((city, days))
        return try marineResult.get()
    }
}

final class StubRecentSearchesRepository: RecentSearchesRepository, @unchecked Sendable {

    /// What storage currently holds. Tests seed it directly and assert on it afterwards.
    var stored: [City] = []
    /// Set to make reads fail, so the use case's error handling is exercised.
    var readError: AppError?
    private(set) var replaceCallCount = 0
    private(set) var clearCallCount = 0

    func recentSearches() async throws -> [City] {
        if let readError { throw readError }
        return stored
    }

    func replace(with cities: [City]) async throws {
        replaceCallCount += 1
        stored = cities
    }

    func clear() async throws {
        clearCallCount += 1
        stored = []
    }
}

// MARK: - Fixtures

extension City {
    static func fixture(
        id: Int = 1,
        name: String = "Oslo",
        country: String = "Norway",
        admin1: String? = "Oslo",
        latitude: Double = 59.9127,
        longitude: Double = 10.7461,
        timezone: String = "Europe/Oslo"
    ) -> City {
        City(
            id: id, name: name, country: country, admin1: admin1,
            latitude: latitude, longitude: longitude, timezone: timezone
        )
    }
}

extension Date {
    /// UTC midnight on a given day offset, matching how `ForecastDate` keys forecast days.
    static func forecastDay(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: 0).addingTimeInterval(TimeInterval(offset) * 86_400)
    }
}
