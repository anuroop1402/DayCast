import Foundation

/// Drives the forecast screen for one city.
///
/// Holds the whole `ActivityForecast` in `ViewState` rather than unpacking it into parallel
/// arrays: the domain already shaped this data, and a presentation model mirroring it 1:1
/// is on the rejected list in `CLAUDE.md`. The computed properties below are *views* of
/// that value, not copies of it.
@Observable
final class ForecastViewModel {

    let city: City
    private(set) var state: ViewState<ActivityForecast> = .idle

    private let getActivityForecast: any GetActivityForecastUseCase

    init(city: City, getActivityForecast: any GetActivityForecastUseCase) {
        self.city = city
        self.getActivityForecast = getActivityForecast
    }

    // MARK: - Derived

    var days: [DayForecast] { state.value?.days ?? [] }

    /// The summary strip: the pick of the week for each activity, in a stable order.
    ///
    /// Every activity gets an entry even when there is no day to name, so nothing silently
    /// drops off the screen — the card says why instead.
    var bestDays: [BestDaySummary] {
        guard let forecast = state.value else { return [] }
        return Activity.allCases.map { activity in
            let best = forecast.bestDay(for: activity)
            let rating = best?.score(for: activity)?.rating ?? .unknown
            return BestDaySummary(activity: activity, rating: rating, day: best)
        }
    }

    /// True when no day in the week could be scored for surfing — an inland city, or a
    /// Marine API failure. Drives the one-line explanation on the screen.
    var isMissingMarineData: Bool {
        guard let forecast = state.value, !forecast.days.isEmpty else { return false }
        return forecast.days.allSatisfy {
            $0.score(for: .surfing)?.outcome == .insufficientData
        }
    }

    // MARK: - Actions

    func load() async {
        state = .loading
        do {
            let forecast = try await getActivityForecast(city: city)
            state = forecast.days.isEmpty ? .empty : .loaded(forecast)
        } catch let error as AppError {
            guard error != .cancelled else { return }
            state = .failed(error)
        } catch is CancellationError {
            return
        } catch {
            state = .failed(.unexpected)
        }
    }
}


/// One card in the "Best day for" strip.
///
/// Not a mirror of a domain entity — it answers a question the domain does not ask: *what
/// should this card say?* Keeping that here rather than in the view is what makes it
/// testable, since the project deliberately has no snapshot tests.
nonisolated struct BestDaySummary: Identifiable, Hashable {

    let activity: Activity
    /// The rating of the week's highest-scoring day, shown even when no day is named.
    let rating: SuitabilityRating
    private let best: DayForecast?

    init(activity: Activity, rating: SuitabilityRating, day: DayForecast?) {
        self.activity = activity
        self.rating = rating
        self.best = day
    }

    var id: Activity { activity }

    /// The day to put on the card, or `nil` when naming one would read as a recommendation
    /// we do not mean.
    ///
    /// A week where every day is `.unsuitable` still *has* a highest-scoring day, but
    /// calling it the best day makes the card contradict its own badge — someone skimming
    /// the strip reads the day and not the rating. Queenstown in September is the live
    /// case: the town sits at 322 m and its ski fields at 1200–1900 m, so the weather-only
    /// ski score is correctly hopeless all week and "Best day for Ski: Wednesday" was
    /// pointing at nothing.
    ///
    /// `.poor` still names a day. "Least bad" is genuinely useful when the week is merely
    /// mediocre; it stops being useful when the answer is *don't*.
    var day: DayForecast? {
        switch rating {
        case .unsuitable, .unknown: nil
        default:                    best
        }
    }
}
