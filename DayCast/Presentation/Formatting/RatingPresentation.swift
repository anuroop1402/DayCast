import SwiftUI

/// How a rating band looks and reads.
///
/// **Colour is never the only signal.** Every place a rating colour appears, the label
/// appears with it — colour-blind users and anyone glancing at a greyscale screenshot get
/// the same information. The colours are ordered semantically (green good, red poor) but
/// they decorate the word, they do not replace it.
extension SuitabilityRating {

    nonisolated var displayName: String {
        switch self {
        case .excellent:  "Excellent"
        case .good:       "Good"
        case .fair:       "Fair"
        case .poor:       "Poor"
        case .unsuitable: "Unsuitable"
        case .unknown:    "No data"
        }
    }

    var tint: Color {
        switch self {
        case .excellent:  .green
        case .good:       .mint
        case .fair:       .yellow
        case .poor:       .orange
        case .unsuitable: .red
        // Grey, not red. "We could not tell" must not look like "we checked and it is bad" —
        // the whole point of `insufficientData` being a separate outcome.
        case .unknown:    .secondary
        }
    }
}

extension SuitabilityScore {

    /// What VoiceOver reads for one score. Spelling the activity and the band out in one
    /// phrase avoids a swipe-per-element crawl through a four-column row.
    nonisolated var accessibilityLabel: String {
        "\(activity.displayName): \(rating.displayName)"
    }
}
