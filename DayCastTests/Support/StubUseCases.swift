import Foundation
@testable import DayCast

/// Stubs at the use-case seam. ViewModel tests stop here — a ViewModel that reached a
/// repository would not compile against these, which is the boundary rule enforcing itself.

final class StubSearchCitiesUseCase: SearchCitiesUseCase, @unchecked Sendable {
    var result: Result<[City], any Error> = .success([])
    private(set) var queries: [String] = []

    func callAsFunction(query: String) async throws -> [City] {
        queries.append(query)
        return try result.get()
    }
}

final class StubGetActivityForecastUseCase: GetActivityForecastUseCase, @unchecked Sendable {
    var result: Result<ActivityForecast, any Error> = .success(ActivityForecast(city: .fixture(), days: []))
    private(set) var requestedCities: [City] = []

    func callAsFunction(city: City) async throws -> ActivityForecast {
        requestedCities.append(city)
        return try result.get()
    }
}

final class StubGetRecentSearchesUseCase: GetRecentSearchesUseCase, @unchecked Sendable {
    var result: Result<[City], any Error> = .success([])

    func callAsFunction() async throws -> [City] { try result.get() }
}

final class StubSaveRecentSearchUseCase: SaveRecentSearchUseCase, @unchecked Sendable {
    var error: (any Error)?
    private(set) var saved: [City] = []

    func callAsFunction(city: City) async throws {
        if let error { throw error }
        saved.append(city)
    }
}

final class StubClearRecentSearchesUseCase: ClearRecentSearchesUseCase, @unchecked Sendable {
    private(set) var callCount = 0

    func callAsFunction() async throws { callCount += 1 }
}

// MARK: - Building a real forecast for presentation tests

extension ActivityForecast {
    /// Scored by the real engine, so ratings and `insufficientData` outcomes in these tests
    /// are the ones the app actually produces — not values a stub asserted into existence.
    static func scored(city: City = .fixture(), days: [DailyWeather]) -> ActivityForecast {
        SuitabilityScoring().forecast(for: city, days: days)
    }
}
