import Foundation

/// Land and sea forecasts from Open-Meteo.
///
/// The two endpoints are exposed as separate methods rather than combined here: fetching
/// them concurrently and deciding what to do when marine data is missing is a policy
/// decision, and it lives in `GetActivityForecastUseCase`.
nonisolated struct OpenMeteoForecastRepository: ForecastRepository {

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func dailyForecast(for city: City, days: Int) async throws -> [DailyWeather] {
        let data = try await client.data(
            from: .forecast(latitude: city.latitude, longitude: city.longitude, days: days)
        )
        let response = try OpenMeteoJSON.decode(ForecastResponseDTO.self, from: data)

        let forecast = ForecastMapper.map(response)
        // Every day failed to map, or the window was empty. Distinct from a transport
        // failure, and the caller shows an empty state rather than a retry prompt.
        guard !forecast.isEmpty else { throw AppError.noResults }
        return forecast
    }

    func marineForecast(for city: City, days: Int) async throws -> [Date: MarineConditions] {
        let data = try await client.data(
            from: .marine(latitude: city.latitude, longitude: city.longitude, days: days)
        )
        let response = try OpenMeteoJSON.decode(MarineResponseDTO.self, from: data)

        // Returns an empty dictionary for an inland city. That is a valid answer, not an
        // error — see the protocol's contract note.
        return MarineMapper.map(response)
    }
}
