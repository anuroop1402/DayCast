import Foundation

/// The four activities the app ranks.
///
/// Adding a fifth activity means adding a case here and one `SuitabilityRule`
/// implementation — the scoring engine and the UI iterate over `allCases` and need no
/// changes. Display names deliberately live in the presentation layer, not here, so the
/// domain stays free of user-facing copy.
nonisolated enum Activity: String, CaseIterable, Identifiable, Hashable, Sendable {
    case skiing
    case surfing
    case outdoorSightseeing
    case indoorSightseeing

    var id: String { rawValue }

    /// Activities that cannot be scored from land-only forecast data.
    var requiresMarineData: Bool { self == .surfing }
}
