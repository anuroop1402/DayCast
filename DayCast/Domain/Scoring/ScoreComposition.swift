import Foundation

/// One normalised input to a score, with the weight it carries.
nonisolated struct WeightedFactor: Sendable {
    /// Share of the activity's score. Weights within a rule must sum to 1.
    let weight: Double
    /// 0...1, produced by a `ScoringCurve`.
    let normalised: Double
    /// Emitted only when the factor is notable enough to be worth telling the user about.
    let reason: ScoreReason?

    init(weight: Double, normalised: Double, reason: ScoreReason? = nil) {
        self.weight = weight
        self.normalised = normalised
        self.reason = reason
    }
}

/// Combines weighted factors into a 0...100 score.
///
/// Two combination modes, and the distinction is deliberate:
///
/// - **Additive factors compensate.** Strong swell can offset mediocre wind, because a
///   surfer trades those off in real life.
/// - **A gate does not.** Nothing compensates for being unable to travel, or for data that
///   does not exist. A gate multiplies the whole score, so it can drive it to zero
///   regardless of how favourable everything else is.
///
/// Modelling both as a weighted sum would let a blizzard's "nothing else to do" appeal
/// cancel out the fact that you cannot get to the museum.
nonisolated enum ScoreComposition {

    static func weightedSum(_ factors: [WeightedFactor]) -> Double {
        assert(
            abs(factors.reduce(0) { $0 + $1.weight } - 1) < 0.0001,
            "Factor weights must sum to 1.0, got \(factors.reduce(0) { $0 + $1.weight })"
        )
        return factors.reduce(0) { $0 + $1.weight * ScoringCurve.clamped($1.normalised) }
    }

    /// Applies the gate and converts to the 0...100 integer scale.
    static func finalise(_ normalised: Double, gate: Double = 1) -> Int {
        let combined = ScoringCurve.clamped(normalised) * ScoringCurve.clamped(gate)
        return Int((combined * 100).rounded())
    }

    static func compose(_ factors: [WeightedFactor], gate: Double = 1) -> Int {
        finalise(weightedSum(factors), gate: gate)
    }

    /// Reasons worth surfacing, most impactful first.
    ///
    /// Impact is `weight × distance from neutral`, so a heavily-weighted factor at an
    /// extreme outranks a lightly-weighted one. Capped because a list of six caveats is
    /// noise, not explanation.
    static func reasons(from factors: [WeightedFactor], limit: Int = 3) -> [ScoreReason] {
        factors
            .filter { $0.reason != nil }
            .sorted { lhs, rhs in
                lhs.weight * abs(lhs.normalised - 0.5) > rhs.weight * abs(rhs.normalised - 0.5)
            }
            .prefix(limit)
            .compactMap(\.reason)
    }
}
