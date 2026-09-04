import Foundation
@testable import DayCast

extension DailyWeather {
    /// Neutral baseline: a bland, unremarkable day. Tests override only the variables
    /// they are actually exercising, so each test reads as "this factor, changed".
    static func fixture(
        date: Date = Date(timeIntervalSince1970: 0),
        temperatureMax: Double = 15,
        temperatureMin: Double = 8,
        apparentTemperatureMax: Double = 15,
        precipitationSum: Double = 0,
        rainSum: Double = 0,
        snowfallSum: Double = 0,
        precipitationProbabilityMax: Double = 0,
        windSpeedMax: Double = 8,
        windGustsMax: Double = 15,
        sunshineDuration: TimeInterval = 6 * 3600,
        daylightDuration: TimeInterval = 12 * 3600,
        uvIndexMax: Double = 3,
        marine: MarineConditions? = nil
    ) -> DailyWeather {
        DailyWeather(
            date: date,
            temperatureMaxCelsius: temperatureMax,
            temperatureMinCelsius: temperatureMin,
            apparentTemperatureMaxCelsius: apparentTemperatureMax,
            precipitationSumMillimetres: precipitationSum,
            rainSumMillimetres: rainSum,
            snowfallSumCentimetres: snowfallSum,
            precipitationProbabilityMaxPercent: precipitationProbabilityMax,
            windSpeedMaxKilometresPerHour: windSpeedMax,
            windGustsMaxKilometresPerHour: windGustsMax,
            sunshineDurationSeconds: sunshineDuration,
            daylightDurationSeconds: daylightDuration,
            uvIndexMax: uvIndexMax,
            marine: marine
        )
    }

    // MARK: - Named scenarios used across the scoring tests

    /// Warm, dry, sunny, still.
    static let perfectSummerDay = fixture(
        temperatureMax: 24, apparentTemperatureMax: 23,
        windSpeedMax: 6, windGustsMax: 12,
        sunshineDuration: 10 * 3600, daylightDuration: 14 * 3600, uvIndexMax: 5
    )

    /// Grey, persistent light rain. Unpleasant outside, trivially easy to travel in.
    static let drizzle = fixture(
        temperatureMax: 11, apparentTemperatureMax: 9,
        precipitationSum: 7, rainSum: 7, precipitationProbabilityMax: 90,
        windSpeedMax: 14, windGustsMax: 25,
        sunshineDuration: 0.5 * 3600, daylightDuration: 10 * 3600, uvIndexMax: 1
    )

    /// Heavy snow and gales. Maximum "nothing else to do", minimum ability to get anywhere.
    static let blizzard = fixture(
        temperatureMax: -6, apparentTemperatureMax: -14,
        precipitationSum: 22, rainSum: 0, snowfallSum: 28,
        precipitationProbabilityMax: 100,
        windSpeedMax: 55, windGustsMax: 90,
        sunshineDuration: 0, daylightDuration: 8 * 3600, uvIndexMax: 0
    )

    /// Cold, fresh dump, light wind.
    static let powderDay = fixture(
        temperatureMax: -6, temperatureMin: -12, apparentTemperatureMax: -10,
        precipitationSum: 18, rainSum: 0, snowfallSum: 22,
        windSpeedMax: 12, windGustsMax: 22,
        sunshineDuration: 2 * 3600, daylightDuration: 9 * 3600, uvIndexMax: 1
    )

    /// Same mountain, two degrees warmer, and it is raining on the snow.
    static let rainOnSnowDay = fixture(
        temperatureMax: 2, temperatureMin: -1, apparentTemperatureMax: 0,
        precipitationSum: 12, rainSum: 12, snowfallSum: 0,
        precipitationProbabilityMax: 95,
        windSpeedMax: 20, windGustsMax: 35,
        sunshineDuration: 0, daylightDuration: 9 * 3600, uvIndexMax: 1
    )

    /// Clean offshore-ish morning with real groundswell.
    static let goodSurfDay = fixture(
        temperatureMax: 21, apparentTemperatureMax: 20,
        windSpeedMax: 8, windGustsMax: 14,
        sunshineDuration: 8 * 3600, daylightDuration: 13 * 3600, uvIndexMax: 6,
        marine: MarineConditions(
            swellWaveHeightMax: 1.6, swellWavePeriodMax: 13, waveHeightMax: 1.9
        )
    )

    /// Coastal, but the sea is flat and the wind is up.
    static let flatBlownOutDay = fixture(
        temperatureMax: 19, apparentTemperatureMax: 18,
        windSpeedMax: 38, windGustsMax: 52,
        marine: MarineConditions(
            swellWaveHeightMax: 0.3, swellWavePeriodMax: 4, waveHeightMax: 0.8
        )
    )
}
