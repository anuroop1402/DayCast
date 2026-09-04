import Foundation

/// Why a score came out the way it did.
///
/// Structured rather than a bare `String`: tests assert on `factor` and `sentiment`, which
/// survive copy changes, while the UI renders `detail`. A score without a reason is not
/// useful to a user and not defensible in review, so every rule emits these.
nonisolated struct ScoreReason: Hashable, Sendable, Identifiable {

    /// The measurement responsible. Named per weather variable, not per activity, so the
    /// same factor reads consistently wherever it appears.
    enum Factor: String, Hashable, Sendable, CaseIterable {
        case freshSnow
        case snowBase
        case temperature
        case rain
        case precipitation
        case wind
        case sunshine
        case uv
        case swellHeight
        case swellPeriod
        case travelConditions
        case dataAvailability
    }

    enum Sentiment: Hashable, Sendable {
        /// Pushes the score up.
        case favourable
        /// Pushes the score down.
        case unfavourable
        /// Caps the score regardless of everything else — a gate, not a trade-off.
        case limiting
    }

    let factor: Factor
    let sentiment: Sentiment
    /// Short, user-facing. Includes the measurement so the number is auditable,
    /// e.g. "12 cm fresh snow" rather than "good snow".
    let detail: String

    var id: String { "\(factor.rawValue)|\(detail)" }
}
