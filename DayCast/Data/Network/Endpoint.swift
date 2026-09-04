import Foundation

/// A URL to build. Open-Meteo splits its APIs across three hosts, so the host is part of
/// the endpoint rather than baked into the client.
nonisolated struct Endpoint: Sendable, Equatable {
    let host: String
    let path: String
    let queryItems: [URLQueryItem]

    var url: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = queryItems
        return components.url
    }
}

extension Endpoint {

    /// Daily variables requested from the forecast API, in the order the mapper expects.
    /// Kept as one constant so the request and the DTO cannot drift apart.
    static let forecastDailyVariables = [
        "weather_code", "temperature_2m_max", "temperature_2m_min",
        "apparent_temperature_max", "precipitation_sum", "rain_sum", "snowfall_sum",
        "precipitation_probability_max", "wind_speed_10m_max", "wind_gusts_10m_max",
        "sunshine_duration", "daylight_duration", "uv_index_max"
    ]

    static let marineDailyVariables = [
        "wave_height_max", "swell_wave_height_max", "swell_wave_period_max"
    ]

    static func geocoding(query: String, count: Int = 10) -> Endpoint {
        Endpoint(
            host: "geocoding-api.open-meteo.com",
            path: "/v1/search",
            queryItems: [
                URLQueryItem(name: "name", value: query),
                URLQueryItem(name: "count", value: String(count)),
                URLQueryItem(name: "language", value: "en"),
                URLQueryItem(name: "format", value: "json")
            ]
        )
    }

    static func forecast(latitude: Double, longitude: Double, days: Int) -> Endpoint {
        Endpoint(
            host: "api.open-meteo.com",
            path: "/v1/forecast",
            queryItems: coordinateItems(latitude, longitude) + [
                URLQueryItem(name: "daily", value: forecastDailyVariables.joined(separator: ",")),
                URLQueryItem(name: "timezone", value: "auto"),
                URLQueryItem(name: "forecast_days", value: String(days))
            ]
        )
    }

    static func marine(latitude: Double, longitude: Double, days: Int) -> Endpoint {
        Endpoint(
            host: "marine-api.open-meteo.com",
            path: "/v1/marine",
            queryItems: coordinateItems(latitude, longitude) + [
                URLQueryItem(name: "daily", value: marineDailyVariables.joined(separator: ",")),
                URLQueryItem(name: "timezone", value: "auto"),
                URLQueryItem(name: "forecast_days", value: String(days))
            ]
        )
    }

    /// Four decimal places is ~11 m — far finer than the forecast grid, and it keeps URLs
    /// stable so responses cache cleanly.
    private static func coordinateItems(_ latitude: Double, _ longitude: Double) -> [URLQueryItem] {
        [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", longitude))
        ]
    }
}
