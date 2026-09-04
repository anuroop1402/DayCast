import SwiftUI

/// User-facing copy for the domain's activities.
///
/// Lives here, not on `Activity`, so the domain carries no display strings — the entity
/// says as much. It also means renaming "Outdoor sightseeing" is a presentation change
/// that cannot touch the scoring engine.
extension Activity {

    nonisolated var displayName: String {
        switch self {
        case .skiing:             "Skiing"
        case .surfing:            "Surfing"
        case .outdoorSightseeing: "Outdoor sightseeing"
        case .indoorSightseeing:  "Indoor sightseeing"
        }
    }

    /// Short enough for a compact row where four of these sit side by side.
    nonisolated var shortName: String {
        switch self {
        case .skiing:             "Ski"
        case .surfing:            "Surf"
        case .outdoorSightseeing: "Outdoor"
        case .indoorSightseeing:  "Indoor"
        }
    }

    nonisolated var symbolName: String {
        switch self {
        case .skiing:             "figure.skiing.downhill"
        case .surfing:            "figure.surfing"
        case .outdoorSightseeing: "binoculars.fill"
        case .indoorSightseeing:  "building.columns.fill"
        }
    }

    /// The honest caveat, shown in the UI rather than buried in the README.
    ///
    /// Both scores are computed from weather alone: nothing in the Open-Meteo response says
    /// whether there is a mountain or a rideable beach at these coordinates. A perfect ski
    /// score for a flat, snowy city is the model working as designed and reporting
    /// something useless, so the user is told where the number stops being meaningful.
    nonisolated var limitation: String? {
        switch self {
        case .skiing:
            "Scored from weather only — DayCast does not know whether there is a ski area nearby."
        case .surfing:
            "Scored from weather and sea state only — DayCast does not know whether there is a surfable beach nearby."
        case .outdoorSightseeing, .indoorSightseeing:
            nil
        }
    }
}
