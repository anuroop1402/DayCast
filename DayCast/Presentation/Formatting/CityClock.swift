import Foundation

/// The one line that tells the reader whose calendar they are looking at.
///
/// Every day label on this screen is the *city's* day — see `DayLabel`. That is the right
/// frame, because the forecast is about the city, but it leaves one honest gap: a device on
/// the 6th sees a row reading "Today, 7 Sep" with nothing on screen to explain it. This
/// closes that gap by stating the city's own clock in a full sentence.
///
/// **Returns `nil` when the two clocks agree**, which is the overwhelming majority of use —
/// looking up a city in your own timezone needs no explanation, and a caption that is always
/// present is a caption nobody reads. Compared by *offset*, not identifier: `Asia/Kolkata`
/// and `Asia/Colombo` are different zones showing the same time, and there is nothing to
/// reconcile between them.
///
/// `now` and both timezones are parameters for the reason everything else in this folder
/// takes them — a formatter that reads `Date()` or `Calendar.current` internally asserts the
/// developer's machine rather than a behaviour.
nonisolated enum CityClock {

    /// Whether there is anything to reconcile at all.
    ///
    /// Separate from `caption` because the answer changes only at a DST boundary, while the
    /// text changes every minute. The view uses this to decide whether the row exists and
    /// `caption` to fill it, so a city on the device's own clock costs no row rather than an
    /// empty one.
    static func isWorthShowing(
        cityTimeZone: TimeZone,
        deviceTimeZone: TimeZone,
        at now: Date
    ) -> Bool {
        cityTimeZone.secondsFromGMT(for: now) != deviceTimeZone.secondsFromGMT(for: now)
    }

    /// "It's 05:49 on Sunday 7 September in Queenstown", or `nil` if that adds nothing.
    static func caption(
        now: Date,
        cityName: String,
        cityTimeZone: TimeZone,
        deviceTimeZone: TimeZone
    ) -> String? {
        guard isWorthShowing(cityTimeZone: cityTimeZone, deviceTimeZone: deviceTimeZone, at: now)
        else { return nil }

        let time = formatter("j:mm", cityTimeZone).string(from: now)
        let date = formatter("EEEE d MMMM", cityTimeZone).string(from: now)
        return "It's \(time) on \(date) in \(cityName)"
    }

    /// Localised ordering, but pinned to the city's zone rather than the device's.
    private static func formatter(_ template: String, _ timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }
}
