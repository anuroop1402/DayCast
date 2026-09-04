import Foundation

/// Surfing suitability.
///
/// **Why the Marine API.** The brief names the Geocoding and Forecast APIs, neither of which
/// exposes wave data. Inferring surf from wind speed is a poor proxy: wind produces local
/// chop, while surfable waves are *swell* — organised energy that has travelled from a
/// distant storm. Open-Meteo's Marine API gives real swell height and period, so this rule
/// uses it. See `docs/01-Solution-Planning.md` §5.
///
/// **Two gates.**
///
/// *Marine data* — inland cities have none. Scoring 0 would imply we checked and the surf
/// was flat; `insufficientData` says we could not tell. The user should not be told Prague
/// has bad waves.
///
/// *Swell height* — a rideable wave is a precondition, not something you trade against
/// wind. This was originally a 40%-weighted additive factor, which let a clean period and
/// a warm afternoon drag a dangerous 4.2 m day up to 53/100 and a flat sea to 12/100.
/// Same flaw as `SkiingRule` had with snow: **the absence of negatives standing in for the
/// presence of a prerequisite.**
nonisolated struct SurfingRule: SuitabilityRule {

    let activity = Activity.surfing

    // MARK: - Weights (sum to 1.0)

    // Swell height is deliberately absent — it is a gate, not a vote. See `score(_:)`.
    private static let swellPeriodWeight = 0.40
    private static let windWeight = 0.40
    private static let comfortWeight = 0.20

    // MARK: - Thresholds

    /// Metres. Below `risesFrom` there is nothing to ride; above `fallsTo` it is the
    /// preserve of experts and often closed out. The band targets a competent recreational
    /// surfer — an explicit assumption, since "good surf" is skill-dependent.
    private static let swellRisesFromMetres = 0.3
    private static let swellIdealFromMetres = 1.0
    private static let swellIdealToMetres = 2.5
    private static let swellFallsToMetres = 4.5

    /// Seconds. Short-period sea is wind slop; long-period groundswell is clean and powerful.
    private static let swellPeriodPoorSeconds = 5.0
    private static let swellPeriodExcellentSeconds = 12.0

    /// Wind is the main spoiler of otherwise good swell.
    private static let windGlassyKph = 10.0
    private static let windBlownOutKph = 40.0

    /// Comfort only — cold does not make waves unsurfable, it makes them unpleasant,
    /// hence the small weight.
    private static let comfortColdCelsius = 2.0
    private static let comfortPleasantCelsius = 16.0

    // MARK: - Reason triggers

    private static let notablyBigSwellMetres = 3.0
    private static let notablySmallSwellMetres = 0.6
    private static let notableWindKph = 30.0
    private static let notableCleanPeriodSeconds = 10.0

    func score(_ day: DailyWeather) -> SuitabilityScore {
        guard let marine = day.marine else {
            return SuitabilityScore(
                activity: activity,
                outcome: .insufficientData,
                reasons: [ScoreReason(
                    factor: .dataAvailability,
                    sentiment: .limiting,
                    detail: "No coastal wave data for this location"
                )]
            )
        }

        // Rideable swell is a precondition, not a trade-off. A flawless 14 s period on a
        // flat ocean is still a flat ocean, and a clean offshore breeze does not make a
        // 4 m closeout safe. Additively weighted, those pleasant conditions dragged a
        // dangerous day back up to "Fair" (53/100) and a flat sea to 12/100.
        let swell = swellSuitability(marine)

        let factors = [
            swellPeriodFactor(marine),
            windFactor(day),
            comfortFactor(day)
        ]

        let value = ScoreComposition.finalise(
            ScoreComposition.weightedSum(factors),
            gate: swell
        )

        // The gate leads when it is what decided the score.
        let reasons = [swellReason(marine, suitability: swell)].compactMap { $0 }
            + ScoreComposition.reasons(from: factors, limit: 2)

        return SuitabilityScore(
            activity: activity,
            outcome: .scored(value),
            reasons: Array(reasons.prefix(3))
        )
    }

    // MARK: - Factors

    // MARK: - Gate

    /// Is there a rideable wave at all? 0 means flat or dangerously oversized.
    private func swellSuitability(_ marine: MarineConditions) -> Double {
        ScoringCurve.band(
            marine.swellWaveHeightMax,
            risesFrom: Self.swellRisesFromMetres,
            idealFrom: Self.swellIdealFromMetres,
            idealTo: Self.swellIdealToMetres,
            fallsTo: Self.swellFallsToMetres
        )
    }

    private func swellReason(_ marine: MarineConditions, suitability: Double) -> ScoreReason? {
        let height = marine.swellWaveHeightMax
        if height >= Self.notablyBigSwellMetres {
            return ScoreReason(
                factor: .swellHeight, sentiment: .limiting,
                detail: "Heavy \(height.reasonValue) m swell — experienced surfers only"
            )
        }
        if height <= Self.notablySmallSwellMetres {
            return ScoreReason(
                factor: .swellHeight, sentiment: .limiting,
                detail: "Nearly flat at \(height.reasonValue) m"
            )
        }
        if suitability >= 0.99 {
            return ScoreReason(
                factor: .swellHeight, sentiment: .favourable,
                detail: "\(height.reasonValue) m swell"
            )
        }
        return nil
    }

    private func swellPeriodFactor(_ marine: MarineConditions) -> WeightedFactor {
        let period = marine.swellWavePeriodMax
        let normalised = ScoringCurve.ascending(
            period,
            zeroAt: Self.swellPeriodPoorSeconds,
            oneAt: Self.swellPeriodExcellentSeconds
        )
        let reason: ScoreReason? = if period >= Self.notableCleanPeriodSeconds {
            ScoreReason(
                factor: .swellPeriod, sentiment: .favourable,
                detail: "Clean \(period.reasonValue) s groundswell"
            )
        } else if period <= Self.swellPeriodPoorSeconds {
            ScoreReason(
                factor: .swellPeriod, sentiment: .unfavourable,
                detail: "Short \(period.reasonValue) s period — disorganised"
            )
        } else {
            nil
        }
        return WeightedFactor(weight: Self.swellPeriodWeight, normalised: normalised, reason: reason)
    }

    private func windFactor(_ day: DailyWeather) -> WeightedFactor {
        let wind = day.windSpeedMaxKilometresPerHour
        let normalised = ScoringCurve.descending(
            wind, oneAt: Self.windGlassyKph, zeroAt: Self.windBlownOutKph
        )
        let reason: ScoreReason? = wind >= Self.notableWindKph
            ? ScoreReason(
                factor: .wind, sentiment: .unfavourable,
                detail: "\(wind.roundedInt) km/h wind — choppy"
              )
            : nil
        return WeightedFactor(weight: Self.windWeight, normalised: normalised, reason: reason)
    }

    private func comfortFactor(_ day: DailyWeather) -> WeightedFactor {
        let normalised = ScoringCurve.ascending(
            day.apparentTemperatureMaxCelsius,
            zeroAt: Self.comfortColdCelsius,
            oneAt: Self.comfortPleasantCelsius
        )
        return WeightedFactor(weight: Self.comfortWeight, normalised: normalised, reason: nil)
    }
}
