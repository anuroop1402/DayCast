import Foundation

/// Open-Meteo geocoding response.
nonisolated struct GeocodingResponseDTO: Decodable, Sendable {

    /// **Optional, and that is the whole point.**
    ///
    /// A search with no matches does not return `"results": []` — it omits the key entirely
    /// and responds with `{"generationtime_ms": 0.8}`. Declaring this non-optional would
    /// throw `keyNotFound` on a perfectly successful request, turning "no cities found"
    /// into an error banner. Verified against `geocoding-no-results.json`.
    let results: [CityDTO]?
}

nonisolated struct CityDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let timezone: String
    /// Absent for some minor entries.
    let country: String?
    /// State / region. Absent for city-states and small territories.
    let admin1: String?
}
