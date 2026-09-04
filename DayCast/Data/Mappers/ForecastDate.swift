import Foundation

/// Parses Open-Meteo's `"2026-09-04"` day labels.
///
/// **Parsed at UTC midnight, deliberately.**
///
/// The API is asked for `timezone=auto`, so those strings are already *local calendar days*
/// at the requested coordinates. Two problems follow if we parse them in the device's
/// timezone:
///
/// 1. **The merge breaks.** Forecast and Marine snap to different grid points and can report
///    different `utc_offset_seconds` — Biarritz came back as `Europe/Paris` from Marine
///    while the forecast grid point could differ. Same label, different `Date`, and the
///    dictionary lookup silently misses.
/// 2. **The label shifts.** A user in Sydney checking Oslo would see the day names slide by
///    one, because midnight in Oslo is mid-morning in Sydney.
///
/// Anchoring every label to UTC midnight makes the value a stable *key* and keeps the
/// displayed day identical to the day Open-Meteo forecast. The presentation layer must
/// format these with a UTC calendar for the same reason.
nonisolated enum ForecastDate {

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")   // immune to user calendars
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func parse(_ string: String) -> Date? {
        formatter.date(from: string)
    }

    /// Formatter callers must use so displayed days match forecast days.
    static var displayTimeZone: TimeZone { TimeZone(identifier: "UTC") ?? .gmt }
}
