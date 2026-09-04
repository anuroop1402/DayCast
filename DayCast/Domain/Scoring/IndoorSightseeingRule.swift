import Foundation

/// Indoor sightseeing suitability — museums, galleries, historic interiors.
///
/// **This is the biggest judgement call in the project.** Museums are open whatever the
/// weather, so a naive model scores every day ~90 and tells the user nothing. The question
/// worth answering is not "is the museum open" but *"is today a day to spend indoors?"*
///
/// So the score is modelled as **relative attractiveness**, in two parts:
///
/// 1. **Appeal** rises as outdoor conditions worsen. Grim weather makes a gallery the
///    obvious choice.
/// 2. **Travel feasibility** is a *gate*, not another factor. A blizzard maximises appeal
///    while making the trip miserable or impossible, and no amount of "nothing else to do"
///    compensates for that. Modelled additively, those two would cancel out and a blizzard
///    would score the same as steady drizzle — which is wrong. Multiplying means the gate
///    can veto.
///
/// A floor keeps a sunny day from being labelled *unsuitable*: you can always visit a
/// museum in good weather, you would just rather be outside. "Poor" conveys that; "unsuitable"
/// would be a false statement about the world.
///
/// Consequence, and it is intended: **drizzle outscores a blizzard, and a blizzard outscores
/// nothing at all.** Verified by test.
nonisolated struct IndoorSightseeingRule: SuitabilityRule {

    let activity = Activity.indoorSightseeing

    // MARK: - Appeal weights (sum to 1.0)

    private static let precipitationWeight = 0.50
    private static let temperatureWeight = 0.30
    private static let windWeight = 0.20

    // MARK: - Thresholds

    /// Indoor sightseeing is never *unsuitable* on weather grounds alone — only less
    /// attractive. This floor encodes that.
    private static let baselineAppeal = 0.25

    /// Rain that makes being outdoors unpleasant enough to drive people inside.
    private static let precipitationDrivesIndoorsMillimetres = 6.0

    /// Same comfort band as outdoor sightseeing — deliberately, so the two rules are
    /// consistent about what "pleasant" means.
    private static let comfortRisesFromCelsius = 0.0
    private static let comfortIdealFromCelsius = 14.0
    private static let comfortIdealToCelsius = 26.0
    private static let comfortFallsToCelsius = 36.0

    private static let windPleasantKph = 10.0
    private static let windDrivesIndoorsKph = 45.0

    // MARK: - Travel feasibility gate

    /// Beyond these, getting across town stops being a normal errand.
    private static let travelEasyPrecipitationMillimetres = 12.0
    private static let travelImpossiblePrecipitationMillimetres = 45.0
    private static let travelEasySnowfallCentimetres = 3.0
    private static let travelImpossibleSnowfallCentimetres = 30.0
    private static let travelEasyGustsKph = 45.0
    private static let travelImpossibleGustsKph = 95.0

    /// Below this the gate is worth explaining to the user.
    private static let travelWorthMentioning = 0.75

    func score(_ day: DailyWeather) -> SuitabilityScore {
        let discomfort = [
            precipitationDiscomfort(day),
            temperatureDiscomfort(day),
            windDiscomfort(day)
        ]

        // Appeal never falls below the floor, however pleasant it is outside.
        let appeal = Self.baselineAppeal
            + (1 - Self.baselineAppeal) * ScoreComposition.weightedSum(discomfort)

        let travel = travelFeasibility(day)

        var reasons = ScoreComposition.reasons(from: discomfort, limit: 2)
        if let gateReason = travelReason(day, feasibility: travel) {
            // A gate outranks any trade-off, so it leads.
            reasons.insert(gateReason, at: 0)
        }

        return SuitabilityScore(
            activity: activity,
            outcome: .scored(ScoreComposition.finalise(appeal, gate: travel)),
            reasons: Array(reasons.prefix(3))
        )
    }

    // MARK: - Appeal factors (higher = worse outside = better indoors)

    private func precipitationDiscomfort(_ day: DailyWeather) -> WeightedFactor {
        let normalised = ScoringCurve.ascending(
            day.precipitationSumMillimetres,
            zeroAt: 0,
            oneAt: Self.precipitationDrivesIndoorsMillimetres
        )
        let reason: ScoreReason? = if normalised >= 0.6 {
            ScoreReason(
                factor: .precipitation, sentiment: .favourable,
                detail: "Wet outside — a good day for indoor sights"
            )
        } else if normalised <= 0.05 {
            ScoreReason(
                factor: .precipitation, sentiment: .unfavourable,
                detail: "Dry outside — you may prefer outdoor sights"
            )
        } else {
            nil
        }
        return WeightedFactor(weight: Self.precipitationWeight, normalised: normalised, reason: reason)
    }

    private func temperatureDiscomfort(_ day: DailyWeather) -> WeightedFactor {
        let comfort = ScoringCurve.band(
            day.apparentTemperatureMaxCelsius,
            risesFrom: Self.comfortRisesFromCelsius,
            idealFrom: Self.comfortIdealFromCelsius,
            idealTo: Self.comfortIdealToCelsius,
            fallsTo: Self.comfortFallsToCelsius
        )
        let discomfort = 1 - comfort
        let reason: ScoreReason? = discomfort >= 0.7
            ? ScoreReason(
                factor: .temperature, sentiment: .favourable,
                detail: "Feels like \(day.apparentTemperatureMaxCelsius.reasonValue) °C — better indoors"
              )
            : nil
        return WeightedFactor(weight: Self.temperatureWeight, normalised: discomfort, reason: reason)
    }

    private func windDiscomfort(_ day: DailyWeather) -> WeightedFactor {
        let normalised = ScoringCurve.ascending(
            day.windSpeedMaxKilometresPerHour,
            zeroAt: Self.windPleasantKph,
            oneAt: Self.windDrivesIndoorsKph
        )
        return WeightedFactor(weight: Self.windWeight, normalised: normalised, reason: nil)
    }

    // MARK: - Gate

    /// Worst of the three travel hazards — they do not average out. Deep snow makes the
    /// journey hard regardless of how little it is raining.
    private func travelFeasibility(_ day: DailyWeather) -> Double {
        let byRain = ScoringCurve.descending(
            day.precipitationSumMillimetres,
            oneAt: Self.travelEasyPrecipitationMillimetres,
            zeroAt: Self.travelImpossiblePrecipitationMillimetres
        )
        let bySnow = ScoringCurve.descending(
            day.snowfallSumCentimetres,
            oneAt: Self.travelEasySnowfallCentimetres,
            zeroAt: Self.travelImpossibleSnowfallCentimetres
        )
        let byWind = ScoringCurve.descending(
            day.windGustsMaxKilometresPerHour,
            oneAt: Self.travelEasyGustsKph,
            zeroAt: Self.travelImpossibleGustsKph
        )
        return min(byRain, bySnow, byWind)
    }

    private func travelReason(_ day: DailyWeather, feasibility: Double) -> ScoreReason? {
        guard feasibility < Self.travelWorthMentioning else { return nil }
        let detail = if day.snowfallSumCentimetres > Self.travelEasySnowfallCentimetres {
            "Heavy snow (\(day.snowfallSumCentimetres.roundedInt) cm) makes travel difficult"
        } else if day.windGustsMaxKilometresPerHour > Self.travelEasyGustsKph {
            "Gusts to \(day.windGustsMaxKilometresPerHour.roundedInt) km/h make travel difficult"
        } else {
            "Heavy rain (\(day.precipitationSumMillimetres.roundedInt) mm) makes travel difficult"
        }
        return ScoreReason(factor: .travelConditions, sentiment: .limiting, detail: detail)
    }
}
