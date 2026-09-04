import Foundation

/// Open-Meteo forecast response.
///
/// Open-Meteo returns *columnar* data — one array per variable, aligned by index with
/// `daily.time` — rather than an array of day objects. The mapper transposes it.
nonisolated struct ForecastResponseDTO: Decodable, Sendable {
    let utcOffsetSeconds: Int
    let daily: Daily

    /// Every value is optional. Open-Meteo omits or nulls variables it cannot produce for a
    /// given grid point or day, and a non-optional array would fail the whole response
    /// because one day was missing a UV index.
    nonisolated struct Daily: Decodable, Sendable {
        let time: [String]
        let weatherCode: [Int?]?
        let temperature2mMax: [Double?]?
        let temperature2mMin: [Double?]?
        let apparentTemperatureMax: [Double?]?
        let precipitationSum: [Double?]?
        let rainSum: [Double?]?
        let snowfallSum: [Double?]?
        let precipitationProbabilityMax: [Double?]?
        let windSpeed10mMax: [Double?]?
        let windGusts10mMax: [Double?]?
        let sunshineDuration: [Double?]?
        let daylightDuration: [Double?]?
        let uvIndexMax: [Double?]?

        /// Spelled out against Open-Meteo's `daily=` parameter list. See `OpenMeteoJSON`
        /// for why these are not derived from a key strategy.
        enum CodingKeys: String, CodingKey {
            case time
            case weatherCode = "weather_code"
            case temperature2mMax = "temperature_2m_max"
            case temperature2mMin = "temperature_2m_min"
            case apparentTemperatureMax = "apparent_temperature_max"
            case precipitationSum = "precipitation_sum"
            case rainSum = "rain_sum"
            case snowfallSum = "snowfall_sum"
            case precipitationProbabilityMax = "precipitation_probability_max"
            case windSpeed10mMax = "wind_speed_10m_max"
            case windGusts10mMax = "wind_gusts_10m_max"
            case sunshineDuration = "sunshine_duration"
            case daylightDuration = "daylight_duration"
            case uvIndexMax = "uv_index_max"
        }
    }

    enum CodingKeys: String, CodingKey {
        case utcOffsetSeconds = "utc_offset_seconds"
        case daily
    }
}
