import Foundation

/// Transposes the Marine response, keyed by forecast day.
///
/// **Days with null values are omitted rather than defaulted to zero.** An inland location
/// returns `HTTP 200` with all-null arrays, and zero would mean "we measured a flat sea" —
/// which would score surfing as genuinely bad rather than unknown, and tell the user Prague
/// has poor surf. Omission is what lets `SurfingRule` return `insufficientData`.
nonisolated enum MarineMapper {

    static func map(_ dto: MarineResponseDTO) -> [Date: MarineConditions] {
        let daily = dto.daily
        var result: [Date: MarineConditions] = [:]

        for index in daily.time.indices {
            guard
                let date = ForecastDate.parse(daily.time[index]),
                // Height and period are both required: a height with no period cannot
                // distinguish groundswell from wind chop, which is most of what the rule
                // is judging.
                let swellHeight = value(daily.swellWaveHeightMax, index),
                let swellPeriod = value(daily.swellWavePeriodMax, index)
            else { continue }

            result[date] = MarineConditions(
                swellWaveHeightMax: swellHeight,
                swellWavePeriodMax: swellPeriod,
                // Total sea state including wind chop; falls back to swell alone.
                waveHeightMax: value(daily.waveHeightMax, index) ?? swellHeight
            )
        }
        return result
    }

    private static func value(_ column: [Double?]?, _ index: Int) -> Double? {
        guard let column, column.indices.contains(index) else { return nil }
        return column[index]
    }
}
