import Testing
import Foundation
@testable import DayCast

@MainActor
struct ForecastViewModelTests {

    private func week(marine: MarineConditions? = nil) -> [DailyWeather] {
        (0..<7).map { offset in
            DailyWeather.fixture(
                date: .forecastDay(offset),
                temperatureMax: 21, apparentTemperatureMax: 20,
                windSpeedMax: 8, windGustsMax: 14,
                sunshineDuration: 8 * 3600, daylightDuration: 13 * 3600, uvIndexMax: 6,
                marine: marine
            )
        }
    }

    private let swell = MarineConditions(
        swellWaveHeightMax: 1.6, swellWavePeriodMax: 13, waveHeightMax: 1.9
    )

    private func make(
        _ result: Result<ActivityForecast, any Error>,
        city: City = .fixture()
    ) -> (ForecastViewModel, StubGetActivityForecastUseCase) {
        let useCase = StubGetActivityForecastUseCase()
        useCase.result = result
        return (ForecastViewModel(city: city, getActivityForecast: useCase), useCase)
    }

    @Test("A loaded week exposes its days and asks for the right city")
    func loadsTheWeek() async {
        let city = City.fixture(id: 42, name: "Biarritz")
        let (viewModel, useCase) = make(.success(.scored(city: city, days: week())), city: city)

        await viewModel.load()

        #expect(viewModel.days.count == 7)
        #expect(useCase.requestedCities.map(\.id) == [42])
    }

    @Test("The summary covers every activity, in a stable order")
    func summaryCoversEveryActivity() async {
        let (viewModel, _) = make(.success(.scored(days: week(marine: swell))))

        await viewModel.load()

        #expect(viewModel.bestDays.map(\.activity) == Activity.allCases)
    }

    // MARK: - The inland case, end to end through the real scoring engine

    @Test("An inland week degrades surfing alone — the screen still works")
    func inlandDegradesSurfingOnly() async {
        let (viewModel, _) = make(.success(.scored(days: week(marine: nil))))

        await viewModel.load()

        #expect(viewModel.isMissingMarineData)
        // Surfing alone reports no data...
        #expect(viewModel.bestDays.first { $0.activity == .surfing }?.rating == .unknown)
        // ...and nothing else lost its score. Asserting on the rating rather than on `day`,
        // because a warm week legitimately names no ski day — see `BestDaySummary.day`.
        for activity in [Activity.skiing, .outdoorSightseeing, .indoorSightseeing] {
            let summary = viewModel.bestDays.first { $0.activity == activity }
            #expect(summary?.rating != .unknown, "\(activity) lost its score")
        }
        #expect(viewModel.state.error == nil)
    }

    @Test("A coastal week does not show the missing-marine-data notice")
    func coastalWeekHasMarineData() async {
        let (viewModel, _) = make(.success(.scored(days: week(marine: swell))))

        await viewModel.load()

        #expect(!viewModel.isMissingMarineData)
        #expect(viewModel.bestDays.first { $0.activity == .surfing }?.day != nil)
    }

    @Test("The missing-data notice does not appear before anything has loaded")
    func noNoticeWhileEmpty() async {
        let (viewModel, _) = make(.success(.scored(days: [])))
        #expect(!viewModel.isMissingMarineData)

        await viewModel.load()

        #expect(!viewModel.isMissingMarineData)
    }

    // MARK: - Failure states

    // MARK: - Naming a best day

    @Test("A week with no suitable day names none, but still reports the rating")
    func unsuitableWeekNamesNoDay() async {
        // A warm, snowless week: skiing is correctly hopeless every day. Queenstown in
        // September is the live case that surfaced this.
        let (viewModel, _) = make(.success(.scored(days: week(marine: swell))))

        await viewModel.load()

        let skiing = viewModel.bestDays.first { $0.activity == .skiing }
        #expect(skiing?.rating == .unsuitable)
        // "Best day for Ski: Wednesday" alongside an Unsuitable badge points at nothing.
        #expect(skiing?.day == nil)
    }

    @Test("A week with a genuinely good day names it")
    func suitableWeekNamesItsBestDay() async {
        let (viewModel, _) = make(.success(.scored(days: week(marine: swell))))

        await viewModel.load()

        let outdoor = viewModel.bestDays.first { $0.activity == .outdoorSightseeing }
        #expect(outdoor?.day != nil)
        #expect(outdoor?.rating != .unsuitable)
    }

    @Test("An activity with no data names no day either")
    func unknownRatingNamesNoDay() async {
        let (viewModel, _) = make(.success(.scored(days: week(marine: nil))))

        await viewModel.load()

        let surfing = viewModel.bestDays.first { $0.activity == .surfing }
        #expect(surfing?.rating == .unknown)
        #expect(surfing?.day == nil)
    }

    @Test("A forecast with no days is empty, not an error")
    func noDaysIsEmpty() async {
        let (viewModel, _) = make(.success(.scored(days: [])))

        await viewModel.load()

        #expect(viewModel.state == .empty)
        #expect(viewModel.days.isEmpty)
    }

    @Test("A failure is surfaced with its retryability intact")
    func failureIsSurfaced() async {
        let (viewModel, _) = make(.failure(AppError.timedOut))

        await viewModel.load()

        #expect(viewModel.state == .failed(.timedOut))
        #expect(viewModel.state.error?.isRetryable == true)
    }

    @Test("A non-retryable failure is reported as such, so no dead retry button is offered")
    func nonRetryableFailure() async {
        let (viewModel, _) = make(.failure(AppError.decoding))

        await viewModel.load()

        #expect(viewModel.state.error?.isRetryable == false)
    }

    @Test("A cancelled load never reaches the user as an error")
    func cancellationIsNotAnError() async {
        let (viewModel, _) = make(.failure(AppError.cancelled))

        await viewModel.load()

        #expect(viewModel.state.error == nil)
    }

    @Test("Retrying after a failure can succeed")
    func retryAfterFailureSucceeds() async {
        let useCase = StubGetActivityForecastUseCase()
        useCase.result = .failure(AppError.offline)
        let viewModel = ForecastViewModel(city: .fixture(), getActivityForecast: useCase)
        await viewModel.load()
        #expect(viewModel.state.error == .offline)

        useCase.result = .success(.scored(days: week()))
        await viewModel.load()

        #expect(viewModel.days.count == 7)
        #expect(viewModel.state.error == nil)
    }
}
