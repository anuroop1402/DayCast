import Foundation

/// How suitable one day is for one activity.
///
/// `rating` is *derived* from `outcome` rather than stored, so the two can never disagree —
/// there is no way to construct a score of 12 labelled "excellent".
nonisolated struct SuitabilityScore: Hashable, Sendable, Identifiable {

    /// Modelled as a sum type so "no score" is a real state rather than a sentinel value.
    /// A `-1` or a `nil` alongside a rating would let callers forget to handle it.
    enum Outcome: Hashable, Sendable {
        /// 0...100.
        case scored(Int)
        /// The inputs this activity needs were not available — currently only surfing,
        /// when a location has no marine data. Distinct from "scored 0", which would
        /// wrongly imply we looked and the conditions were terrible.
        case insufficientData
    }

    let activity: Activity
    let outcome: Outcome
    /// Ordered most significant first, capped by the rule that produced them.
    let reasons: [ScoreReason]

    var id: Activity { activity }

    var value: Int? {
        if case .scored(let value) = outcome { return value }
        return nil
    }

    var rating: SuitabilityRating { SuitabilityRating(outcome: outcome) }
}

/// Coarse bands over the 0...100 score.
///
/// The app shows bands, not raw numbers. A model built on documented assumptions does not
/// justify presenting "73% suitable" — that is false precision. Bands communicate the
/// confidence the model actually has.
nonisolated enum SuitabilityRating: String, Hashable, Sendable, CaseIterable {
    case excellent
    case good
    case fair
    case poor
    case unsuitable
    /// Corresponds to `Outcome.insufficientData`.
    case unknown

    init(outcome: SuitabilityScore.Outcome) {
        guard case .scored(let value) = outcome else {
            self = .unknown
            return
        }
        switch value {
        case Self.excellentThreshold...:                          self = .excellent
        case Self.goodThreshold..<Self.excellentThreshold:        self = .good
        case Self.fairThreshold..<Self.goodThreshold:             self = .fair
        case Self.poorThreshold..<Self.fairThreshold:             self = .poor
        default:                                                  self = .unsuitable
        }
    }

    static let excellentThreshold = 80
    static let goodThreshold = 60
    static let fairThreshold = 40
    static let poorThreshold = 20

    /// Ordering for "is this day better than that one", `unknown` lowest.
    var sortRank: Int {
        switch self {
        case .excellent:   return 5
        case .good:        return 4
        case .fair:        return 3
        case .poor:        return 2
        case .unsuitable:  return 1
        case .unknown:     return 0
        }
    }
}
