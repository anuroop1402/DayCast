import Foundation

/// Skiing suitability.
///
/// **Assumption:** this scores *weather at the city's coordinates*, not terrain. Open-Meteo
/// exposes no resort, altitude or snow-base data, so a lowland city with freak snowfall will
/// score. The UI states this limitation rather than hiding it.
///
/// **Two gates, and they exist because of a bug this model originally had.**
///
/// The first version composed snow, rain, temperature and wind additively. That let a 24 °C
/// sunny day score 40/100 for skiing — it collected 25% for "not raining" and 15% for "not
/// windy" while having no snow whatsoever. It also scored a blizzard 85/100, because 90 km/h
/// gusts were only 15% of the total and could not express "every lift is shut".
///
/// The flaw was general: **additive factors let the absence of negatives substitute for the
/// presence of a prerequisite.** Snow is not something you trade off against wind — without
/// it there is no skiing at any temperature. Same for lift-closing gusts.
///
/// So both are gates. Additive factors (temperature, rain, wind comfort) describe *how good*
/// a ski day is; the gates decide whether there is a ski day at all.
///
/// **Rain is still penalised harder than warmth.** A dry 8 °C day merely fails to improve
/// conditions; 5 mm of rain actively destroys the base and leaves ice.
nonisolated struct SkiingRule: SuitabilityRule {

    let activity = Activity.skiing

    // MARK: - Weights for the additive factors (sum to 1.0)

    private static let temperatureWeight = 0.40
    private static let rainWeight = 0.35
    private static let windComfortWeight = 0.25

    // MARK: - Snow availability gate

    /// Fresh snow giving full availability. A 15 cm dump is a genuinely good powder day.
    private static let excellentFreshSnowCm = 15.0
    /// At or below this, a day with no new snow can still ski on an existing base.
    private static let baseHoldsAtOrBelowCelsius = -2.0
    /// Above this, any base is slush.
    private static let baseLostAtCelsius = 4.0
    /// Cap on credit for an unobserved base — we can see air temperature, not snow depth.
    private static let maxCreditForExistingBase = 0.5

    // MARK: - Lift operability gate
    //
    // Deliberately does not overlap the wind *comfort* factor below: this gate is flat at
    // 1.0 across that factor's entire active range, so wind is never counted twice. Below
    // 60 km/h wind is merely unpleasant; above it, lifts start closing.

    private static let liftsRunAtOrBelowGustsKph = 60.0
    private static let liftsClosedAtGustsKph = 90.0

    // MARK: - Additive thresholds

    /// Rain destroys snow quality fast; 5 mm writes the day off.
    private static let rainRuinsDayMillimetres = 5.0

    private static let temperatureRisesFromCelsius = -25.0
    private static let temperatureIdealFromCelsius = -12.0
    private static let temperatureIdealToCelsius = -1.0
    private static let temperatureFallsToCelsius = 6.0

    private static let windComfortableGustsKph = 20.0
    private static let windUnpleasantGustsKph = 60.0

    // MARK: - Reason triggers

    private static let notableSnowfallCm = 5.0
    /// Below this, "fresh snow" is a rounding artefact rather than something a skier would
    /// notice underfoot, so the reason says there is none.
    private static let reportableSnowfallCm = 0.5
    private static let notableRainMillimetres = 2.0
    private static let gateWorthMentioning = 0.75

    func score(_ day: DailyWeather) -> SuitabilityScore {
        let snow = snowAvailability(day)
        let lifts = liftOperability(day)

        let factors = [temperatureFactor(day), rainFactor(day), windComfortFactor(day)]
        let value = ScoreComposition.finalise(
            ScoreComposition.weightedSum(factors),
            gate: snow * lifts
        )

        // Gates lead, and a veto outranks anything favourable. A blizzard has 28 cm of
        // fresh snow *and* closed lifts; leading with the snow would explain a score of 0
        // with a reason that sounds like good news.
        let gateReasons = [
            snowReason(day, availability: snow),
            liftReason(day, operability: lifts)
        ].compactMap { $0 }

        let reasons = gateReasons.filter { $0.sentiment == .limiting }
            + gateReasons.filter { $0.sentiment != .limiting }
            + ScoreComposition.reasons(from: factors, limit: 2)

        return SuitabilityScore(
            activity: activity,
            outcome: .scored(value),
            reasons: Array(reasons.prefix(3))
        )
    }

    // MARK: - Gates

    /// Best of "fresh snow fell" and "it is cold enough that a base survives".
    private func snowAvailability(_ day: DailyWeather) -> Double {
        let fresh = ScoringCurve.ascending(
            day.snowfallSumCentimetres, zeroAt: 0, oneAt: Self.excellentFreshSnowCm
        )
        let base = ScoringCurve.descending(
            day.temperatureMaxCelsius,
            oneAt: Self.baseHoldsAtOrBelowCelsius,
            zeroAt: Self.baseLostAtCelsius
        ) * Self.maxCreditForExistingBase
        return max(fresh, base)
    }

    private func liftOperability(_ day: DailyWeather) -> Double {
        ScoringCurve.descending(
            day.windGustsMaxKilometresPerHour,
            oneAt: Self.liftsRunAtOrBelowGustsKph,
            zeroAt: Self.liftsClosedAtGustsKph
        )
    }

    // MARK: - Gate reasons

    private func snowReason(_ day: DailyWeather, availability: Double) -> ScoreReason? {
        if availability <= 0.01 {
            return ScoreReason(
                factor: .snowBase, sentiment: .limiting,
                detail: "No snow — \(day.temperatureMaxCelsius.reasonValue) °C and none forecast"
            )
        }
        if day.snowfallSumCentimetres >= Self.notableSnowfallCm {
            return ScoreReason(
                factor: .freshSnow, sentiment: .favourable,
                detail: "\(day.snowfallSumCentimetres.roundedInt) cm fresh snow"
            )
        }
        if availability < Self.gateWorthMentioning {
            // There may well *be* fresh snow here — just not enough to lift the gate. Saying
            // "no fresh snow" beneath a conditions panel reading "Snowfall 4.4 cm" makes the
            // screen argue with itself, which costs the user more trust than the score gains.
            if day.snowfallSumCentimetres >= Self.reportableSnowfallCm {
                return ScoreReason(
                    factor: .freshSnow, sentiment: .limiting,
                    detail: "Only \(day.snowfallSumCentimetres.reasonValue) cm fresh snow"
                )
            }
            return ScoreReason(
                factor: .snowBase, sentiment: .limiting,
                detail: "Thin cover — no fresh snow"
            )
        }
        return nil
    }

    private func liftReason(_ day: DailyWeather, operability: Double) -> ScoreReason? {
        guard operability < 1 else { return nil }
        return ScoreReason(
            factor: .wind, sentiment: .limiting,
            detail: "Gusts to \(day.windGustsMaxKilometresPerHour.roundedInt) km/h — lifts likely closed"
        )
    }

    // MARK: - Additive factors

    private func temperatureFactor(_ day: DailyWeather) -> WeightedFactor {
        let normalised = ScoringCurve.band(
            day.temperatureMaxCelsius,
            risesFrom: Self.temperatureRisesFromCelsius,
            idealFrom: Self.temperatureIdealFromCelsius,
            idealTo: Self.temperatureIdealToCelsius,
            fallsTo: Self.temperatureFallsToCelsius
        )
        let reason: ScoreReason? = if day.temperatureMaxCelsius > Self.temperatureIdealToCelsius {
            ScoreReason(
                factor: .temperature, sentiment: .unfavourable,
                detail: "Above freezing at \(day.temperatureMaxCelsius.reasonValue) °C"
            )
        } else if day.temperatureMaxCelsius < Self.temperatureIdealFromCelsius {
            ScoreReason(
                factor: .temperature, sentiment: .unfavourable,
                detail: "Bitterly cold at \(day.temperatureMaxCelsius.reasonValue) °C"
            )
        } else {
            nil
        }
        return WeightedFactor(weight: Self.temperatureWeight, normalised: normalised, reason: reason)
    }

    private func rainFactor(_ day: DailyWeather) -> WeightedFactor {
        let normalised = ScoringCurve.descending(
            day.rainSumMillimetres, oneAt: 0, zeroAt: Self.rainRuinsDayMillimetres
        )
        let reason: ScoreReason? = day.rainSumMillimetres >= Self.notableRainMillimetres
            ? ScoreReason(
                factor: .rain, sentiment: .unfavourable,
                detail: "\(day.rainSumMillimetres.reasonValue) mm rain on snow"
              )
            : nil
        return WeightedFactor(weight: Self.rainWeight, normalised: normalised, reason: reason)
    }

    /// Wind you can still ski in, but would rather not. Operability is handled by the gate.
    private func windComfortFactor(_ day: DailyWeather) -> WeightedFactor {
        let normalised = ScoringCurve.descending(
            day.windGustsMaxKilometresPerHour,
            oneAt: Self.windComfortableGustsKph,
            zeroAt: Self.windUnpleasantGustsKph
        )
        return WeightedFactor(weight: Self.windComfortWeight, normalised: normalised, reason: nil)
    }
}
