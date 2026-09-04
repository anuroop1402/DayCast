import Foundation

/// Open-Meteo's error body, returned with a 4xx:
/// `{"error": true, "reason": "Latitude must be in range of -90 to 90°. Given: 999.0."}`
///
/// Captured in `error-invalid-latitude.json`. Decoded only for logging — the `reason` is
/// developer-facing and is never shown to a user.
nonisolated struct OpenMeteoErrorDTO: Decodable, Sendable {
    let error: Bool
    let reason: String
}
