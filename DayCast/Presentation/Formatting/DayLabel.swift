import Foundation

/// Formats forecast days.
///
/// **Every formatter here uses a UTC calendar, and that is not optional.**
///
/// `ForecastDate` parses Open-Meteo's `"2026-09-04"` labels at UTC midnight so the value is
/// a stable dictionary key for the land/marine merge. The consequence lands here: format
/// one of those dates with the device's calendar and the label slides by a day for any user
/// whose timezone is behind the anchor — a user in Los Angeles would see Oslo's Friday
/// rendered as Thursday. The date is a *calendar day label*, not a moment in time, so it
/// must be read back in the same timezone it was written in.
///
/// `today` **and the user's timezone** are both injected rather than read from `Date()` and
/// `Calendar.current`, for the same reason the scoring engine takes a reference date: a
/// function that reads the environment cannot be tested, only observed. The first version
/// read `Calendar.current` and its tests passed in IST and would have failed in New York.
///
/// **"Today" means the user's calendar day, not the city's.** A user in Mumbai at 04:30
/// looking at Oslo is in a few-hour window where the two disagree, and either choice is
/// defensible. The phone's own day wins because it matches the calendar the user is
/// actually holding; the cost is that for those few hours the day labelled "Today" is the
/// city's tomorrow. Recorded as an assumption in `docs/01-Solution-Planning.md`.
nonisolated enum DayLabel {

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = ForecastDate.displayTimeZone
        return calendar
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.timeZone = ForecastDate.displayTimeZone
        formatter.setLocalizedDateFormatFromTemplate(format)
        return formatter
    }

    /// "Friday", or "Today" / "Tomorrow" where that is friendlier.
    static func weekday(
        _ date: Date,
        today: Date = Date(),
        userTimeZone: TimeZone = .current
    ) -> String {
        switch offsetInDays(from: today, to: date, userTimeZone: userTimeZone) {
        case 0:  "Today"
        case 1:  "Tomorrow"
        default: formatter("EEEE").string(from: date)
        }
    }

    /// "3 Sep" — the calendar date, always, so a user can pin "Tomorrow" to a real day.
    static func shortDate(_ date: Date) -> String {
        formatter("d MMM").string(from: date)
    }

    /// "Friday 5 September" — for a screen title, where there is room to be unambiguous.
    static func full(
        _ date: Date,
        today: Date = Date(),
        userTimeZone: TimeZone = .current
    ) -> String {
        let day = weekday(date, today: today, userTimeZone: userTimeZone)
        return "\(day), \(formatter("d MMMM").string(from: date))"
    }

    /// Whole days between two dates, compared as calendar days rather than by subtracting
    /// intervals — 23 hours apart can still be two different days.
    ///
    /// `today` arrives as a real moment. Its calendar day *in the user's timezone* is
    /// re-anchored to UTC midnight before comparing, because that is the frame every
    /// forecast date is already in — comparing the two directly would mix frames and shift
    /// every label by a day for anyone not on UTC.
    private static func offsetInDays(
        from today: Date,
        to date: Date,
        userTimeZone: TimeZone
    ) -> Int? {
        var userCalendar = Calendar(identifier: .gregorian)
        userCalendar.timeZone = userTimeZone
        let day = userCalendar.dateComponents([.year, .month, .day], from: today)

        guard let anchoredToday = utcCalendar.date(from: day) else { return nil }
        return utcCalendar.dateComponents([.day], from: anchoredToday, to: date).day
    }
}
