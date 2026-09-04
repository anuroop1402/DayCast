import Testing
import Foundation
@testable import DayCast

struct ViewStateTests {

    @Test("A finished request with results loads")
    func nonEmptyCollectionLoads() {
        #expect(ViewState([1, 2, 3]) == .loaded([1, 2, 3]))
    }

    @Test("A finished request with nothing in it is empty, not loaded")
    func emptyCollectionIsEmpty() {
        // The distinction the whole type exists for: `loaded([])` would render a blank
        // list where "No results" belongs.
        #expect(ViewState([Int]()) == .empty)
    }

    @Test("Accessors read only their own case")
    func accessorsAreCaseSpecific() {
        let loading = ViewState<[Int]>.loading
        #expect(loading.isLoading)
        #expect(loading.value == nil)
        #expect(loading.error == nil)

        let loaded = ViewState.loaded([1])
        #expect(!loaded.isLoading)
        #expect(loaded.value == [1])
        #expect(loaded.error == nil)

        let failed = ViewState<[Int]>.failed(.offline)
        #expect(failed.error == .offline)
        #expect(failed.value == nil)
        #expect(!failed.isLoading)
    }

    @Test("The error is kept so the view can decide whether retry is worth offering")
    func failedCarriesRetryability() {
        #expect(ViewState<[Int]>.failed(.offline).error?.isRetryable == true)
        #expect(ViewState<[Int]>.failed(.decoding).error?.isRetryable == false)
    }
}

struct DayLabelTests {

    /// Epoch is UTC midnight, matching how `ForecastDate` anchors every forecast day.
    private let day0 = Date.forecastDay(0)

    private let utc = TimeZone(identifier: "UTC")!
    /// UTC+5:30 — chosen because it is ahead of UTC and on a half-hour offset, so it breaks
    /// any accidental assumption that offsets are whole hours.
    private let mumbai = TimeZone(identifier: "Asia/Kolkata")!
    /// UTC-5, behind UTC. The first version of `DayLabel` read `Calendar.current` and
    /// passed only because the machine running it happened to be ahead of UTC.
    private let newYork = TimeZone(identifier: "America/New_York")!

    @Test("The nearest days read as words rather than dates")
    func relativeLabels() {
        #expect(DayLabel.weekday(day0, today: day0, userTimeZone: utc) == "Today")
        #expect(DayLabel.weekday(.forecastDay(1), today: day0, userTimeZone: utc) == "Tomorrow")
        #expect(DayLabel.weekday(.forecastDay(2), today: day0, userTimeZone: utc) != "Tomorrow")
    }

    @Test("Labels do not shift as the user's clock moves through their day")
    func labelIsStableAcrossTheUsersDay() {
        // The property that matters: "Today" must mean the same day at 00:30 and at 23:30.
        // Comparing raw intervals instead of calendar days breaks exactly this.
        for timeZone in [utc, mumbai, newYork] {
            // Local midnight on 1 January, whichever side of UTC this timezone sits.
            let startOfDay = day0.addingTimeInterval(-TimeInterval(timeZone.secondsFromGMT(for: day0)))
            let morning = startOfDay.addingTimeInterval(30 * 60)
            let lateEvening = startOfDay.addingTimeInterval(23 * 3600 + 30 * 60)

            #expect(
                DayLabel.weekday(day0, today: morning, userTimeZone: timeZone)
                    == DayLabel.weekday(day0, today: lateEvening, userTimeZone: timeZone),
                "Label shifted within a single day in \(timeZone.identifier)"
            )
        }
    }

    @Test("A user behind UTC gets the same labels as one ahead of it")
    func labelsAgreeAcrossTimeZones() {
        // Both users are on their own 1 January; both should see day 0 as "Today". The
        // original implementation returned "Thursday" for one of them.
        let mumbaiMorning = day0.addingTimeInterval(4 * 3600)      // 09:30 on 1 Jan in Mumbai
        let newYorkMorning = day0.addingTimeInterval(14 * 3600)    // 09:00 on 1 Jan in New York

        #expect(DayLabel.weekday(day0, today: mumbaiMorning, userTimeZone: mumbai) == "Today")
        #expect(DayLabel.weekday(day0, today: newYorkMorning, userTimeZone: newYork) == "Today")
        #expect(DayLabel.weekday(.forecastDay(1), today: newYorkMorning, userTimeZone: newYork) == "Tomorrow")
    }

    @Test("A day almost a week out is neither today nor tomorrow")
    func distantDayGetsAWeekdayName() {
        let label = DayLabel.weekday(.forecastDay(6), today: day0, userTimeZone: utc)
        #expect(label != "Today")
        #expect(label != "Tomorrow")
        #expect(!label.isEmpty)
    }

    @Test("The full title carries both the relative day and the calendar date")
    func fullTitleIsUnambiguous() {
        let title = DayLabel.full(day0, today: day0, userTimeZone: utc)
        #expect(title.hasPrefix("Today, "))
        #expect(title.contains("1"))
    }
}
