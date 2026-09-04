import Foundation

/// Open-Meteo Marine API response.
///
/// **An inland location returns `HTTP 200` with every value `null`** — not a 404, not an
/// error body. Verified against `marine-prague-inland.json`. The mapper therefore treats
/// nulls as "no data for this day" and simply omits the day, which is what lets surfing
/// degrade on its own while the rest of the forecast scores normally.
nonisolated struct MarineResponseDTO: Decodable, Sendable {
    let utcOffsetSeconds: Int
    let daily: Daily

    nonisolated struct Daily: Decodable, Sendable {
        let time: [String]
        let waveHeightMax: [Double?]?
        let swellWaveHeightMax: [Double?]?
        let swellWavePeriodMax: [Double?]?

        enum CodingKeys: String, CodingKey {
            case time
            case waveHeightMax = "wave_height_max"
            case swellWaveHeightMax = "swell_wave_height_max"
            case swellWavePeriodMax = "swell_wave_period_max"
        }
    }

    enum CodingKeys: String, CodingKey {
        case utcOffsetSeconds = "utc_offset_seconds"
        case daily
    }
}
