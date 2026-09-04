import Foundation

/// Scores one activity for one day.
///
/// One implementation per activity, rather than a `switch` inside a single scorer: adding
/// an activity is then a new file, not an edit to shared code, and each rule's thresholds
/// can be reviewed and tested in isolation.
protocol SuitabilityRule: Sendable {
    nonisolated var activity: Activity { get }
    /// Pure: same day in, same score out. No I/O, no clock, no shared state.
    nonisolated func score(_ day: DailyWeather) -> SuitabilityScore
}
