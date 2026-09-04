import Foundation

/// Outdoor sightseeing suitability — walking a city, viewpoints, parks, outdoor monuments.
///
/// The most "ordinary" of the four, and the one users have the strongest intuitions about,
/// so the model deliberately mirrors those: rain dominates, then comfort, then everything else.
///
/// **Precipitation uses the worse of amount and probability.** 0 mm with an 85% chance of
/// rain is not a good day out — you would carry a coat and change plans. Taking the minimum
/// of the two sub-scores means a bad signal on either axis is enough to mark the day down,
/// rather than being averaged away.
nonisolated struct OutdoorSightseeingRule: SuitabilityRule {

    let activity = Activity.outdoorSightseeing

    // MARK: - Weights (sum to 1.0)

    private static let precipitationWeight = 0.35
    private static let temperatureWeight = 0.25
    private static let windWeight = 0.15
    private static let sunshineWeight = 0.15
    private static let uvWeight = 0.10

    // MARK: - Thresholds

    /// 8 mm over a day is persistent rain, not a passing shower.
    private static let rainSpoilsDayMillimetres = 8.0
    /// Below this chance, rain is not worth planning around.
    private static let precipitationProbabilityIgnorablePercent = 20.0
    private static let precipitationProbabilityCertainPercent = 90.0

    /// Uses *apparent* temperature — wind chill and humidity are what you actually feel
    /// while walking around.
    private static let temperatureRisesFromCelsius = 0.0
    private static let temperatureIdealFromCelsius = 14.0
    private static let temperatureIdealToCelsius = 26.0
    private static let temperatureFallsToCelsius = 36.0

    private static let windPleasantKph = 15.0
    private static let windUnpleasantKph = 50.0

    /// Fraction of daylight that is sunny. Normalised by daylight so a bright winter day is
    /// not punished for being short.
    private static let sunshineDismalFraction = 0.1
    private static let sunshineGloriousFraction = 0.6

    /// Safety, not comfort: UV 11+ is "extreme" on the WHO scale.
    private static let uvComfortableIndex = 6.0
    private static let uvExtremeIndex = 11.0

    // MARK: - Reason triggers

    private static let notableRainMillimetres = 3.0
    private static let notableRainChancePercent = 60.0
    private static let notableWindKph = 35.0
    private static let notableSunshineFraction = 0.55

    func score(_ day: DailyWeather) -> SuitabilityScore {
        let factors = [
            precipitationFactor(day),
            temperatureFactor(day),
            windFactor(day),
            sunshineFactor(day),
            uvFactor(day)
        ]
        return SuitabilityScore(
            activity: activity,
            outcome: .scored(ScoreComposition.compose(factors)),
            reasons: ScoreComposition.reasons(from: factors)
        )
    }

    // MARK: - Factors

    private func precipitationFactor(_ day: DailyWeather) -> WeightedFactor {
        let byAmount = ScoringCurve.descending(
            day.precipitationSumMillimetres, oneAt: 0, zeroAt: Self.rainSpoilsDayMillimetres
        )
        let byChance = ScoringCurve.descending(
            day.precipitationProbabilityMaxPercent,
            oneAt: Self.precipitationProbabilityIgnorablePercent,
            zeroAt: Self.precipitationProbabilityCertainPercent
        )

        let reason: ScoreReason? = if day.precipitationSumMillimetres >= Self.notableRainMillimetres {
            ScoreReason(
                factor: .precipitation, sentiment: .unfavourable,
                detail: "\(day.precipitationSumMillimetres.reasonValue) mm of rain expected"
            )
        } else if day.precipitationProbabilityMaxPercent >= Self.notableRainChancePercent {
            ScoreReason(
                factor: .precipitation, sentiment: .unfavourable,
                detail: "\(day.precipitationProbabilityMaxPercent.roundedInt)% chance of rain"
            )
        } else if byAmount >= 0.99 && byChance >= 0.99 {
            ScoreReason(factor: .precipitation, sentiment: .favourable, detail: "Dry all day")
        } else {
            nil
        }

        return WeightedFactor(
            weight: Self.precipitationWeight,
            normalised: min(byAmount, byChance),
            reason: reason
        )
    }

    private func temperatureFactor(_ day: DailyWeather) -> WeightedFactor {
        let feels = day.apparentTemperatureMaxCelsius
        let normalised = ScoringCurve.band(
            feels,
            risesFrom: Self.temperatureRisesFromCelsius,
            idealFrom: Self.temperatureIdealFromCelsius,
            idealTo: Self.temperatureIdealToCelsius,
            fallsTo: Self.temperatureFallsToCelsius
        )
        let reason: ScoreReason? = if feels < Self.temperatureIdealFromCelsius {
            ScoreReason(
                factor: .temperature, sentiment: .unfavourable,
                detail: "Feels like \(feels.reasonValue) °C"
            )
        } else if feels > Self.temperatureIdealToCelsius {
            ScoreReason(
                factor: .temperature, sentiment: .unfavourable,
                detail: "Hot — feels like \(feels.reasonValue) °C"
            )
        } else {
            ScoreReason(
                factor: .temperature, sentiment: .favourable,
                detail: "Comfortable \(feels.reasonValue) °C"
            )
        }
        return WeightedFactor(weight: Self.temperatureWeight, normalised: normalised, reason: reason)
    }

    private func windFactor(_ day: DailyWeather) -> WeightedFactor {
        let wind = day.windSpeedMaxKilometresPerHour
        let normalised = ScoringCurve.descending(
            wind, oneAt: Self.windPleasantKph, zeroAt: Self.windUnpleasantKph
        )
        let reason: ScoreReason? = wind >= Self.notableWindKph
            ? ScoreReason(
                factor: .wind, sentiment: .unfavourable,
                detail: "Windy at \(wind.roundedInt) km/h"
              )
            : nil
        return WeightedFactor(weight: Self.windWeight, normalised: normalised, reason: reason)
    }

    private func sunshineFactor(_ day: DailyWeather) -> WeightedFactor {
        let fraction = day.sunshineFraction
        let normalised = ScoringCurve.ascending(
            fraction,
            zeroAt: Self.sunshineDismalFraction,
            oneAt: Self.sunshineGloriousFraction
        )
        let reason: ScoreReason? = fraction >= Self.notableSunshineFraction
            ? ScoreReason(factor: .sunshine, sentiment: .favourable, detail: "Mostly sunny")
            : nil
        return WeightedFactor(weight: Self.sunshineWeight, normalised: normalised, reason: reason)
    }

    private func uvFactor(_ day: DailyWeather) -> WeightedFactor {
        let normalised = ScoringCurve.descending(
            day.uvIndexMax, oneAt: Self.uvComfortableIndex, zeroAt: Self.uvExtremeIndex
        )
        let reason: ScoreReason? = day.uvIndexMax >= Self.uvExtremeIndex
            ? ScoreReason(
                factor: .uv, sentiment: .unfavourable,
                detail: "Extreme UV index \(day.uvIndexMax.roundedInt)"
              )
            : nil
        return WeightedFactor(weight: Self.uvWeight, normalised: normalised, reason: reason)
    }
}
