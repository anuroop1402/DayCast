import Foundation

/// Rules about *when* a city search is worth making.
///
/// A free-standing constant rather than a `static` on `SearchCities`, because two layers
/// need it and neither should reach for a concrete use-case type: the use case enforces the
/// floor, and the ViewModel needs to know that a too-short query is an **idle** state rather
/// than "no cities found". Without a shared constant the ViewModel would either duplicate
/// the number or mislabel the state.
nonisolated enum CitySearchPolicy {

    /// A one-character query matches thousands of places and tells the user nothing.
    static let minimumQueryLength = 2

    /// Trimmed, and long enough to be worth asking about.
    static func isSearchable(_ query: String) -> Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).count >= minimumQueryLength
    }
}
