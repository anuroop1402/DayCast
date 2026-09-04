import Foundation

/// One day of weather at a location, in Open-Meteo's metric defaults.
///
/// Units are encoded in the property names rather than a unit type: the app has a single
/// fixed unit system (see `docs/01-Solution-Planning.md` §3), so a `Measurement`-based API
/// would add ceremony without removing a real class of bug.
nonisolated struct DailyWeather: Hashable, Sendable {
    /// Local midnight for this forecast day, in the location's timezone.
    let date: Date

    let temperatureMaxCelsius: Double
    let temperatureMinCelsius: Double
    /// "Feels like" — accounts for wind and humidity, so it is the better comfort signal.
    let apparentTemperatureMaxCelsius: Double

    let precipitationSumMillimetres: Double
    /// Rain only, excluding snow. Tracked separately because rain and snow have opposite
    /// effects on skiing.
    let rainSumMillimetres: Double
    let snowfallSumCentimetres: Double
    let precipitationProbabilityMaxPercent: Double

    let windSpeedMaxKilometresPerHour: Double
    /// Gusts, not sustained wind — gusts are what close ski lifts and ruin a surf session.
    let windGustsMaxKilometresPerHour: Double

    let sunshineDurationSeconds: TimeInterval
    let daylightDurationSeconds: TimeInterval
    let uvIndexMax: Double

    /// `nil` means no marine data for these coordinates — an inland location, or a
    /// Marine API failure. Never treat this as "flat seas".
    let marine: MarineConditions?

    /// Returns a copy carrying sea state.
    ///
    /// Exists because land and marine forecasts are separate endpoints: the repository
    /// returns land data with `marine == nil`, and `GetActivityForecastUseCase` merges the
    /// two. Keeping `marine` a `let` means a day can never be mutated into an inconsistent
    /// state halfway through that merge.
    func withMarine(_ marine: MarineConditions?) -> DailyWeather {
        DailyWeather(
            date: date,
            temperatureMaxCelsius: temperatureMaxCelsius,
            temperatureMinCelsius: temperatureMinCelsius,
            apparentTemperatureMaxCelsius: apparentTemperatureMaxCelsius,
            precipitationSumMillimetres: precipitationSumMillimetres,
            rainSumMillimetres: rainSumMillimetres,
            snowfallSumCentimetres: snowfallSumCentimetres,
            precipitationProbabilityMaxPercent: precipitationProbabilityMaxPercent,
            windSpeedMaxKilometresPerHour: windSpeedMaxKilometresPerHour,
            windGustsMaxKilometresPerHour: windGustsMaxKilometresPerHour,
            sunshineDurationSeconds: sunshineDurationSeconds,
            daylightDurationSeconds: daylightDurationSeconds,
            uvIndexMax: uvIndexMax,
            marine: marine
        )
    }

    /// Fraction of available daylight that was sunny, 0...1.
    /// Normalising by daylight keeps winter days comparable with summer ones.
    var sunshineFraction: Double {
        guard daylightDurationSeconds > 0 else { return 0 }
        return min(1, max(0, sunshineDurationSeconds / daylightDurationSeconds))
    }
}
