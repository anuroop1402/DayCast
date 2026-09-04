import Foundation

/// The orchestration the rest of the app is built around: two endpoints, merged, scored.
///
/// **Why the merge lives here.** `ForecastRepository` exposes land and sea as separate
/// calls because they are separate endpoints with separate failure modes. Deciding what a
/// missing sea response *means* is a business rule, so it belongs in the domain — not in
/// the repository, which would have to invent a policy, and not in the ViewModel, which
/// would have to import both concepts to do it.
///
/// **The partial-failure policy, stated once.**
///
/// - The land forecast is the only non-optional source. Without it there is no day to
///   score for any activity, so its failure propagates and the screen shows an error.
/// - The marine forecast is *expected* to be absent. Inland coordinates return `HTTP 200`
///   with every value null (verified against `marine-prague-inland.json`), and the Marine
///   API can also simply be down. Either way the day keeps `marine == nil`, `SurfingRule`
///   reports `insufficientData`, and skiing and both kinds of sightseeing are unaffected.
///   **A marine failure must never fail the screen.**
///
/// The degradation is per-day, not per-city, because it falls out of the merge: the
/// dictionary is keyed by day, so a coastal city with a gap in the marine grid degrades
/// only the days that are actually missing.
nonisolated struct GetActivityForecast: GetActivityForecastUseCase {

    /// The brief asks for the next 7 days. Both endpoints are asked for the same window so
    /// the day keys line up.
    static let forecastDays = 7

    private let repository: any ForecastRepository
    private let scoring: SuitabilityScoring

    init(
        repository: any ForecastRepository,
        scoring: SuitabilityScoring = SuitabilityScoring()
    ) {
        self.repository = repository
        self.scoring = scoring
    }

    func callAsFunction(city: City) async throws -> ActivityForecast {
        // Concurrent, not sequential: the two requests are independent, and serialising
        // them would double the time the user waits for a screen that needs both.
        async let land = repository.dailyForecast(for: city, days: Self.forecastDays)
        async let sea = marineForecast(for: city)

        let days = try await land
        let marine = try await sea

        // Merged on the UTC-midnight day key — see `ForecastDate` for why that anchor and
        // no other. A missing key yields `nil`, which is exactly what degradation means.
        return scoring.forecast(
            for: city,
            days: days.map { $0.withMarine(marine[$0.date]) }
        )
    }

    /// Sea state, or an empty dictionary if it could not be had.
    ///
    /// Swallowing errors is normally a smell. Here it is the rule: absence of marine data
    /// is the *expected* case for most of the world, and the caller cannot distinguish
    /// "inland" from "Marine API returned 503" in a way that would change what the user
    /// sees — either way we do not know the sea state and must say so.
    private func marineForecast(for city: City) async throws -> [Date: MarineConditions] {
        do {
            return try await repository.marineForecast(for: city, days: Self.forecastDays)
        } catch AppError.cancelled {
            // The one failure that is *not* about the sea. Cancellation means a newer
            // request superseded this one; reporting the city as inland would cache a
            // wrong answer for a request nobody is waiting on any more.
            throw AppError.cancelled
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return [:]
        }
    }
}
