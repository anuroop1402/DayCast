import Foundation

extension Double {
    /// Compact rendering for reason strings: `3.0` → "3", `1.5` → "1.5".
    /// Reasons quote the measurement so a user can audit the score, but "3.0 mm" reads
    /// like false precision.
    nonisolated var reasonValue: String {
        rounded() == self ? String(Int(self)) : String(format: "%.1f", self)
    }

    nonisolated var roundedInt: Int { Int(rounded()) }
}
