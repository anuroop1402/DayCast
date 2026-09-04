import Testing
import Foundation
@testable import DayCast

/// The curves are the only maths in the domain, and every threshold in every rule is
/// expressed through them. Boundary behaviour is tested here once so the rule tests can be
/// about product decisions rather than arithmetic.
struct ScoringCurveTests {

    // MARK: - ascending

    @Test("ascending: clamps at both ends and is linear between")
    func ascendingShape() {
        #expect(ScoringCurve.ascending(-5, zeroAt: 0, oneAt: 10) == 0)
        #expect(ScoringCurve.ascending(0, zeroAt: 0, oneAt: 10) == 0)
        #expect(ScoringCurve.ascending(5, zeroAt: 0, oneAt: 10) == 0.5)
        #expect(ScoringCurve.ascending(10, zeroAt: 0, oneAt: 10) == 1)
        #expect(ScoringCurve.ascending(99, zeroAt: 0, oneAt: 10) == 1)
    }

    @Test("ascending: works across negative ranges")
    func ascendingNegatives() {
        #expect(ScoringCurve.ascending(-15, zeroAt: -20, oneAt: -10) == 0.5)
    }

    // MARK: - descending

    @Test("descending: mirrors ascending")
    func descendingShape() {
        #expect(ScoringCurve.descending(-5, oneAt: 0, zeroAt: 10) == 1)
        #expect(ScoringCurve.descending(0, oneAt: 0, zeroAt: 10) == 1)
        #expect(ScoringCurve.descending(5, oneAt: 0, zeroAt: 10) == 0.5)
        #expect(ScoringCurve.descending(10, oneAt: 0, zeroAt: 10) == 0)
        #expect(ScoringCurve.descending(99, oneAt: 0, zeroAt: 10) == 0)
    }

    // MARK: - band

    @Test("band: zero outside, one across the plateau")
    func bandShape() {
        func value(_ x: Double) -> Double {
            ScoringCurve.band(x, risesFrom: 0, idealFrom: 10, idealTo: 20, fallsTo: 30)
        }
        #expect(value(-1) == 0)
        #expect(value(0) == 0)
        #expect(value(5) == 0.5)
        #expect(value(10) == 1)
        #expect(value(15) == 1)      // plateau
        #expect(value(20) == 1)
        #expect(value(25) == 0.5)
        #expect(value(30) == 0)
        #expect(value(99) == 0)
    }

    @Test("band: is continuous at the plateau edges")
    func bandIsContinuous() {
        func value(_ x: Double) -> Double {
            ScoringCurve.band(x, risesFrom: 0, idealFrom: 10, idealTo: 20, fallsTo: 30)
        }
        #expect(abs(value(9.999) - 1) < 0.001)
        #expect(abs(value(20.001) - 1) < 0.001)
    }

    // MARK: - degenerate inputs

    @Test("degenerate ranges become a step rather than dividing by zero")
    func degenerateRanges() {
        #expect(ScoringCurve.ascending(5, zeroAt: 5, oneAt: 5) == 1)
        #expect(ScoringCurve.ascending(4, zeroAt: 5, oneAt: 5) == 0)
        #expect(ScoringCurve.descending(5, oneAt: 5, zeroAt: 5) == 1)
        #expect(ScoringCurve.descending(6, oneAt: 5, zeroAt: 5) == 0)
    }

    @Test("output is always within 0...1", arguments: [-1000.0, -1.0, 0.0, 3.3, 50.0, 1e6])
    func outputAlwaysNormalised(x: Double) {
        #expect((0...1).contains(ScoringCurve.ascending(x, zeroAt: 0, oneAt: 10)))
        #expect((0...1).contains(ScoringCurve.descending(x, oneAt: 0, zeroAt: 10)))
        #expect((0...1).contains(
            ScoringCurve.band(x, risesFrom: 0, idealFrom: 10, idealTo: 20, fallsTo: 30)
        ))
    }
}

/// Composition is where the "additive vs gate" distinction lives — the idea that fixed
/// three separate scoring bugs. It is tested independently of any real thresholds.
struct ScoreCompositionTests {

    @Test("weighted sum combines factors proportionally")
    func weightedSum() {
        let sum = ScoreComposition.weightedSum([
            WeightedFactor(weight: 0.5, normalised: 1.0),
            WeightedFactor(weight: 0.5, normalised: 0.0)
        ])
        #expect(sum == 0.5)
    }

    @Test("a gate of zero vetoes an otherwise perfect score")
    func gateVetoes() {
        let factors = [WeightedFactor(weight: 1.0, normalised: 1.0)]
        #expect(ScoreComposition.compose(factors, gate: 1) == 100)
        #expect(ScoreComposition.compose(factors, gate: 0) == 0)
        #expect(ScoreComposition.compose(factors, gate: 0.5) == 50)
    }

    @Test("a gate cannot be out-voted, however favourable the factors")
    func gateCannotBeOutvoted() {
        let perfect = [
            WeightedFactor(weight: 0.4, normalised: 1.0),
            WeightedFactor(weight: 0.4, normalised: 1.0),
            WeightedFactor(weight: 0.2, normalised: 1.0)
        ]
        #expect(ScoreComposition.compose(perfect, gate: 0.1) == 10)
    }

    @Test("factor inputs outside 0...1 are clamped, not trusted")
    func factorsAreClamped() {
        #expect(ScoreComposition.compose([WeightedFactor(weight: 1, normalised: 5)]) == 100)
        #expect(ScoreComposition.compose([WeightedFactor(weight: 1, normalised: -5)]) == 0)
    }

    @Test("reasons are ordered by impact and capped")
    func reasonsRankedByImpact() {
        let minor = ScoreReason(factor: .uv, sentiment: .unfavourable, detail: "minor")
        let major = ScoreReason(factor: .rain, sentiment: .unfavourable, detail: "major")

        let reasons = ScoreComposition.reasons(from: [
            WeightedFactor(weight: 0.1, normalised: 0.0, reason: minor),
            WeightedFactor(weight: 0.9, normalised: 0.0, reason: major)
        ])
        #expect(reasons.first == major)
    }

    @Test("factors without a reason contribute nothing to the explanation")
    func silentFactorsAreOmitted() {
        let reasons = ScoreComposition.reasons(from: [
            WeightedFactor(weight: 0.5, normalised: 0.0),
            WeightedFactor(weight: 0.5, normalised: 1.0)
        ])
        #expect(reasons.isEmpty)
    }

    @Test("the explanation is capped so it stays readable")
    func reasonsAreCapped() {
        let factors = (0..<6).map { index in
            WeightedFactor(
                weight: 1.0 / 6,
                normalised: 0,
                reason: ScoreReason(factor: .wind, sentiment: .unfavourable, detail: "\(index)")
            )
        }
        #expect(ScoreComposition.reasons(from: factors).count == 3)
    }
}
