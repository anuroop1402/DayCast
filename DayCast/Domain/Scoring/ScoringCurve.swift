import Foundation

/// Piecewise-linear normalisation.
///
/// Every factor in the engine maps a raw measurement onto 0...1 through one of these three
/// shapes. Keeping the shapes named and few means a reviewer can argue with a *threshold*
/// without having to reverse-engineer a bespoke formula per activity.
nonisolated enum ScoringCurve {

    /// 0 at or below `zeroAt`, 1 at or above `oneAt`, linear between.
    /// Use for "more is better": fresh snow, swell period, sunshine.
    static func ascending(_ x: Double, zeroAt: Double, oneAt: Double) -> Double {
        guard oneAt != zeroAt else { return x >= oneAt ? 1 : 0 }
        return clamped((x - zeroAt) / (oneAt - zeroAt))
    }

    /// 1 at or below `oneAt`, 0 at or above `zeroAt`, linear between.
    /// Use for "less is better": rain, wind, UV.
    static func descending(_ x: Double, oneAt: Double, zeroAt: Double) -> Double {
        guard zeroAt != oneAt else { return x <= oneAt ? 1 : 0 }
        return clamped(1 - (x - oneAt) / (zeroAt - oneAt))
    }

    /// A comfort band: 0 below `risesFrom`, 1 across `idealFrom...idealTo`, 0 again at
    /// `fallsTo`. Use where both extremes are bad — temperature, swell height.
    static func band(
        _ x: Double,
        risesFrom: Double,
        idealFrom: Double,
        idealTo: Double,
        fallsTo: Double
    ) -> Double {
        if x < idealFrom { return ascending(x, zeroAt: risesFrom, oneAt: idealFrom) }
        if x > idealTo { return descending(x, oneAt: idealTo, zeroAt: fallsTo) }
        return 1
    }

    static func clamped(_ value: Double) -> Double { min(1, max(0, value)) }
}
