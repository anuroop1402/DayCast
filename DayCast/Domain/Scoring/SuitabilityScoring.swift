import Foundation

/// The scoring engine: applies every rule to every day.
///
/// Pure and `nonisolated` — no I/O, no clock, no shared state — so it is testable without
/// mocks and free to run off the main actor if it ever becomes expensive.
///
/// Rules are injected rather than hard-coded so tests can drive the engine with a single
/// stub rule and assert on composition behaviour independently of any real thresholds.
nonisolated struct SuitabilityScoring: Sendable {

    private let rules: [any SuitabilityRule]

    init(rules: [any SuitabilityRule] = SuitabilityScoring.defaultRules) {
        assert(
            Set(rules.map(\.activity)).count == rules.count,
            "Duplicate rules for the same activity"
        )
        self.rules = rules
    }

    /// One rule per `Activity`. The order matches `Activity.allCases` so the UI can rely on
    /// a stable ordering without sorting.
    static var defaultRules: [any SuitabilityRule] {
        [
            SkiingRule(),
            SurfingRule(),
            OutdoorSightseeingRule(),
            IndoorSightseeingRule()
        ]
    }

    func scores(for day: DailyWeather) -> [SuitabilityScore] {
        rules.map { $0.score(day) }
    }

    /// Scores an entire forecast window.
    func forecast(for city: City, days: [DailyWeather]) -> ActivityForecast {
        ActivityForecast(
            city: city,
            days: days.map { day in
                DayForecast(date: day.date, weather: day, scores: scores(for: day))
            }
        )
    }
}
