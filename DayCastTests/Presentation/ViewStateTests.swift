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
    /// UTC+5:30 — ahead of UTC and on a half-hour offset, so it breaks any accidental
    /// assumption that offsets are whole hours.
    private let mumbai = TimeZone(identifier: "Asia/Kolkata")!
    /// UTC-5, behind UTC. The first version of `DayLabel` read `Calendar.current` and
    /// passed only because the machine running it happened to be ahead of UTC.
    private let newYork = TimeZone(identifier: "America/New_York")!
    /// UTC+8. Paired with `mumbai` below because the 2h30m gap between them is the window
    /// in which the device's calendar and the city's disagree.
    private let shanghai = TimeZone(identifier: "Asia/Shanghai")!

    @Test("The nearest days read as words rather than dates")
    func relativeLabels() {
        #expect(DayLabel.weekday(day0, today: day0, cityTimeZone: utc) == "Today")
        #expect(DayLabel.weekday(.forecastDay(1), today: day0, cityTimeZone: utc) == "Tomorrow")
        #expect(DayLabel.weekday(.forecastDay(2), today: day0, cityTimeZone: utc) != "Tomorrow")
    }

    @Test("Labels do not shift as the clock moves through the city's day")
    func labelIsStableAcrossTheCitysDay() {
        // The property that matters: "Today" must mean the same day at 00:30 and at 23:30.
        // Dropping the re-anchoring and comparing against the raw moment breaks exactly
        // this — and breaks it only for cities behind UTC, which is why New York is here.
        for timeZone in [utc, mumbai, newYork, shanghai] {
            // Local midnight on 1 January, whichever side of UTC this timezone sits.
            let startOfDay = day0.addingTimeInterval(-TimeInterval(timeZone.secondsFromGMT(for: day0)))
            let morning = startOfDay.addingTimeInterval(30 * 60)
            let lateEvening = startOfDay.addingTimeInterval(23 * 3600 + 30 * 60)

            #expect(
                DayLabel.weekday(day0, today: morning, cityTimeZone: timeZone)
                    == DayLabel.weekday(day0, today: lateEvening, cityTimeZone: timeZone),
                "Label shifted within a single day in \(timeZone.identifier)"
            )
        }
    }

    @Test("A city ahead of the device still calls its own current day Today")
    func labelFollowsTheCityNotTheDevice() {
        // 1 Jan 16:30 UTC: 22:00 on the 1st in Mumbai, but already 00:30 on the 2nd in
        // Shanghai. Open-Meteo's first row for Shanghai is therefore the 2nd, and it is
        // happening *now* there. Labelling by the device's calendar headed it "Tomorrow" —
        // a present-tense forecast sold as the future, with nothing on screen to correct it.
        let now = day0.addingTimeInterval(16 * 3600 + 30 * 60)

        #expect(DayLabel.weekday(.forecastDay(1), today: now, cityTimeZone: shanghai) == "Today")
        #expect(DayLabel.weekday(.forecastDay(2), today: now, cityTimeZone: shanghai) == "Tomorrow")

        // Same instant, a city still on the 1st: its own current day is the 1st.
        #expect(DayLabel.weekday(day0, today: now, cityTimeZone: mumbai) == "Today")
    }

    @Test("The label does not depend on where the device is")
    func labelIgnoresTheDevicesOwnCalendar() {
        // Two people opening the same city at the same instant from opposite sides of UTC
        // see the same week. Guaranteed structurally now the device's timezone is not an
        // input at all — asserted so a future default of `.current` cannot creep back in.
        let now = day0.addingTimeInterval(16 * 3600 + 30 * 60)
        let fromAnywhere = DayLabel.weekday(.forecastDay(1), today: now, cityTimeZone: shanghai)

        #expect(fromAnywhere == "Today")
        #expect(DayLabel.full(.forecastDay(1), today: now, cityTimeZone: shanghai).hasPrefix("Today, "))
    }

    @Test("A day almost a week out is neither today nor tomorrow")
    func distantDayGetsAWeekdayName() {
        let label = DayLabel.weekday(.forecastDay(6), today: day0, cityTimeZone: utc)
        #expect(label != "Today")
        #expect(label != "Tomorrow")
        #expect(!label.isEmpty)
    }

    @Test("The full title carries both the relative day and the calendar date")
    func fullTitleIsUnambiguous() {
        let title = DayLabel.full(day0, today: day0, cityTimeZone: utc)
        #expect(title.hasPrefix("Today, "))
        #expect(title.contains("1"))
    }

    @Test("An unrecognised timezone identifier falls back to UTC, not the device")
    func cityTimeZoneFallsBackToUTC() {
        let city = City(
            id: 1, name: "Nowhere", country: "XX", admin1: nil,
            latitude: 0, longitude: 0, timezone: "Not/AZone"
        )
        #expect(city.localTimeZone.secondsFromGMT(for: day0) == 0)
    }
}

struct CityClockTests {

    private let day0 = Date.forecastDay(0)
    private let mumbai = TimeZone(identifier: "Asia/Kolkata")!
    private let shanghai = TimeZone(identifier: "Asia/Shanghai")!
    private let colombo = TimeZone(identifier: "Asia/Colombo")!

    @Test("A city on a different clock explains itself")
    func captionAppearsWhenClocksDiffer() throws {
        // 1 Jan 16:30 UTC — 22:00 on the 1st in Mumbai, 00:30 on the 2nd in Shanghai. This
        // is the window where the forecast's first row reads "Today, 2 Jan" on a device
        // still showing the 1st, so it is exactly when the caption has to be present.
        let now = day0.addingTimeInterval(16 * 3600 + 30 * 60)
        let caption = try #require(
            CityClock.caption(now: now, cityName: "Shanghai", cityTimeZone: shanghai, deviceTimeZone: mumbai)
        )

        #expect(caption.contains("Shanghai"))
        #expect(caption.contains("2 January"))
    }

    @Test("A city on the same clock says nothing")
    func captionIsHiddenWhenClocksAgree() {
        #expect(
            CityClock.caption(now: day0, cityName: "Delhi", cityTimeZone: mumbai, deviceTimeZone: mumbai) == nil
        )
    }

    @Test("Different zones showing the same time have nothing to reconcile")
    func captionComparesOffsetsNotIdentifiers() {
        // Asia/Colombo and Asia/Kolkata are distinct identifiers, both UTC+5:30. Comparing
        // identifiers instead of offsets would caption a city whose clock already matches.
        #expect(colombo != mumbai)
        #expect(
            CityClock.caption(now: day0, cityName: "Colombo", cityTimeZone: colombo, deviceTimeZone: mumbai) == nil
        )
    }

    @Test("The caption is rendered in the city's zone, not the device's")
    func captionUsesTheCitysClock() throws {
        // Same instant, same device: only the city changes. A formatter that quietly read
        // the device's calendar would return identical text for both.
        let now = day0.addingTimeInterval(16 * 3600 + 30 * 60)
        let shanghaiText = try #require(
            CityClock.caption(now: now, cityName: "Shanghai", cityTimeZone: shanghai, deviceTimeZone: mumbai)
        )
        let utcText = try #require(
            CityClock.caption(now: now, cityName: "Accra", cityTimeZone: TimeZone(identifier: "UTC")!, deviceTimeZone: mumbai)
        )

        #expect(shanghaiText.contains("2 January"))
        #expect(utcText.contains("1 January"))
    }
}
