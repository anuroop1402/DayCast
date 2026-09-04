import Foundation

/// Everything that can go wrong, expressed in domain terms.
///
/// The data layer maps `URLError`, HTTP status codes and `DecodingError` onto these, so the
/// presentation layer never sees a transport type. That is what lets a ViewModel decide
/// *"offer retry"* vs *"tell them to try a different search"* without importing `URLSession`.
nonisolated enum AppError: Error, Equatable, Sendable {
    /// No usable network connection.
    case offline
    /// The request took too long.
    case timedOut
    /// Reached the server, got a failure status.
    case server(statusCode: Int)
    /// Reached the server, could not understand the response. Almost always our bug.
    case decoding
    /// Request succeeded and returned nothing — not an error, but a state the UI must handle.
    case noResults
    /// Superseded by a newer request, or the view went away. Must never be shown to a user.
    case cancelled
    case unexpected

    /// Whether retrying the identical request could plausibly succeed.
    /// Drives whether the error state offers a retry button.
    var isRetryable: Bool {
        switch self {
        case .offline, .timedOut, .server, .unexpected: true
        case .decoding, .noResults, .cancelled: false
        }
    }
}
