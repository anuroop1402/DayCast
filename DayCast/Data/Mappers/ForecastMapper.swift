import Foundation

/// Transposes Open-Meteo's columnar response into `DailyWeather` values.
///
/// The API returns one array per variable, aligned by index with `daily.time`. Nothing
/// guarantees those arrays are the same length — a truncated response would otherwise crash
/// on an index — so every lookup is bounds-checked.
nonisolated enum ForecastMapper {

    static func map(_ dto: ForecastResponseDTO) -> [DailyWeather] {
        let daily = dto.daily

        return daily.time.indices.compactMap { index -> DailyWeather? in
            guard let date = ForecastDate.parse(daily.time[index]) else { return nil }

            // A day without temperatures cannot be scored for anything, so drop it rather
            // than invent a value. Softer variables fall back to a neutral default.
            guard
                let temperatureMax = value(daily.temperature2mMax, index),
                let temperatureMin = value(daily.temperature2mMin, index)
            else { return nil }

            return DailyWeather(
                date: date,
                temperatureMaxCelsius: temperatureMax,
                temperatureMinCelsius: temperatureMin,
                // Falls back to the dry-bulb maximum, which is the honest approximation
                // when "feels like" is unavailable.
                apparentTemperatureMaxCelsius: value(daily.apparentTemperatureMax, index)
                    ?? temperatureMax,
                precipitationSumMillimetres: value(daily.precipitationSum, index) ?? 0,
                rainSumMillimetres: value(daily.rainSum, index) ?? 0,
                snowfallSumCentimetres: value(daily.snowfallSum, index) ?? 0,
                precipitationProbabilityMaxPercent: value(daily.precipitationProbabilityMax, index) ?? 0,
                windSpeedMaxKilometresPerHour: value(daily.windSpeed10mMax, index) ?? 0,
                windGustsMaxKilometresPerHour: value(daily.windGusts10mMax, index)
                    ?? value(daily.windSpeed10mMax, index) ?? 0,
                sunshineDurationSeconds: value(daily.sunshineDuration, index) ?? 0,
                // Zero daylight would make `sunshineFraction` meaningless, so fall back to
                // a 12-hour day rather than divide into nothing.
                daylightDurationSeconds: value(daily.daylightDuration, index) ?? (12 * 3600),
                uvIndexMax: value(daily.uvIndexMax, index) ?? 0,
                marine: nil    // merged in by GetActivityForecastUseCase
            )
        }
    }

    private static func value(_ column: [Double?]?, _ index: Int) -> Double? {
        guard let column, column.indices.contains(index) else { return nil }
        return column[index]
    }
}
