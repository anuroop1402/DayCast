import SwiftUI

/// A rating, always as colour **and** word — see the note on `SuitabilityRating.tint`.
struct RatingBadge: View {

    let rating: SuitabilityRating

    var body: some View {
        Text(rating.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(rating.tint.opacity(0.18), in: .capsule)
            .foregroundStyle(rating.tint)
    }
}

/// One activity's result for one day: icon, name, rating.
struct ScoreRow: View {

    let score: SuitabilityScore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: score.activity.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(score.activity.displayName)
            Spacer(minLength: 8)
            RatingBadge(rating: score.rating)
        }
        // One phrase instead of three elements to swipe through.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(score.accessibilityLabel)
    }
}

/// Empty and failure states, so no screen invents its own.
///
/// Retry is offered only when `AppError.isRetryable` says the identical request could
/// plausibly succeed — a button that cannot work is worse than no button.
struct StatePlaceholder: View {

    let error: AppError
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        } actions: {
            if error.isRetryable {
                Button("Try again", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var title: String {
        switch error {
        case .offline:   "No connection"
        case .timedOut:  "Took too long"
        case .noResults: "Nothing found"
        default:         "Something went wrong"
        }
    }

    private var symbol: String {
        switch error {
        case .offline:  "wifi.slash"
        case .timedOut: "clock.badge.exclamationmark"
        default:        "exclamationmark.triangle"
        }
    }

    private var message: String {
        switch error {
        case .offline:
            "DayCast needs a connection to fetch forecasts. Check your network and try again."
        case .timedOut:
            "The forecast service did not respond in time."
        case .server(let statusCode):
            "The forecast service returned an error (\(statusCode))."
        case .decoding:
            "The forecast service sent something DayCast could not read."
        case .noResults:
            "There was nothing to show for this request."
        case .cancelled, .unexpected:
            "Please try again."
        }
    }
}
