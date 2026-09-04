import Foundation

/// The finished product: a city, and every day scored for every activity.
nonisolated struct ActivityForecast: Hashable, Sendable {
    let city: City
    /// Chronological, typically 7 entries.
    let days: [DayForecast]

    /// Highest-scoring day for an activity. Days with insufficient data are ignored rather
    /// than ranked last, so an inland city returns `nil` for surfing instead of nominating
    /// an arbitrary day.
    func bestDay(for activity: Activity) -> DayForecast? {
        days
            .compactMap { day -> (DayForecast, Int)? in
                guard let value = day.score(for: activity)?.value else { return nil }
                return (day, value)
            }
            .max { $0.1 < $1.1 }?
            .0
    }
}

/// One forecast day, with its scores.
nonisolated struct DayForecast: Hashable, Sendable, Identifiable {
    let date: Date
    let weather: DailyWeather
    /// One entry per `Activity`, in `Activity.allCases` order.
    let scores: [SuitabilityScore]

    var id: Date { date }

    func score(for activity: Activity) -> SuitabilityScore? {
        scores.first { $0.activity == activity }
    }

    /// Activities ranked best-first for this day.
    var rankedScores: [SuitabilityScore] {
        scores.sorted { ($0.value ?? -1) > ($1.value ?? -1) }
    }
}
