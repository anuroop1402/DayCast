import Foundation

/// Sea state for a single day, from Open-Meteo's Marine API.
///
/// Only exists for coastal coordinates. Its absence is meaningful — see `DailyWeather.marine`
/// — and must degrade surfing alone rather than failing the whole forecast.
nonisolated struct MarineConditions: Hashable, Sendable {
    /// Metres. Swell is the surfable component: long-travelled, organised energy.
    let swellWaveHeightMax: Double
    /// Seconds between crests. Longer periods mean cleaner, more powerful waves.
    let swellWavePeriodMax: Double
    /// Metres. Total sea state including local wind chop.
    let waveHeightMax: Double
}
