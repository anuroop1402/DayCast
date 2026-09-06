import Foundation

/// A geocoded place, as returned by Open-Meteo's Geocoding API.
///
/// `Codable` here is a deliberate trade-off. Recent searches persist to `UserDefaults`, and
/// a separate 1:1 persistence DTO would add a file and a mapper for no behavioural benefit.
/// `Codable` is `Foundation`, so the domain stays framework-free. The cost is that changing
/// this shape invalidates stored data — acceptable, because the worst case is a capped
/// recent-searches list resetting, which the app already handles as an empty state.
nonisolated struct City: Identifiable, Hashable, Sendable, Codable {
    /// Open-Meteo's geocoding identifier.
    let id: Int
    let name: String
    let country: String
    /// State / region. Disambiguates the many same-named cities Open-Meteo returns.
    let admin1: String?
    let latitude: Double
    let longitude: Double
    let timezone: String
}

nonisolated extension City {

    /// The city's own timezone, for deciding which of its days is "today".
    ///
    /// Falls back to UTC rather than `.current` so that an unrecognised identifier degrades
    /// to the frame every forecast date is already anchored in, instead of silently
    /// reintroducing the device's calendar — the exact coupling this type exists to avoid.
    var localTimeZone: TimeZone {
        TimeZone(identifier: timezone) ?? ForecastDate.displayTimeZone
    }
}
